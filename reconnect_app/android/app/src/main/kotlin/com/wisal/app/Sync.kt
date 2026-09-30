package com.wisal.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CallLog
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/** All phone-number matching lives here. Change CC if your default country is not Algeria. */
object PhoneNormalizer {
    private const val CC = "213"

    fun normalize(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        val t = raw.trim()
        val d = t.filter { it.isDigit() }
        if (d.isEmpty()) return ""
        if (t.startsWith("+")) return d
        if (d.startsWith("00")) return d.substring(2)
        if (d.startsWith("0")) return CC + d.substring(1)
        if (d.length == 9) return CC + d
        return d
    }
}

object Contacts {
    fun list(ctx: Context): List<Map<String, String>> {
        val out = ArrayList<Map<String, String>>()
        ctx.contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            arrayOf(ContactsContract.Contacts.LOOKUP_KEY, ContactsContract.Contacts.DISPLAY_NAME_PRIMARY),
            "${ContactsContract.Contacts.HAS_PHONE_NUMBER} = 1",
            null,
            "${ContactsContract.Contacts.DISPLAY_NAME_PRIMARY} COLLATE NOCASE ASC"
        )?.use { c ->
            while (c.moveToNext()) {
                val k = c.getString(0) ?: continue
                out.add(mapOf("key" to k, "name" to (c.getString(1) ?: k)))
            }
        }
        return out
    }
}

object Sync {
    private const val DAY = 86_400_000L

    /** A call under this length is a missed pickup / voicemail bounce, not a real conversation. */
    private const val MIN_CALL_SECONDS = 10

    private fun notOk(reason: String) =
        JSONObject().put("ok", false).put("reason", reason).put("calls", JSONObject()).toString()

    private fun has(ctx: Context, p: String) =
        ContextCompat.checkSelfPermission(ctx, p) == PackageManager.PERMISSION_GRANTED

    /**
     * Returns {"ok": Boolean, "calls": {lookupKey: {at, dir, phone}}}.
     * ok=false means a required permission is missing: nothing is computed or overwritten.
     * With ok=true, members without a matching call are simply absent from "calls".
     */
    fun run(ctx: Context): String {
        if (!has(ctx, Manifest.permission.READ_CONTACTS) || !has(ctx, Manifest.permission.READ_CALL_LOG)) {
            return notOk("missing_permission")
        }
        val cfg = Store.config(ctx)
        val members = cfg.optJSONArray("members") ?: JSONArray()
        val keys = HashSet<String>()
        for (i in 0 until members.length()) keys.add(members.getJSONObject(i).getString("key"))

        // Only the selected contacts' numbers (chunked to stay under SQLite's variable limit).
        val phones = HashMap<String, MutableList<String>>()
        for (chunk in keys.chunked(500)) {
            val cur = ctx.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.LOOKUP_KEY,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                "${ContactsContract.CommonDataKinds.Phone.LOOKUP_KEY} IN (${chunk.joinToString(",") { "?" }})",
                chunk.toTypedArray(),
                null
            ) ?: return notOk("provider_unavailable") // null cursor = provider failure, not "no contacts"
            cur.use { c ->
                while (c.moveToNext()) {
                    val k = c.getString(0) ?: continue
                    val n = c.getString(1) ?: continue
                    phones.getOrPut(k) { mutableListOf() }.add(n)
                }
            }
        }
        val targets = HashSet<String>()
        phones.values.forEach { l -> l.forEach { n -> PhoneNormalizer.normalize(n).let { if (it.isNotEmpty()) targets.add(it) } } }

        // Newest first: the first hit per target number is its latest answered call.
        val calls = HashMap<String, Pair<Long, String>>()
        if (targets.isNotEmpty()) {
            val cur = ctx.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE),
                "${CallLog.Calls.TYPE} IN (1,2) AND ${CallLog.Calls.DURATION} >= $MIN_CALL_SECONDS",
                null,
                "${CallLog.Calls.DATE} DESC"
            ) ?: return notOk("provider_unavailable")
            cur.use { c ->
                while (c.moveToNext()) {
                    val n = PhoneNormalizer.normalize(c.getString(0))
                    if (n !in targets || calls.containsKey(n)) continue
                    calls[n] = Pair(c.getLong(2), if (c.getInt(1) == 1) "incoming" else "outgoing")
                    if (calls.size == targets.size) break
                }
            }
        }

        val result = JSONObject()
        for (k in keys) {
            val nums = phones[k] ?: continue
            var best = 0L
            var dir = ""
            var bestNum = ""
            for (n in nums) {
                val hit = calls[PhoneNormalizer.normalize(n)] ?: continue
                if (hit.first > best) { best = hit.first; dir = hit.second; bestNum = n }
            }
            if (best > 0) result.put(k, JSONObject().put("at", best).put("dir", dir).put("phone", bestNum))
        }

        val overdue = computeOverdue(cfg, result, System.currentTimeMillis())
        Store.saveOverdue(ctx, overdue)
        ReconnectWidgetProvider.refresh(ctx)
        return JSONObject().put("ok", true).put("calls", result).toString()
    }

    private fun computeOverdue(cfg: JSONObject, last: JSONObject, now: Long): JSONArray {
        val thresholds = HashMap<Long, Int>()
        val lists = cfg.optJSONArray("lists") ?: JSONArray()
        for (i in 0 until lists.length()) {
            val l = lists.getJSONObject(i)
            thresholds[l.getLong("id")] = l.getInt("days")
        }
        val best = HashMap<String, Triple<String, Int, String>>()
        val members = cfg.optJSONArray("members") ?: JSONArray()
        for (i in 0 until members.length()) {
            val m = members.getJSONObject(i)
            if (!m.optBoolean("enabled", true) || m.optLong("snoozedUntil", 0) > now) continue
            val threshold = thresholds[m.getLong("listId")] ?: continue
            val key = m.getString("key")
            val call = last.optJSONObject(key)
            val at = call?.optLong("at", 0) ?: 0L
            if (at <= 0) continue
            val d = ((now - at) / DAY).toInt()
            val cur = best[key]
            if (d >= threshold && (cur == null || d > cur.second)) {
                best[key] = Triple(m.getString("name"), d, call?.optString("dir", "") ?: "")
            }
        }
        val out = JSONArray()
        best.values.sortedByDescending { it.second }
            .forEach { out.put(JSONObject().put("name", it.first).put("days", it.second).put("dir", it.third)) }
        return out
    }
}
