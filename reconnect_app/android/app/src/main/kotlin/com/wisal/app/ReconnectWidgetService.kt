package com.wisal.app

import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

/** Backs the widget's scrollable list: one row per overdue member, read fresh on every notifyAppWidgetViewDataChanged. */
class ReconnectWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = ReconnectRemoteViewsFactory(applicationContext)
}

private class ReconnectRemoteViewsFactory(private val ctx: android.content.Context) : RemoteViewsService.RemoteViewsFactory {
    private var items: JSONArray = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items = Store.overdue(ctx)
    }

    override fun onDestroy() {}

    override fun getCount(): Int = items.length()

    override fun getViewAt(position: Int): RemoteViews {
        val o = items.getJSONObject(position)
        val v = RemoteViews(ctx.packageName, R.layout.reconnect_widget_item)
        v.setTextViewText(R.id.item_name, o.getString("name"))
        v.setTextViewText(R.id.item_days, "${o.getInt("days")}d")
        v.setTextViewText(R.id.item_direction, directionGlyph(o.optString("dir", "")))
        val fill = Intent().putExtra(EXTRA_POSITION, position)
        v.setOnClickFillInIntent(R.id.item_root, fill)
        return v
    }

    private fun directionGlyph(dir: String): String = when (dir) {
        "incoming" -> "↙" // they called you
        "outgoing" -> "↗" // you called them
        else -> ""
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    companion object {
        const val EXTRA_POSITION = "reconnect_widget_item_position"
    }
}
