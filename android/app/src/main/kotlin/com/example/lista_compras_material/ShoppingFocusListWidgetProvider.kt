package com.example.lista_compras_material

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ShoppingFocusListWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.widget_shopping_focus_list).apply {
        val openIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("minhascompras://open?source=widget_focus"),
        )
        setOnClickPendingIntent(R.id.widget_focus_root, openIntent)
        setOnClickPendingIntent(R.id.widget_focus_open_button, openIntent)

        val title = widgetData.getString("widget_focus_title", "Nenhuma lista criada")
            ?: "Nenhuma lista criada"
        val details = widgetData.getString("widget_focus_details", "Crie uma lista para aparecer aqui.")
            ?: "Crie uma lista para aparecer aqui."
        val total = widgetData.getString("widget_focus_total", "Total: R$ 0,00")
            ?: "Total: R$ 0,00"
        val budget = widgetData.getString("widget_focus_budget", "Orcamento: nao definido")
            ?: "Orcamento: nao definido"

        setTextViewText(R.id.widget_focus_title, title)
        setTextViewText(R.id.widget_focus_details, details)
        setTextViewText(R.id.widget_focus_total, total)
        setTextViewText(R.id.widget_focus_budget, budget)
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
