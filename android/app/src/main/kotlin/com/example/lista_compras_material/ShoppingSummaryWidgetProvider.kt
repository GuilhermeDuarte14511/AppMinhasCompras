package com.example.lista_compras_material

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ShoppingSummaryWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.widget_shopping_summary).apply {
        val openIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("minhascompras://open?source=widget_summary"),
        )
        setOnClickPendingIntent(R.id.widget_summary_root, openIntent)
        setOnClickPendingIntent(R.id.widget_summary_open_button, openIntent)

        val totalLists = widgetData.getInt("widget_total_lists", 0)
        val pendingItems = widgetData.getInt("widget_pending_items", 0)
        val totalValue = widgetData.getString("widget_total_value", "R$ 0,00") ?: "R$ 0,00"
        val updatedAt = widgetData.getString("widget_updated_at", "--") ?: "--"

        setTextViewText(R.id.widget_summary_lists_value, totalLists.toString())
        setTextViewText(R.id.widget_summary_pending_value, pendingItems.toString())
        setTextViewText(R.id.widget_summary_total_value, totalValue)
        setTextViewText(R.id.widget_summary_updated_value, "Atualizado: $updatedAt")
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
