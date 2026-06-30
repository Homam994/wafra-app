package com.wafra.wafra

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class QuickAddActivity : FlutterActivity() {

    companion object {
        fun createIntent(context: Context, type: String): Intent {
            // النمط الصحيح: نمرر الـ entrypoint عبر الـ Intent extra
            return Intent(context, QuickAddActivity::class.java).apply {
                putExtra("quick_add_type", type)
                // هذا الـ extra يُقرأ بواسطة getDartEntrypointFunctionName
                putExtra("dart_entrypoint", "quickAddMain")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
    }

    private var quickType: String = "expense"

    override fun onCreate(savedInstanceState: Bundle?) {
        quickType = intent?.getStringExtra("quick_add_type") ?: "expense"
        super.onCreate(savedInstanceState)
    }

    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wafra.wafra/quick_standalone"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getType" -> result.success(quickType)
                "close"   -> { result.success(null); finish() }
                else      -> result.notImplemented()
            }
        }
    }

    override fun shouldDestroyEngineWithHost() = true
    override fun getCachedEngineId(): String? = null
}
