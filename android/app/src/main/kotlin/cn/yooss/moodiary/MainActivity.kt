package cn.yooss.moodiary

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Bundle
import com.github.gzuliyujiang.oaid.DeviceID
import com.github.gzuliyujiang.oaid.IGetter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private var multicastLock: WifiManager.MulticastLock? = null

class MainActivity : FlutterFragmentActivity() {

    private var shareChannel: MethodChannel? = null
    private var pendingShare: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动由分享触发时，先记录分享文本，待 Dart 侧就绪后取回
        pendingShare = extractShare(intent)
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
        // 系统分享接收：ACTION_SEND 文本 → Dart（链接采集 / 速记）
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "share_channel"
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialShare" -> {
                        result.success(pendingShare)
                        pendingShare = null
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractShare(intent) ?: return
        val channel = shareChannel
        if (channel != null) {
            channel.invokeMethod("onShare", text)
        } else {
            pendingShare = text
        }
    }

    private fun extractShare(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
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
