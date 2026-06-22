package com.wafra.wafra

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val SMS_CHANNEL    = "com.wafra.wafra/sms"
        const val QUICK_CHANNEL  = "com.wafra.wafra/quick_add"
        const val WIDGET_CHANNEL = "com.wafra.wafra/widget"
        const val SMS_PERM_REQUEST = 1001
        var smsChannel:   MethodChannel? = null
        var quickChannel: MethodChannel? = null
    }

    // نحفظ الـ type فور وصول الـ Intent
    private var pendingQuickType: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // احفظ الـ type من Intent البداية
        extractQuickType(intent)?.let { pendingQuickType = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // التطبيق مفتوح بالفعل — أرسل مباشرة
        extractQuickType(intent)?.let { type ->
            quickChannel?.invokeMethod("openQuickAdd", type)
                ?: run { pendingQuickType = type }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── SMS Channel ──────────────────────────────────
        smsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission"     -> result.success(hasSmsPermission())
                "requestSmsPermission" -> { requestSmsPermission(); result.success(null) }
                "flushPendingMessages" -> { SmsReceiver.flushPendingMessages(this); result.success(null) }
                else -> result.notImplemented()
            }
        }

        // ── Widget Update Channel ────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val mgr = android.appwidget.AppWidgetManager.getInstance(this)

                // تحديث Stats Widget مباشرة بدون broadcast
                val statsIds = mgr.getAppWidgetIds(
                    android.content.ComponentName(this, WafraStatsWidgetReceiver::class.java))
                statsIds.forEach { updateStatsWidget(this, mgr, it) }

                // تحديث Quick Widget مباشرة
                val quickIds = mgr.getAppWidgetIds(
                    android.content.ComponentName(this, WafraQuickWidgetReceiver::class.java))
                quickIds.forEach { updateQuickWidget(this, mgr, it) }

                result.success(null)
            } else result.notImplemented()
        }

        // ── Quick Add Channel ────────────────────────────
        quickChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, QUICK_CHANNEL)
        quickChannel!!.setMethodCallHandler { call, result ->
            // Flutter يسأل: هل يوجد quickType معلّق؟
            if (call.method == "getInitialQuickType") {
                result.success(pendingQuickType)
                pendingQuickType = null // امسح بعد القراءة
            } else {
                result.notImplemented()
            }
        }
    }

    private fun extractQuickType(intent: Intent?): String? {
        if (intent?.action == "com.wafra.wafra.QUICK_ADD") {
            return intent.getStringExtra("type") ?: "expense"
        }
        return null
    }

    override fun onResume() {
        super.onResume()
        android.os.Handler(mainLooper).postDelayed({
            SmsReceiver.flushPendingMessages(this)
        }, 800)
    }

    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) ==
                PackageManager.PERMISSION_GRANTED &&
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) ==
                PackageManager.PERMISSION_GRANTED

    private fun requestSmsPermission() {
        if (!hasSmsPermission()) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                SMS_PERM_REQUEST)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERM_REQUEST) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            smsChannel?.invokeMethod("onPermissionResult", granted)
        }
    }

    override fun onDestroy() {
        smsChannel   = null
        quickChannel = null
        super.onDestroy()
    }
}
