package com.wisal.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class NotifSchedule(val enabled: Boolean, val hour: Int, val minute: Int, val cadenceDays: Int)

/** Config mirrored from Flutter (lists, members, settings) plus computed results. */
object Store {
    private fun p(ctx: Context) = ctx.getSharedPreferences("wisal", Context.MODE_PRIVATE)

    fun config(ctx: Context): JSONObject =
        try { JSONObject(p(ctx).getString("config", "{}") ?: "{}") } catch (e: Exception) { JSONObject() }

    fun saveConfig(ctx: Context, json: String) = p(ctx).edit().putString("config", json).apply()

    fun overdue(ctx: Context): JSONArray =
        try { JSONArray(p(ctx).getString("overdue", "[]") ?: "[]") } catch (e: Exception) { JSONArray() }

    fun saveOverdue(ctx: Context, a: JSONArray) = p(ctx).edit().putString("overdue", a.toString()).apply()

    fun language(ctx: Context): String = config(ctx).optString("language", "ar")

    private fun notifications(ctx: Context): JSONObject = config(ctx).optJSONObject("notifications") ?: JSONObject()

    fun reminderSchedule(ctx: Context): NotifSchedule {
        val n = notifications(ctx)
        return NotifSchedule(
            enabled = n.optBoolean("reminderEnabled", true),
            hour = n.optInt("reminderHour", 18),
            minute = n.optInt("reminderMinute", 0),
            cadenceDays = n.optInt("reminderCadenceDays", 1)
        )
    }

    fun sentenceSchedule(ctx: Context): NotifSchedule {
        val n = notifications(ctx)
        return NotifSchedule(
            enabled = n.optBoolean("sentenceEnabled", true),
            hour = n.optInt("sentenceHour", 8),
            minute = n.optInt("sentenceMinute", 0),
            cadenceDays = 1
        )
    }
}
