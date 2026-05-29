package com.metacasa.metacasa

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget que muestra el balance del mes + ingresos/gastos del hogar
 * activo. Port 1:1 del `BalanceWidget` de iOS (`MetaCasaWidgets/BalanceWidget.swift`),
 * familia "medium": label DISPONIBLE, balance grande, fila Ingresos/Gastos.
 *
 * Los datos los escribe la app Flutter via `home_widget` (ver
 * `lib/features/widget/widget_snapshot_service.dart`), que persiste en el
 * `SharedPreferences` "HomeWidgetPreferences" que `HomeWidgetProvider` nos pasa
 * ya formateados como strings (mismo contrato que el App Group de iOS).
 *
 * Claves leídas: balanceMonth, ingresosMonth, gastosMonth, householdName,
 * currency, nextBillTitle, nextBillAmount, nextBillInDays.
 */
class BalanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.balance_widget).apply {
                // Balance del mes (string ya formateado por la app). Fallback al
                // placeholder cuando todavía no hubo un sync (widget recién puesto).
                val balance = widgetData.getString("balanceMonth", null)
                setTextViewText(
                    R.id.widget_balance,
                    balance ?: context.getString(R.string.widget_balance_placeholder),
                )

                // Nombre del hogar (subtítulo). Vacío → cae al nombre de la app.
                val household = widgetData.getString("householdName", null)
                setTextViewText(
                    R.id.widget_household,
                    household ?: context.getString(R.string.widget_default_household),
                )

                // Ingresos / gastos del período (con prefijo +/− para lectura rápida).
                val ingresos = widgetData.getString("ingresosMonth", null)
                val gastos = widgetData.getString("gastosMonth", null)
                setTextViewText(
                    R.id.widget_ingresos,
                    if (ingresos != null) "↓ $ingresos" else "↓ —",
                )
                setTextViewText(
                    R.id.widget_gastos,
                    if (gastos != null) "↑ $gastos" else "↑ —",
                )

                // Tap en cualquier parte → abre la app (MainActivity).
                setOnClickPendingIntent(R.id.widget_root, buildLaunchIntent(context))
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    /**
     * PendingIntent que abre la app al tocar el widget. Usa un launch intent a
     * `MainActivity` (singleTop, ya declarado en el manifest); `home_widget`
     * también soporta deep-links pero un simple open-app alcanza para este widget.
     */
    private fun buildLaunchIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
