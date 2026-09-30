package com.wisal.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** Keeps the overdue cache and widget fresh; actual notification timing is owned by Alarms/the two alarm receivers. */
class SyncWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result = try {
        val r = JSONObject(Sync.run(applicationContext))
        if (!r.optBoolean("ok") && r.optString("reason") == "provider_unavailable") Result.retry() else Result.success()
    } catch (e: Exception) {
        Result.retry()
    }
}

object Scheduler {
    fun set(ctx: Context, on: Boolean) {
        val wm = WorkManager.getInstance(ctx)
        if (on) {
            wm.enqueueUniquePeriodicWork(
                "wisal_sync",
                ExistingPeriodicWorkPolicy.UPDATE,
                PeriodicWorkRequestBuilder<SyncWorker>(6, TimeUnit.HOURS).build()
            )
        } else {
            wm.cancelUniqueWork("wisal_sync")
        }
    }
}

object Notifier {
    private const val CH_REMINDER = "wisal_reminder"
    private const val CH_SENTENCE = "wisal_sentence"

    private fun ar(cfg: JSONObject) = cfg.optString("language", "ar") != "en"
    private fun t(cfg: JSONObject, en: String, arText: String) = if (ar(cfg)) arText else en

    private fun channel(ctx: Context, id: String, name: String) {
        if (Build.VERSION.SDK_INT >= 26) {
            ctx.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(NotificationChannel(id, name, NotificationManager.IMPORTANCE_DEFAULT))
        }
    }

    private fun openAppIntent(ctx: Context) = PendingIntent.getActivity(
        ctx, 0, Intent(ctx, MainActivity::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    /** Fired by ReminderAlarmReceiver at the user's chosen time/cadence — no extra gating here, the alarm is the schedule. */
    fun postReminder(ctx: Context, cfg: JSONObject, overdue: JSONArray) {
        val reminderOn = cfg.optJSONObject("notifications")?.optBoolean("reminderEnabled", true) ?: true
        if (!reminderOn) { Log.d("Wisal", "postReminder skipped: reminderEnabled=false"); return }
        if (overdue.length() == 0) { Log.d("Wisal", "postReminder skipped: nobody overdue"); return }
        val nm = NotificationManagerCompat.from(ctx)
        if (!nm.areNotificationsEnabled()) { Log.d("Wisal", "postReminder skipped: app notifications blocked by OS"); return }
        channel(ctx, CH_REMINDER, t(cfg, "Reminders", "التذكيرات"))

        val names = (0 until overdue.length()).map { overdue.getJSONObject(it).getString("name") }
        val n = names.size
        val title = if (n == 1) t(cfg, "1 person to reconnect with", "شخص واحد بانتظار تواصلك")
        else t(cfg, "$n people to reconnect with", "$n أشخاص بانتظار تواصلك")
        val text = names.take(5).joinToString(" · ") + if (n > 5) " +${n - 5}" else ""

        val notif = NotificationCompat.Builder(ctx, CH_REMINDER)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openAppIntent(ctx))
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(1001, notif)
        } catch (e: SecurityException) {
        }
    }

    /** Fired by SentenceAlarmReceiver — the sentence itself stays in its original Arabic regardless of app language. */
    fun postSentence(ctx: Context, cfg: JSONObject, sentence: String) {
        val sentenceOn = cfg.optJSONObject("notifications")?.optBoolean("sentenceEnabled", true) ?: true
        if (!sentenceOn) { Log.d("Wisal", "postSentence skipped: sentenceEnabled=false"); return }
        val nm = NotificationManagerCompat.from(ctx)
        if (!nm.areNotificationsEnabled()) { Log.d("Wisal", "postSentence skipped: app notifications blocked by OS"); return }
        channel(ctx, CH_SENTENCE, t(cfg, "Daily sentence", "تذكير اليوم"))

        val notif = NotificationCompat.Builder(ctx, CH_SENTENCE)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(t(cfg, "Today's reminder", "تذكير اليوم"))
            .setContentText(sentence)
            .setStyle(NotificationCompat.BigTextStyle().bigText(sentence))
            .setContentIntent(openAppIntent(ctx))
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(1002, notif)
        } catch (e: SecurityException) {
        }
    }

    /** Posts immediately, ignoring every toggle/overdue/cadence gate — isolates "can this app show a
     *  notification at all" (OS permission/channel) from "did the alarm fire on schedule". */
    fun postTest(ctx: Context, cfg: JSONObject): String {
        val nm = NotificationManagerCompat.from(ctx)
        if (!nm.areNotificationsEnabled()) return "blocked_by_os"
        channel(ctx, CH_REMINDER, t(cfg, "Reminders", "التذكيرات"))
        val notif = NotificationCompat.Builder(ctx, CH_REMINDER)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(t(cfg, "Test notification", "إشعار تجريبي"))
            .setContentText(t(cfg, "If you can see this, notifications work.", "إذا رأيت هذا، فالإشعارات تعمل."))
            .setContentIntent(openAppIntent(ctx))
            .setAutoCancel(true)
            .build()
        return try {
            nm.notify(9999, notif)
            "posted"
        } catch (e: SecurityException) {
            "security_exception"
        }
    }
}
