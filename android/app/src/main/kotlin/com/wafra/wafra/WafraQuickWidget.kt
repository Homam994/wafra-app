package com.wafra.wafra

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class WafraQuickWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateQuickWidget(context, mgr, it) }
    }
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(
            android.content.ComponentName(context, WafraQuickWidgetReceiver::class.java))
        ids.forEach { updateQuickWidget(context, mgr, it) }
    }
}

fun updateQuickWidget(context: Context, mgr: AppWidgetManager, id: Int) {
    val prefs  = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    val lang   = prefs.getString("flutter.language", "ar") ?: "ar"
    val isDark = prefs.getBoolean("flutter.isDark", true)

    val views = RemoteViews(context.packageName, R.layout.widget_quick)

    val bgColor = if (isDark) 0xCC0D0D14.toInt() else 0xCCF5F3EE.toInt()
    views.setInt(R.id.widget_quick_root, "setBackgroundColor", bgColor)

    views.setTextViewText(R.id.widget_expense_btn_label,
        if (lang == "ar") "مصروف" else "Expense")
    views.setTextViewText(R.id.widget_income_btn_label,
        if (lang == "ar") "دخل" else "Income")

    // استخدم QuickAddActivity.createIntent لضمان صحة الـ entry point
    val expIntent = QuickAddActivity.createIntent(context, "expense")
    val incIntent = QuickAddActivity.createIntent(context, "income")

    views.setOnClickPendingIntent(R.id.btn_expense,
        PendingIntent.getActivity(context, 1, expIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
    views.setOnClickPendingIntent(R.id.btn_income,
        PendingIntent.getActivity(context, 2, incIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

    mgr.updateAppWidget(id, views)
}
