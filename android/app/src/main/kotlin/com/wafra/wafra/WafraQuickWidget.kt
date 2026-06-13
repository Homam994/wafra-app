package com.wafra.wafra

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class WafraQuickWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { updateQuickWidget(context, appWidgetManager, it) }
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
    val views = RemoteViews(context.packageName, R.layout.widget_quick)

    val expenseIntent = Intent(context, MainActivity::class.java).apply {
        action = "com.wafra.wafra.QUICK_ADD"
        putExtra("type", "expense")
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val incomeIntent = Intent(context, MainActivity::class.java).apply {
        action = "com.wafra.wafra.QUICK_ADD"
        putExtra("type", "income")
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

    views.setOnClickPendingIntent(R.id.btn_expense,
        PendingIntent.getActivity(context, 1, expenseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
    views.setOnClickPendingIntent(R.id.btn_income,
        PendingIntent.getActivity(context, 2, incomeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

    mgr.updateAppWidget(id, views)
}