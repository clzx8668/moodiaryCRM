package cn.yooss.moodiary

import android.os.Handler
import android.os.Looper
import com.k2fsa.sherpa.onnx.FeatureConfig
import com.k2fsa.sherpa.onnx.OfflineModelConfig
import com.k2fsa.sherpa.onnx.OfflineParaformerModelConfig
import com.k2fsa.sherpa.onnx.OfflineRecognizer
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig
import com.k2fsa.sherpa.onnx.SileroVadModelConfig
import com.k2fsa.sherpa.onnx.Vad
import com.k2fsa.sherpa.onnx.VadModelConfig
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * 端侧实时转写桥（批次 103）。
 *
 * 链路：Dart 送来 16k/mono/int16 PCM → silero VAD 切句 → Paraformer int8 逐句识别
 * → 回吐文本（`onResult`）。全部在本地跑，不依赖网络。
 *
 * 约束：sherpa-onnx 的推理调用不是线程安全的，这里用单线程 executor 串行化；
 * 回调经主线程 post 回 Dart。
 */
class AsrChannel(
    private val channel: MethodChannel,
    /** 应用私有模型目录：<filesDir>/asr（与 Dart 侧 AsrModelStore.baseDir() 对齐） */
    private val defaultModelDir: String? = null,
    /** 资源读取（自检样例音频）；传 null 则跳过样例 */
    private val assets: android.content.res.AssetManager? = null,
) {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var vad: Vad? = null
    private var recognizer: OfflineRecognizer? = null
    private var modelDir: String? = null
    private var segmentIndex = 0

    /** 本次会话已回吐的文本（自检用） */
    private val sessionResults = mutableListOf<String>()

    /** 用固定时长静音把最后一句"压"出来（自检模拟说话结束） */
    private fun appendSilenceTail(frames: Int = 60) {
        val engine = vad ?: return
        val silence = FloatArray(512)
        repeat(frames) { engine.acceptWaveform(silence) }
    }

    /**
     * 全部已识别文本（调用方负责在 `start` 前清空）。
     * 供 `runStreamSelfTest` 取尾句使用。
     */
    fun takeSessionResults(): List<String> = sessionResults.toList()

    /** 模型文件名与 Dart 侧 AsrModelFiles 保持一致 */
    private val vadFile = "silero_vad.onnx"
    private val asrFile = "model.int8.onnx"
    private val tokensFile = "tokens.txt"

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "init" -> {
                val dir = call.argument<String>("modelDir")
                if (dir.isNullOrBlank()) {
                    result.error("bad_args", "modelDir 为空", null)
                    return
                }
                worker.execute {
                    val err = initEngine(dir)
                    main.post { if (err == null) result.success(true) else result.error("init_failed", err, null) }
                }
            }
            "start" -> {
                worker.execute {
                    segmentIndex = 0
                    sessionResults.clear()
                    vad?.reset()
                    main.post { result.success(true) }
                }
            }
            "acceptPcm" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null || bytes.isEmpty()) {
                    result.success(null)
                    return
                }
                // 大块音频不需要回执延迟：先回，再异步处理
                result.success(null)
                worker.execute { feed(bytes) }
            }
            "stop" -> {
                worker.execute {
                    flush()
                    main.post { result.success(true) }
                }
            }
            "release" -> {
                worker.execute {
                    releaseEngine()
                    main.post { result.success(true) }
                }
            }
            else -> result.notImplemented()
        }
    }

    /** 模型是否就绪（不加载模型，仅查文件） */
    fun status(): Map<String, Any> {
        val dir = resolveDir()
        if (dir == null) {
            return mapOf(
                "ready" to false,
                "missing" to listOf(vadFile, asrFile, tokensFile)
            )
        }
        val missing = listOf(vadFile, asrFile, tokensFile).filter { !File(dir, it).exists() }
        return mapOf(
            "ready" to missing.isEmpty(),
            "missing" to missing,
            "dir" to dir
        )
    }

    /** 解析当前模型目录（init 传入的优先，否则用应用私有目录） */
    private fun resolveDir(): String? =
        (modelDir ?: defaultModelDir)?.takeIf { it.isNotBlank() }

    /**
     * 引擎自检：加载模型 → 喂一段测试音 → 收尾 → 返回结论。
     *
     * 用于"端侧链路通不通"的现场验证（设置页按钮 / `adb shell am start --es ASR selftest`）。
     * @param probePcm 可选的 16k/mono/int16 PCM；为空时用内置扫频音
     */
    fun runSelfTest(probePcm: ByteArray? = null, seconds: Double = 1.6): String {
        val started = System.currentTimeMillis()
        val dir = resolveDir() ?: return "失败：未指定模型目录"
        val err = initEngine(dir)
        if (err != null) return "失败：$err"
        val engine = vad ?: return "失败：VAD 未就绪"
        return try {
            engine.reset()
            segmentIndex = 0
            sessionResults.clear()
            val pcm = probePcm ?: loadSelfTestPcm() ?: probeTone(seconds)
            // 按线上一致的节奏分块喂（512 采样 ≈ 32ms），而不是整段塞进去
            val all = pcm16ToFloat(pcm)
            var off = 0
            while (off < all.size) {
                val len = minOf(512, all.size - off)
                engine.acceptWaveform(all.copyOfRange(off, off + len))
                off += len
            }
            engine.flush()
            drain()
            val ms = System.currentTimeMillis() - started
            if (sessionResults.isEmpty()) {
                "通过：引擎已加载并推理完成（${ms}ms，测试音无可识别语音）"
            } else {
                "通过：识别到「${sessionResults.joinToString("")}」（${ms}ms）"
            }
        } catch (e: Throwable) {
            "失败：${e.message}"
        }
    }
    /**
     * 自检用音频：优先 `assets/asr_selftest.wav`（16k/mono/16bit，真实人声样例），
     * 没有则退回内置扫频音。用真实语音才能验证"识别正确"而不只是"引擎能加载"。
     */
    private fun loadSelfTestPcm(): ByteArray? {
        val mgr = assets ?: return null
        return try {
            val wav = mgr.open("asr_selftest.wav").use { it.readBytes() }
            wavPcm16(wav)
        } catch (_: Throwable) {
            null
        }
    }
    /** 从 WAV 字节里剥出 PCM 段（跳过 RIFF 头，兼容带额外 chunk 的文件） */
    private fun wavPcm16(wav: ByteArray): ByteArray? {
        if (wav.size < 44) return null
        var offset = 12
        while (offset + 8 <= wav.size) {
            val id = String(wav, offset, 4, Charsets.US_ASCII)
            val size = (wav[offset + 4].toInt() and 0xFF) or
                ((wav[offset + 5].toInt() and 0xFF) shl 8) or
                ((wav[offset + 6].toInt() and 0xFF) shl 16) or
                ((wav[offset + 7].toInt() and 0xFF) shl 24)
            if (id == "data") {
                val start = offset + 8
                val end = minOf(wav.size, start + size)
                if (end <= start) return null
                return wav.copyOfRange(start, end)
            }
            offset += 8 + size + (size and 1)
        }
        return null
    }

    /** 内置测试音：180→300Hz 扫频，带淡入淡出（避免爆音） */
    private fun probeTone(seconds: Double): ByteArray {
        val sampleRate = 16000
        val total = (sampleRate * seconds).toInt()
        val out = ByteArray(total * 2)
        for (i in 0 until total) {
            val t = i.toDouble() / sampleRate
            val freq = 180.0 + 120.0 * (i.toDouble() / total)
            val fade = when {
                i < total * 0.1 -> i / (total * 0.1)
                i > total * 0.9 -> (total - i) / (total * 0.1)
                else -> 1.0
            }
            val v = (0.35 * fade * 32767 * kotlin.math.sin(2 * Math.PI * freq * t)).toInt()
            out[i * 2] = (v and 0xFF).toByte()
            out[i * 2 + 1] = ((v shr 8) and 0xFF).toByte()
        }
        return out
    }

    /** 释放引擎（供外部宿主在退出时调用） */
    fun shutdown() {
        worker.execute { releaseEngine() }
        worker.shutdown()
    }

    /**
     * **流式链路自检**：模拟"边录边转写"的完整过程。
     *
     * 用 `assets/asr_selftest.wav` 的真实人声，按录音时的节奏（每块 512 采样 ≈32ms）
     * 依次喂给 VAD，模拟说话中的停顿，最后补静音把尾句压出来 —— 与真机录音走的是
     * **完全同一条代码路径**（acceptWaveform → VAD 切句 → 逐句识别 → onResult）。
     *
     * 返回给人看的结论；过程中每识别出一句都会回调 `onResult`，用于验证
     * "实时字幕逐句出现"而不是"录完才一次给"。
     */
    fun runStreamSelfTest(): String {
        val started = System.currentTimeMillis()
        val dir = resolveDir() ?: return "失败：未指定模型目录"
        val err = initEngine(dir)
        if (err != null) return "失败：$err"
        val engine = vad ?: return "失败：VAD 未就绪"
        val pcm = loadSelfTestPcm() ?: return "失败：未找到自检音频（assets/asr_selftest.wav）"
        val samples = pcm16ToFloat(pcm)
        if (samples.isEmpty()) return "失败：自检音频为空"
        return try {
            engine.reset()
            segmentIndex = 0
            sessionResults.clear()

            var offset = 0
            var blocks = 0
            var silenceRun = 0
            val timeline = StringBuilder()
            while (offset < samples.size) {
                val len = minOf(512, samples.size - offset)
                engine.acceptWaveform(samples.copyOfRange(offset, offset + len))
                offset += len
                blocks++

                // 模拟真实说话的节奏：每 ~800ms 插一小段静音（约 250ms）
                if (blocks % 25 == 0) {
                    val silence = FloatArray(512)
                    repeat(8) {
                        engine.acceptWaveform(silence)
                        drain()
                    }
                    silenceRun++
                    if (sessionResults.isNotEmpty()) {
                        timeline.append("[${blocks * 32}ms] ${sessionResults.last()}; ")
                    }
                } else {
                    drain()
                }
            }
            appendSilenceTail()
            drain()
            val ms = System.currentTimeMillis() - started
            val text = sessionResults.joinToString("")
            "通过：${sessionResults.size} 句 / ${ms}ms；逐句时间线：$timeline；合并：$text"
        } catch (e: Throwable) {
            "失败：${e.message}"
        }
    }

    private fun initEngine(dir: String): String? {
        if (recognizer != null && modelDir == dir) return null
        releaseEngine()
        modelDir = dir
        val missing = listOf(vadFile, asrFile, tokensFile).filter { !File(dir, it).exists() }
        if (missing.isNotEmpty()) return "缺少端侧模型文件：${missing.joinToString("、")}"
        return try {
            vad = Vad(
                assetManager = null,
                config = VadModelConfig(
                    sileroVadModelConfig = SileroVadModelConfig(
                        model = File(dir, vadFile).absolutePath,
                        // 0.4 比官方示例的 0.5 更灵敏：手机近距离说话、环境稍吵也能切出句
                        threshold = 0.4f,
                        minSilenceDuration = 0.3f,
                        minSpeechDuration = 0.12f,
                        // 单段上限 20 秒：说话人不停顿时也定期吐出，避免一直攒
                        maxSpeechDuration = 20.0f,
                        windowSize = 512,
                    ),
                    sampleRate = 16000,
                    numThreads = 1,
                    provider = "cpu",
                    debug = false,
                ),
            )
            recognizer = OfflineRecognizer(
                assetManager = null,
                config = OfflineRecognizerConfig(
                    featConfig = FeatureConfig(sampleRate = 16000, featureDim = 80),
                    modelConfig = OfflineModelConfig(
                        paraformer = OfflineParaformerModelConfig(
                            model = File(dir, asrFile).absolutePath,
                        ),
                        tokens = File(dir, tokensFile).absolutePath,
                        // 1 = 串行推理：模拟器/低端机更稳（多线程在部分 x86 模拟器上会崩）
                        numThreads = 1,
                        provider = "cpu",
                        debug = false,
                    ),
                    decodingMethod = "greedy_search",
                ),
            )
            null
        } catch (e: Throwable) {
            releaseEngine()
            "端侧引擎初始化失败：${e.message}"
        }
    }

    private fun releaseEngine() {
        try {
            recognizer?.release()
        } catch (_: Throwable) {
        }
        try {
            vad?.release()
        } catch (_: Throwable) {
        }
        recognizer = null
        vad = null
    }

    private fun feed(bytes: ByteArray) {
        val engine = vad ?: return
        val samples = pcm16ToFloat(bytes)
        try {
            engine.acceptWaveform(samples)
            drain()
        } catch (e: Throwable) {
            emitError("端侧识别异常：${e.message}")
        }
    }

    private fun flush() {
        val engine = vad ?: return
        try {
            engine.flush()
            drain()
        } catch (e: Throwable) {
            emitError("端侧收尾异常：${e.message}")
        }
    }

    /** 把 VAD 已经切好的语音段逐个识别并回吐 */
    private fun drain() {
        val engine = vad ?: return
        val rec = recognizer ?: return
        while (!engine.empty()) {
            val segment = engine.front()
            engine.pop()
            val samples = segment.samples
            if (samples.isEmpty()) continue
            val stream = rec.createStream()
            try {
                stream.acceptWaveform(samples, 16000)
                rec.decode(stream)
                val text = rec.getResult(stream).text.trim()
                if (text.isNotEmpty()) {
                    sessionResults.add(text)
                    val index = segmentIndex++
                    main.post {
                        channel.invokeMethod(
                            "onResult",
                            mapOf("text" to text, "index" to index, "final" to true)
                        )
                    }
                }
            } catch (e: Throwable) {
                emitError("端侧识别失败：${e.message}")
            } finally {
                try {
                    stream.release()
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun emitError(message: String) {
        main.post { channel.invokeMethod("onError", message) }
    }

    /** int16 小端 PCM → [-1, 1] 浮点（sherpa-onnx 入口要求） */
    private fun pcm16ToFloat(bytes: ByteArray): FloatArray {
        val count = bytes.size / 2
        val out = FloatArray(count)
        var i = 0
        while (i < count) {
            val lo = bytes[i * 2].toInt() and 0xFF
            val hi = bytes[i * 2 + 1].toInt()
            val v = ((hi shl 8) or lo).toShort().toInt()
            out[i] = v / 32768.0f
            i++
        }
        return out
    }
}
