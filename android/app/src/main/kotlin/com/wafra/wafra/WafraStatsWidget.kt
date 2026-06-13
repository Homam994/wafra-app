package com.wafra.wafra

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

const val PREFS_NAME   = "WafraWidgetPrefs"
const val KEY_INCOME   = "widget_income"
const val KEY_EXPENSE  = "widget_expense"
const val KEY_CURRENCY = "widget_currency"
const val KEY_MONTH    = "widget_month"

class WafraStatsWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { updateStatsWidget(context, appWidgetManager, it) }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(
            android.content.ComponentName(context, WafraQuickWidgetReceiver::class.java))
        ids.forEach { updateQuickWidget(context, mgr, it) }
    }
}

fun updateStatsWidget(context: Context, mgr: AppWidgetManager, id: Int) {
    val prefs    = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    
    val income   = parseFlutterDouble(prefs.getString("flutter.widget_income",  null))
    val expense  = parseFlutterDouble(prefs.getString("flutter.widget_expense", null))
    val currency = prefs.getString("flutter.widget_currency", "ر.س") ?: "ر.س"
    val month    = prefs.getString("flutter.widget_month",    "") ?: ""
    val net      = income - expense

    val views = RemoteViews(context.packageName, R.layout.widget_stats)
    views.setTextViewText(R.id.widget_month,   month)
    views.setTextViewText(R.id.widget_income,  "${fmt(income)} $currency")
    views.setTextViewText(R.id.widget_expense, "${fmt(expense)} $currency")
    views.setTextViewText(R.id.widget_net,
        "${if (net >= 0) "+" else ""}${fmt(net)} $currency")
    views.setTextColor(R.id.widget_net,
        if (net >= 0) 0xFF27AE60.toInt() else 0xFFE74C3C.toInt())

    val intent = Intent(context, MainActivity::class.java)
    val pi = PendingIntent.getActivity(context, 0, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    views.setOnClickPendingIntent(R.id.widget_title, pi)

    mgr.updateAppWidget(id, views)
}

private fun parseFlutterDouble(raw: String?): Double {
    if (raw == null) return 0.0
    // Flutter prefix: "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"
    val prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"
    return if (raw.startsWith(prefix)) {
        raw.substring(prefix.length).toDoubleOrNull() ?: 0.0
    } else {
        raw.toDoubleOrNull() ?: 0.0
    }
}

private fun fmt(v: Double): String {
    val nf = java.text.NumberFormat.getInstance(java.util.Locale("en"))
    nf.maximumFractionDigits = 2
    nf.minimumFractionDigits = 0
    return nf.format(v)
}