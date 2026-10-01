package com.wisal.app

import android.content.Context
import java.io.BufferedReader
import java.io.InputStreamReader

/** صلة الرحم motivational sentences, bundled identically as a Flutter asset and this raw resource. */
object Sentences {
    private var cache: List<String>? = null

    private fun all(ctx: Context): List<String> {
        cache?.let { return it }
        val list = ArrayList<String>()
        ctx.resources.openRawResource(R.raw.sentences).use { stream ->
            BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).forEachLine { line ->
                val t = line.trim()
                if (t.isNotEmpty()) list.add(t)
            }
        }
        cache = list
        return list
    }

    /** Same day-bucket index as the Flutter side, so the widget/home card and today's notification agree. */
    fun today(ctx: Context): String? {
        val list = all(ctx)
        if (list.isEmpty()) return null
        val epochDay = (System.currentTimeMillis() / 86_400_000L).toInt()
        return list[((epochDay % list.size) + list.size) % list.size]
    }
}
