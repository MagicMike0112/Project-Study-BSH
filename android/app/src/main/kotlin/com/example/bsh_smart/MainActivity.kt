package com.example.bsh_smart

import android.content.Context
import android.content.Intent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "widget_channel"
    private var channel: MethodChannel? = null
    private val widgetPrefs = "widget_prefs"
    private val keyInventoryJson = "inventory_json"
    private val keyPendingRecipeJson = "pending_recipe_json"
    private val keyLastRecipeId = "last_recipe_id"
    private val keyPendingOpenRecipeId = "pending_open_recipe_id"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences(widgetPrefs, Context.MODE_PRIVATE)
            when (call.method) {
                "updateInventorySnapshot" -> {
                    val json = call.arguments as? String
                    if (json != null) {
                        prefs.edit().putString(keyInventoryJson, json).apply()
                    }
                    result.success(null)
                }
                "getPendingRecipe" -> {
                    result.success(prefs.getString(keyPendingRecipeJson, null))
                }
                "clearPendingRecipe" -> {
                    prefs.edit().remove(keyPendingRecipeJson).apply()
                    result.success(null)
                }
                "getLastRecipeId" -> {
                    result.success(prefs.getString(keyLastRecipeId, null))
                }
                "setPendingOpenRecipeId" -> {
                    val id = call.arguments as? String
                    if (id != null) {
                        prefs.edit().putString(keyPendingOpenRecipeId, id).apply()
                    }
                    result.success(null)
                }
                "getPendingOpenRecipeId" -> {
                    result.success(prefs.getString(keyPendingOpenRecipeId, null))
                }
                "clearPendingOpenRecipeId" -> {
                    prefs.edit().remove(keyPendingOpenRecipeId).apply()
                    result.success(null)
                }
                "refreshRecipeWidget" -> {
                    WorkManager.getInstance(this)
                        .enqueue(OneTimeWorkRequestBuilder<RecipeWidgetWorker>().build())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getInitialRoute(): String? {
        val route = intent?.getStringExtra("route")
        val recipeId = intent?.getStringExtra("recipe_id")
        if (!recipeId.isNullOrBlank()) {
            val prefs = getSharedPreferences(widgetPrefs, Context.MODE_PRIVATE)
            prefs.edit().putString(keyPendingOpenRecipeId, recipeId).apply()
        }
        return route ?: super.getInitialRoute()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = intent.getStringExtra("route")
        val recipeId = intent.getStringExtra("recipe_id")
        if (route != null) {
            if (!recipeId.isNullOrBlank()) {
                val prefs = getSharedPreferences(widgetPrefs, Context.MODE_PRIVATE)
                prefs.edit().putString(keyPendingOpenRecipeId, recipeId).apply()
            }
            channel?.invokeMethod("openRoute", route)
        }
    }
}
