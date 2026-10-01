package com.wisal.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val firedAt = System.currentTimeMillis()
        val ok = JSONObject(Sync.run(ctx)).optBoolean("ok")
        Log.d("Wisal", "ReminderAlarmReceiver fired, sync ok=$ok overdue=${Store.overdue(ctx).length()}")
        if (ok) Notifier.postReminder(ctx, Store.config(ctx), Store.overdue(ctx))
        Alarms.rearmReminderAfterFire(ctx, firedAt)
    }
}
