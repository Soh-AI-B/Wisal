package com.wisal.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** AlarmManager alarms don't survive a reboot, so re-arm both notifications from stored config. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Alarms.rescheduleFromConfig(ctx)
        }
    }
}
