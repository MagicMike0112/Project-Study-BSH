package com.example.bsh_smart

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class RecipeWidgetProvider : AppWidgetProvider() {
    override fun onEnabled(context: Context) {
        schedulePeriodicWork(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_recipe)
            views.setTextViewText(R.id.widget_recipe_title, "Chef is thinking...")
            views.setTextViewText(R.id.widget_recipe_subtitle, "Using expiring items")
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        enqueueOneTimeWork(context)
        schedulePeriodicWork(context)
    }

    private fun enqueueOneTimeWork(context: Context) {
        WorkManager.getInstance(context)
            .enqueue(OneTimeWorkRequestBuilder<RecipeWidgetWorker>().build())
    }

    private fun schedulePeriodicWork(context: Context) {
        val request = PeriodicWorkRequestBuilder<RecipeWidgetWorker>(6, TimeUnit.HOURS)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "recipe_widget_refresh",
            ExistingPeriodicWorkPolicy.UPDATE,
            request
        )
    }

    companion object {
        fun buildClickIntent(context: Context, recipeId: String?): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "/widget-recipe")
                putExtra("recipe_id", recipeId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getActivity(context, 1, intent, flags)
        }
    }
}
