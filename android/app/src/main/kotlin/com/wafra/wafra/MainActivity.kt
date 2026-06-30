package com.wafra.wafra

import android.Manifest
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
        const val WIDGET_CHANNEL = "com.wafra.wafra/widget"
        const val SMS_PERM_CODE  = 1001
        var smsChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── SMS ──────────────────────────────────────────────
        smsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission"     -> result.success(hasSmsPermission())
                "requestSmsPermission" -> { requestSmsPermission(); result.success(null) }
                "flushPendingMessages" -> {
                    SmsReceiver.flushPendingMessages(this); result.success(null) }
                else -> result.notImplemented()
            }
        }

        // ── Widget update ────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val mgr = android.appwidget.AppWidgetManager.getInstance(this)
                mgr.getAppWidgetIds(android.content.ComponentName(
                    this, WafraStatsWidgetReceiver::class.java))
                    .forEach { updateStatsWidget(this, mgr, it) }
                mgr.getAppWidgetIds(android.content.ComponentName(
                    this, WafraQuickWidgetReceiver::class.java))
                    .forEach { updateQuickWidget(this, mgr, it) }
                result.success(null)
            } else result.notImplemented()
        }
    }

    override fun onResume() {
        super.onResume()
        SmsReceiver.flushPendingMessages(this)
    }

    private fun hasSmsPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) ==
                PackageManager.PERMISSION_GRANTED &&
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) ==
                PackageManager.PERMISSION_GRANTED

    private fun requestSmsPermission() {
        if (!hasSmsPermission())
            ActivityCompat.requestPermissions(this,
                arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                SMS_PERM_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERM_CODE)
            smsChannel?.invokeMethod("onPermissionResult",
                grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED })
    }

    override fun onDestroy() { smsChannel = null; super.onDestroy() }
}
