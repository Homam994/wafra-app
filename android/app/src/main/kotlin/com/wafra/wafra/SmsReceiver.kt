package com.wafra.wafra

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

// ════════════════════════════════════════════════════════════
//  SmsReceiver v4 — إرسال رسائل متعددة بشكل متسلسل
//
//  الإصلاح الجوهري:
//  بدلاً من إرسال كل الرسائل دفعة واحدة (fire & forget)،
//  ننتظر Flutter يُنهي معالجة كل رسالة (await) قبل إرسال
//  التالية — هذا يضمن تسجيل جميع المشتريات حتى لو وصلت
//  في نفس الثانية
// ════════════════════════════════════════════════════════════
class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_NAME  = "wafra_sms_queue"
        const val KEY_PENDING = "pending_messages"

        // هل الـ flush جارٍ حالياً؟ (لمنع التشغيل المتوازي)
        private var isFlushing = false

        // يُفرَّغ الـ queue رسالةً رسالةً مع انتظار Flutter بعد كل واحدة
        fun flushPendingMessages(context: Context) {
            if (isFlushing) return
            val channel = MainActivity.smsChannel ?: return

            val prefs   = getPrefs(context)
            val raw     = prefs.getString(KEY_PENDING, "[]") ?: "[]"
            val pending = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }
            if (pending.length() == 0) return

            isFlushing = true
            flushNext(context, channel, pending, 0)
        }

        // إرسال رسالة واحدة ثم انتظار Flutter للرد قبل الانتقال للتالية
        private fun flushNext(
            context: Context,
            channel: MethodChannel,
            pending: JSONArray,
            index: Int
        ) {
            if (index >= pending.length()) {
                // انتهينا — امسح الـ queue كله
                getPrefs(context).edit().putString(KEY_PENDING, "[]").apply()
                isFlushing = false
                return
            }

            val obj = try { pending.getJSONObject(index) }
                      catch (_: Exception) {
                          flushNext(context, channel, pending, index + 1)
                          return
                      }

            // يجب استدعاء invokeMethod من الـ main thread
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod(
                    "onSmsReceived",
                    mapOf(
                        "sender"    to obj.optString("sender"),
                        "message"   to obj.optString("message"),
                        "timestamp" to obj.optLong("timestamp", System.currentTimeMillis()),
                    ),
                    // MethodChannel.Result — يُستدعى عندما ينهي Flutter المعالجة
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            // Flutter أنهى معالجة هذه الرسالة → انتقل للتالية
                            flushNext(context, channel, pending, index + 1)
                        }
                        override fun error(code: String, msg: String?, details: Any?) {
                            // خطأ في Flutter → تخطَّ هذه الرسالة وانتقل للتالية
                            flushNext(context, channel, pending, index + 1)
                        }
                        override fun notImplemented() {
                            isFlushing = false
                        }
                    }
                )
            }
        }

        private fun getPrefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        private fun dedupKey(sender: String, message: String): String =
            "$sender|${message.trim()}"
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

            // ── ١. احفظ في الـ queue (مع فحص التكرار بالمحتوى) ──
            val saved = saveToPending(context, sender, fullMessage, timestamp)
            if (!saved) return@forEach

            // ── ٢. إن كان التطبيق مفتوحاً → ابدأ flush فوري ──
            if (MainActivity.smsChannel != null) {
                flushPendingMessages(context)
            }
            // إن كان مغلقاً → الرسالة محفوظة وستُرسَل عند الفتح
        }
    }

    private fun saveToPending(
        context: Context, sender: String, message: String, timestamp: Long
    ): Boolean {
        val prefs   = getPrefs(context)
        val raw     = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        val pending = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }

        // فحص التكرار بـ (sender + message)
        val key = dedupKey(sender, message)
        for (i in 0 until pending.length()) {
            try {
                val obj = pending.getJSONObject(i)
                val existingKey = dedupKey(
                    obj.getString("sender"),
                    obj.getString("message")
                )
                if (existingKey == key) return false
            } catch (_: Exception) {}
        }

        val obj = JSONObject().apply {
            put("sender",    sender)
            put("message",   message)
            put("timestamp", timestamp)
        }
        pending.put(obj)

        val trimmed = if (pending.length() > 50) {
            val t = JSONArray()
            for (i in pending.length() - 50 until pending.length()) t.put(pending.get(i))
            t
        } else pending

        prefs.edit().putString(KEY_PENDING, trimmed.toString()).apply()
        return true
    }
}
