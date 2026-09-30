package com.wisal.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/** Schedules the two user-configurable notifications with AlarmManager (WorkManager can't hit an exact clock time). */
object Alarms {
    private const val REQ_REMINDER = 101
    private const val REQ_SENTENCE = 102

    private fun mgr(ctx: Context) = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pendingIntent(ctx: Context, cls: Class<*>, req: Int): PendingIntent =
        PendingIntent.getBroadcast(
            ctx, req, Intent(ctx, cls),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

    private fun canExact(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < 31 || mgr(ctx).canScheduleExactAlarms()

    private fun set(ctx: Context, triggerAt: Long, pi: PendingIntent) {
        val am = mgr(ctx)
        try {
            if (canExact(ctx)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                Log.d("Wisal", "alarm set exact for ${java.util.Date(triggerAt)}")
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                Log.d("Wisal", "alarm set inexact (no exact-alarm permission) for ${java.util.Date(triggerAt)}")
            }
        } catch (e: SecurityException) {
            // Some OEMs revoke the exact-alarm grant between the canScheduleExactAlarms() check and the call.
            Log.w("Wisal", "exact alarm denied at call time, falling back to inexact", e)
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    /** The next occurrence of hour:minute that's still in the future (today, else tomorrow). */
    private fun nextFromNow(hour: Int, minute: Int): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, minute)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        if (cal.timeInMillis <= System.currentTimeMillis()) cal.add(Calendar.DAY_OF_YEAR, 1)
        return cal.timeInMillis
    }

    /** cadenceDays after a previous firing, same clock time — keeps the cycle exact, immune to drift. */
    private fun nextAfterFire(previousTrigger: Long, cadenceDays: Int): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = previousTrigger
        cal.add(Calendar.DAY_OF_YEAR, cadenceDays.coerceAtLeast(1))
        if (cal.timeInMillis <= System.currentTimeMillis()) {
            return nextFromNow(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
        }
        return cal.timeInMillis
    }

    fun scheduleReminder(ctx: Context) {
        val s = Store.reminderSchedule(ctx)
        val pi = pendingIntent(ctx, ReminderAlarmReceiver::class.java, REQ_REMINDER)
        if (!s.enabled) { mgr(ctx).cancel(pi); return }
        set(ctx, nextFromNow(s.hour, s.minute), pi)
    }

    fun rearmReminderAfterFire(ctx: Context, firedAt: Long) {
        val s = Store.reminderSchedule(ctx)
        val pi = pendingIntent(ctx, ReminderAlarmReceiver::class.java, REQ_REMINDER)
        if (!s.enabled) { mgr(ctx).cancel(pi); return }
        set(ctx, nextAfterFire(firedAt, s.cadenceDays), pi)
    }

    fun scheduleSentence(ctx: Context) {
        val s = Store.sentenceSchedule(ctx)
        val pi = pendingIntent(ctx, SentenceAlarmReceiver::class.java, REQ_SENTENCE)
        if (!s.enabled) { mgr(ctx).cancel(pi); return }
        set(ctx, nextFromNow(s.hour, s.minute), pi)
    }

    fun rearmSentenceAfterFire(ctx: Context, firedAt: Long) {
        val s = Store.sentenceSchedule(ctx)
        val pi = pendingIntent(ctx, SentenceAlarmReceiver::class.java, REQ_SENTENCE)
        if (!s.enabled) { mgr(ctx).cancel(pi); return }
        set(ctx, nextAfterFire(firedAt, s.cadenceDays), pi)
    }

    /** Call after every config save: re-arms whichever notifications are enabled from a fresh "next occurrence" baseline. */
    fun rescheduleFromConfig(ctx: Context) {
        scheduleReminder(ctx)
        scheduleSentence(ctx)
    }
}
