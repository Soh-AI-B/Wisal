package com.wisal.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class SentenceAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val firedAt = System.currentTimeMillis()
        val sentence = Sentences.today(ctx)
        Log.d("Wisal", "SentenceAlarmReceiver fired, sentence=${sentence != null}")
        sentence?.let { Notifier.postSentence(ctx, Store.config(ctx), it) }
        Alarms.rearmSentenceAfterFire(ctx, firedAt)
    }
}
