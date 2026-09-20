package cn.yooss.moodiary

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Bundle
import android.webkit.MimeTypeMap
import com.github.gzuliyujiang.oaid.DeviceID
import com.github.gzuliyujiang.oaid.IGetter
import java.io.File
import java.util.ArrayList
import java.util.UUID
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private var multicastLock: WifiManager.MulticastLock? = null

class MainActivity : FlutterFragmentActivity() {

    private var shareChannel: MethodChannel? = null
    private var pendingShare: String? = null
    private var pendingShareImages: ArrayList<String> = ArrayList()
    private var pendingShortcut: String? = null

    /** 端侧转写引擎桥（自检钩子复用） */
    private var pendingAsr: AsrChannel? = null

    /** `--es ASR selftest`：在后台跑一次端侧引擎自检，结论写 Logcat */
    private fun maybeRunAsrSelftest(source: Intent?) {
        val mode = source?.getStringExtra("ASR") ?: return
        if (mode != "selftest" && mode != "streamtest") return
        val bridge = pendingAsr ?: return
        Thread {
            val started = System.currentTimeMillis()
            val result = if (mode == "streamtest") {
                bridge.runStreamSelfTest()
            } else {
                bridge.runSelfTest()
            }
            android.util.Log.i(
                if (mode == "streamtest") "AsrStreamTest" else "AsrSelftest",
                "$result（总耗时 ${System.currentTimeMillis() - started}ms）"
            )
        }.start()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动由分享/快捷方式触发时，先记录负载，待 Dart 侧就绪后取回
        pendingShare = extractShareText(intent)
        pendingShortcut = extractShortcut(intent)
        pendingShareImages = extractShareImages(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "oaid_channel"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getOAID" -> {
                    getOAID(result)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
        // 局域网同步：Android 接收 UDP 广播需要 WifiManager.MulticastLock，
        // 否则 Wi-Fi 驱动会把入站广播直接丢弃（Dart 端 LocalSend 使用）。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "wifi_multicast_channel"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> acquireMulticastLock(result)
                "release" -> releaseMulticastLock(result)
                else -> result.notImplemented()
            }
        }
        // 系统分享 / 桌面快捷方式接收：文本、图片 → Dart；长按图标快捷方式 → Dart
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "share_channel"
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialShare" -> {
                        result.success(pendingShare)
                        pendingShare = null
                    }

                    "getInitialShareImages" -> {
                        result.success(ArrayList(pendingShareImages))
                        pendingShareImages = ArrayList()
                    }

                    "getInitialShortcut" -> {
                        result.success(pendingShortcut)
                        pendingShortcut = null
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // 端侧实时转写：Dart 送 PCM，Kotlin 侧做 VAD 切句 + Paraformer int8 识别后回吐文本
        val asrChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "asr_channel"
        )
        val asr = AsrChannel(
            asrChannel,
            File(filesDir, "asr").absolutePath,
            assets,
        )
        asrChannel.setMethodCallHandler { call, result -> asr.handle(call, result) }

        // 现场自检钩子：adb shell am start -n <pkg>/cn.yooss.moodiary.MainActivity --es ASR selftest
        // 结果打到 Logcat（TAG=AsrSelftest），方便真机/模拟器无 UI 验证端侧链路。
        pendingAsr = asr
        maybeRunAsrSelftest(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeRunAsrSelftest(intent)
        val shortcut = extractShortcut(intent)
        if (shortcut != null) {
            deliver("onShortcut", shortcut) { pendingShortcut = it }
            return
        }
        val text = extractShareText(intent)
        if (text != null) {
            deliver("onShare", text) { pendingShare = it }
        }
        val images = extractShareImages(intent)
        if (images.isNotEmpty()) {
            val channel = shareChannel
            if (channel != null) {
                channel.invokeMethod("onShareImages", images)
            } else {
                pendingShareImages = images
            }
        }
    }

    /** 有通道就直接投递，否则挂起等待 Dart 侧取回（冷启动）。 */
    private fun deliver(method: String, payload: String, park: (String) -> Unit) {
        val channel = shareChannel
        if (channel != null) {
            channel.invokeMethod(method, payload)
        } else {
            park(payload)
        }
    }

    private fun extractShareText(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
    }

    /** 长按图标的快捷方式入口（短按启动则是普通 LAUNCHER，无该 extra）。 */
    private fun extractShortcut(intent: Intent?): String? {
        return intent?.getStringExtra("shortcut_id")
    }

    /**
     * 分享进来的图片/文件（ACTION_SEND / ACTION_SEND_MULTIPLE + EXTRA_STREAM）：
     * 逐个复制到私有缓存目录，再把本地路径列表交给 Dart（避免依赖外部 URI 权限）。
     */
    private fun extractShareImages(intent: Intent?): ArrayList<String> {
        val results = ArrayList<String>()
        if (intent == null) return results
        val multiple = intent.action == Intent.ACTION_SEND_MULTIPLE
        if (intent.action != Intent.ACTION_SEND && !multiple) return results

        val mime = intent.type ?: ""
        // 只接管图片与常见文档；纯文本分享仍走文本链路
        val acceptImage = mime.startsWith("image/")
        val acceptDocument = mime == "application/pdf" ||
            mime.startsWith("application/msword") ||
            mime.startsWith("application/vnd.openxmlformats") ||
            mime.startsWith("text/") && mime != "text/plain"
        if (!acceptImage && !acceptDocument) return results

        @Suppress("DEPRECATION")
        val uris: List<Uri> = collectSharedUris(intent, multiple)
        for (uri in uris) {
            copySharedUri(uri, acceptImage)?.let { results.add(it) }
        }
        return results
    }

    /**
     * 兼容三种分享来源（真机踩坑）：
     * 1) 相册/文件管理器：`EXTRA_STREAM` = ArrayList&lt;Uri&gt;（API 33+ 也可能是单个 Uri）；
     * 2) `am` 或部分老应用：`EXTRA_STREAM` = String[] / String；
     * 3) 新式分享：只给 `clipData`。
     */
    @Suppress("DEPRECATION")
    private fun collectSharedUris(intent: Intent, multiple: Boolean): List<Uri> {
        val uris = ArrayList<Uri>()
        if (multiple) {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                ?.let { uris.addAll(it) }
        }
        if (uris.isEmpty()) {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
        }
        if (uris.isEmpty()) {
            intent.getStringArrayListExtra(Intent.EXTRA_STREAM)?.forEach { value ->
                value.toUriOrNull()?.let { uris.add(it) }
            }
        }
        // `adb shell am --esa` 与部分老应用给的是 String[]（不是 ArrayList<String>）
        if (uris.isEmpty()) {
            intent.getStringArrayExtra(Intent.EXTRA_STREAM)?.forEach { value ->
                value.toUriOrNull()?.let { uris.add(it) }
            }
        }
        if (uris.isEmpty()) {
            intent.getStringExtra(Intent.EXTRA_STREAM)?.toUriOrNull()?.let { uris.add(it) }
        }
        if (uris.isEmpty()) {
            intent.clipData?.let { clip ->
                for (i in 0 until clip.itemCount) {
                    clip.getItemAt(i)?.uri?.let { uris.add(it) }
                }
            }
        }
        return uris
    }

    private fun String.toUriOrNull(): Uri? {
        val text = trim().trim('[', ']', '"')
        if (text.isEmpty()) return null
        return try {
            Uri.parse(text)
        } catch (e: Exception) {
            null
        }
    }

    /** 单个分享 URI → 本地缓存文件路径；失败返回 null。 */
    private fun copySharedUri(uri: Uri, isImage: Boolean): String? {
        return try {
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val mime = contentResolver.getType(uri)
                ?: if (isImage) "image/jpeg" else "application/octet-stream"
            val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
                ?: if (isImage) "jpg" else "bin"
            val target = File(dir, "shared-${UUID.randomUUID()}.$ext")
            val input = if (uri.scheme == "file") {
                uri.path?.let { File(it).inputStream() }
            } else {
                contentResolver.openInputStream(uri)
            } ?: return null
            input.use { source -> target.outputStream().use { source.copyTo(it) } }
            if (target.length() <= 0L) null else target.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    @SuppressLint("WifiManagerLeak")
    private fun acquireMulticastLock(result: MethodChannel.Result) {
        try {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (multicastLock == null) {
                multicastLock = wifiManager.createMulticastLock("moodiary_lan_sync").apply {
                    setReferenceCounted(false)
                }
            }
            if (!multicastLock!!.isHeld) {
                multicastLock!!.acquire()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("multicast_lock_error", e.message, null)
        }
    }

    private fun releaseMulticastLock(result: MethodChannel.Result) {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock!!.release()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("multicast_lock_error", e.message, null)
        }
    }

    private fun getOAID(resultCallback: MethodChannel.Result) {
        if (DeviceID.supportedOAID(application)) {
            DeviceID.getOAID(application, HandleGetOAID(resultCallback))
        } else {
            resultCallback.success(null)
        }
    }

}

class HandleGetOAID(private var resultCallback: MethodChannel.Result) : IGetter {
    override fun onOAIDGetComplete(result: String) {
        resultCallback.success(result)
    }

    override fun onOAIDGetError(error: Exception?) {
        resultCallback.success(null)
    }
}
