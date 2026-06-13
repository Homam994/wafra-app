package com.wafra.wafra

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject

// ════════════════════════════════════════════════════════════
//  SmsReceiver v2 — يعمل حتى لو كان التطبيق مغلقاً
//
//  الحل:
//  ١. يحفظ الرسائل في SharedPreferences (queue محلي)
//  ٢. يحاول إرسالها لـ Flutter إن كان التطبيق مفتوحاً
//  ٣. عند فتح التطبيق يُفرَّغ الـ queue تلقائياً
// ════════════════════════════════════════════════════════════
class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_NAME  = "wafra_sms_queue"
        const val KEY_PENDING = "pending_messages"

        // يُفرَّغ الـ queue عند فتح التطبيق
        fun flushPendingMessages(context: Context) {
            val prefs    = getPrefs(context)
            val raw      = prefs.getString(KEY_PENDING, "[]") ?: "[]"
            val pending  = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }

            if (pending.length() == 0) return

            val channel = MainActivity.smsChannel ?: return

            val sent = mutableListOf<Int>()
            for (i in 0 until pending.length()) {
                try {
                    val obj = pending.getJSONObject(i)
                    channel.invokeMethod(
                        "onSmsReceived",
                        mapOf(
                            "sender"    to obj.getString("sender"),
                            "message"   to obj.getString("message"),
                            "timestamp" to obj.getLong("timestamp"),
                        )
                    )
                    sent.add(i)
                } catch (_: Exception) { break } // channel غير جاهز بعد
            }

            // احذف الرسائل التي أُرسلت
            if (sent.size == pending.length()) {
                // كلها أُرسلت — امسح الكل
                prefs.edit().putString(KEY_PENDING, "[]").apply()
            } else if (sent.isNotEmpty()) {
                // بعضها — احذف المُرسَلة فقط
                val remaining = JSONArray()
                for (i in 0 until pending.length()) {
                    if (i !in sent) remaining.put(pending.get(i))
                }
                prefs.edit().putString(KEY_PENDING, remaining.toString()).apply()
            }
        }

        private fun getPrefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val grouped = messages.groupBy { it.originatingAddress ?: "" }

        grouped.forEach { (sender, parts) ->
            if (sender.isEmpty()) return@forEach
            val fullMessage = parts.joinToString("") { it.messageBody ?: "" }
            if (fullMessage.isEmpty()) return@forEach
            val timestamp = parts.firstOrNull()?.timestampMillis
                ?: System.currentTimeMillis()

            // ── ١. احفظ في الـ queue دائماً ────────────────
            saveToPending(context, sender, fullMessage, timestamp)

            // ── ٢. حاول الإرسال الفوري إن كان التطبيق مفتوحاً
            val channel = MainActivity.smsChannel
            if (channel != null) {
                try {
                    channel.invokeMethod(
                        "onSmsReceived",
                        mapOf(
                            "sender"    to sender,
                            "message"   to fullMessage,
                            "timestamp" to timestamp,
                        )
                    )
                    // نجح — احذف من الـ queue
                    removeFromPending(context, timestamp)
                } catch (_: Exception) {
                    // فشل — سيُعالَج عند فتح التطبيق
                }
            }
            // إن كان channel == null → الرسالة محفوظة في queue ✅
        }
    }

    private fun saveToPending(
        context: Context, sender: String, message: String, timestamp: Long
    ) {
        val prefs   = getPrefs(context)
        val raw     = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        val pending = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }

        // تجنّب التكرار بنفس الـ timestamp
        for (i in 0 until pending.length()) {
            try {
                if (pending.getJSONObject(i).getLong("timestamp") == timestamp) return
            } catch (_: Exception) {}
        }

        val obj = JSONObject().apply {
            put("sender",    sender)
            put("message",   message)
            put("timestamp", timestamp)
        }
        pending.put(obj)

        // احتفظ بآخر 50 رسالة فقط (تجنّب تراكم البيانات)
        val trimmed = if (pending.length() > 50) {
            val t = JSONArray()
            for (i in pending.length() - 50 until pending.length()) t.put(pending.get(i))
            t
        } else pending

        prefs.edit().putString(KEY_PENDING, trimmed.toString()).apply()
    }

    private fun removeFromPending(context: Context, timestamp: Long) {
        val prefs   = getPrefs(context)
        val raw     = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        val pending = try { JSONArray(raw) } catch (_: Exception) { return }
        val updated = JSONArray()
        for (i in 0 until pending.length()) {
            try {
                if (pending.getJSONObject(i).getLong("timestamp") != timestamp)
                    updated.put(pending.get(i))
            } catch (_: Exception) {}
        }
        prefs.edit().putString(KEY_PENDING, updated.toString()).apply()
    }
}
