package com.wisal.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class ReconnectWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        render(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        fun refresh(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, ReconnectWidgetProvider::class.java))
            if (ids.isNotEmpty()) render(ctx, mgr, ids)
        }

        private fun render(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
            ids.forEach { id ->
                val v = RemoteViews(ctx.packageName, R.layout.reconnect_widget)
                v.setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(
                        ctx, 0, Intent(ctx, MainActivity::class.java),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                )
                v.setEmptyView(R.id.widget_list, R.id.empty)

                // Unique data Uri per widget id so each instance gets its own RemoteViewsFactory.
                val intent = Intent(ctx, ReconnectWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    data = Uri.parse("reconnect://widget/$id")
                }
                v.setRemoteAdapter(R.id.widget_list, intent)

                // Tapping a row opens the app, same as tapping the widget elsewhere.
                v.setPendingIntentTemplate(
                    R.id.widget_list,
                    PendingIntent.getActivity(
                        ctx, 0, Intent(ctx, MainActivity::class.java),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                )
                mgr.updateAppWidget(id, v)
            }
            mgr.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
        }
    }
}
