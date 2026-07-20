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
        val listId = widgetData.getString("widget_focus_list_id", "") ?: ""
        val openIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.Builder()
                .scheme("minhascompras")
                .authority("open")
                .appendQueryParameter("action", "open_list")
                .appendQueryParameter("listId", listId)
                .appendQueryParameter("source", "widget_focus")
                .build(),
        )
        val voiceIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.Builder()
                .scheme("minhascompras")
                .authority("open")
                .appendQueryParameter("action", "voice")
                .appendQueryParameter("listId", listId)
                .appendQueryParameter("source", "widget_focus")
                .build(),
        )
        val pantryIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("minhascompras://open?action=pantry&source=widget_focus"),
        )
        setOnClickPendingIntent(R.id.widget_focus_root, openIntent)
        setOnClickPendingIntent(R.id.widget_focus_open_button, openIntent)
        setOnClickPendingIntent(R.id.widget_focus_voice_button, voiceIntent)
        setOnClickPendingIntent(R.id.widget_focus_pantry_preview, pantryIntent)

        val title = widgetData.getString("widget_focus_title", "Nenhuma lista criada")
            ?: "Nenhuma lista criada"
        val details = widgetData.getString("widget_focus_details", "Crie uma lista para aparecer aqui.")
            ?: "Crie uma lista para aparecer aqui."
        val pendingPreview = widgetData.getString(
            "widget_focus_pending_preview",
            "Toque no microfone para começar uma lista.",
        ) ?: "Toque no microfone para começar uma lista."
        val total = widgetData.getString("widget_focus_total", "Total: R$ 0,00")
            ?: "Total: R$ 0,00"
        val budget = widgetData.getString("widget_focus_budget", "Orcamento: nao definido")
            ?: "Orcamento: nao definido"
        val pantryPreview = widgetData.getString("widget_pantry_preview", "Despensa: tudo em ordem")
            ?: "Despensa: tudo em ordem"

        setTextViewText(R.id.widget_focus_title, title)
        setTextViewText(R.id.widget_focus_details, details)
        setTextViewText(R.id.widget_focus_pending_preview, pendingPreview)
        setTextViewText(R.id.widget_focus_total, total)
        setTextViewText(R.id.widget_focus_budget, budget)
        setTextViewText(R.id.widget_focus_pantry_preview, pantryPreview)
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
