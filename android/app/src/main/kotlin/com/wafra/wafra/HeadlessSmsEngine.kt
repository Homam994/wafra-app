package com.wafra.wafra

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

// ════════════════════════════════════════════════════════════
//  HeadlessSmsEngine
//  محرّك Flutter مستقل بلا واجهة (headless) يُشغَّل مباشرة من
//  SmsReceiver عندما يكون التطبيق مغلقاً تماماً — يسمح بمعالجة
//  رسائل البنوك وتسجيل المعاملة فور وصولها دون فتح التطبيق.
// ════════════════════════════════════════════════════════════
object HeadlessSmsEngine {
    private const val CHANNEL = "com.wafra.wafra/sms_headless"

    // نُبقي مرجعاً واحداً فقط لمنع تشغيل أكثر من محرّك بالتوازي
    // إن وصلت عدة رسائل في نفس اللحظة
    private var engine: FlutterEngine? = null

    fun run(context: Context) {
        if (engine != null) return // معالجة جارية بالفعل

        val appContext = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(appContext)
        }
        loader.ensureInitializationComplete(appContext, null)

        val newEngine = FlutterEngine(appContext)
        engine = newEngine

        val channel = MethodChannel(newEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart يطلب الرسائل المعلَّقة مباشرة من نفس queue الخاص بـ SmsReceiver
                "getPending" -> {
                    val prefs = appContext.getSharedPreferences(
                        SmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(prefs.getString(SmsReceiver.KEY_PENDING, "[]"))
                }
                // بعد أن ينتهي Dart من معالجة كل الرسائل بنجاح
                "clearPending" -> {
                    appContext.getSharedPreferences(
                        SmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                        .edit().putString(SmsReceiver.KEY_PENDING, "[]").apply()
                    result.success(null)
                }
                // انتهى Dart تماماً — أغلق المحرّك ووفّر الذاكرة
                "done" -> {
                    result.success(null)
                    newEngine.destroy()
                    engine = null
                }
                else -> result.notImplemented()
            }
        }

        newEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "smsHeadlessMain")
        )
    }
}
