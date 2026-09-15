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
import java.util.UUID
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private var multicastLock: WifiManager.MulticastLock? = null

class MainActivity : FlutterFragmentActivity() {

    private var shareChannel: MethodChannel? = null
    private var pendingShare: String? = null
    private var pendingShareImage: String? = null
    private var pendingShortcut: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动由分享/快捷方式触发时，先记录负载，待 Dart 侧就绪后取回
        pendingShare = extractShareText(intent)
        pendingShortcut = extractShortcut(intent)
        pendingShareImage = extractShareImage(intent)
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

                    "getInitialShareImage" -> {
                        result.success(pendingShareImage)
                        pendingShareImage = null
                    }

                    "getInitialShortcut" -> {
                        result.success(pendingShortcut)
                        pendingShortcut = null
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val shortcut = extractShortcut(intent)
        if (shortcut != null) {
            deliver("onShortcut", shortcut) { pendingShortcut = it }
            return
        }
        val text = extractShareText(intent)
        if (text != null) {
            deliver("onShare", text) { pendingShare = it }
        }
        val image = extractShareImage(intent)
        if (image != null) {
            deliver("onShareImage", image) { pendingShareImage = it }
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
     * 分享进来的图片/文件（ACTION_SEND + EXTRA_STREAM）：
     * 复制到私有缓存目录后把本地路径交给 Dart，避免依赖外部 URI 权限。
     */
    private fun extractShareImage(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        @Suppress("DEPRECATION")
        val uri: Uri = intent.getParcelableExtra(Intent.EXTRA_STREAM) ?: return null
        val mime = intent.type ?: "image/jpeg"
        if (!mime.startsWith("image/")) return null
        return try {
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "jpg"
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
