package com.example.bsh_smart

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.widget.RemoteViews
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class RecipeWidgetWorker(
    private val ctx: Context,
    params: WorkerParameters
) : CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result {
        val prefs = ctx.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
        val inventoryJson = prefs.getString(KEY_INVENTORY_JSON, null)

        updateWidgetState(
            title = "Chef is thinking...",
            subtitle = "Using expiring items",
            bitmap = null,
            recipeId = null
        )

        if (inventoryJson.isNullOrBlank()) {
            updateWidgetState(
                title = "Add items to get recipes",
                subtitle = "Inventory is empty",
                bitmap = null,
                recipeId = null
            )
            return Result.success()
        }

        val parsed = parseInventorySnapshot(inventoryJson)
        val items = parsed.first
        val studentMode = parsed.second
        if (items.length() == 0) {
            updateWidgetState(
                title = "Add items to get recipes",
                subtitle = "Inventory is empty",
                bitmap = null,
                recipeId = null
            )
            return Result.success()
        }

        val expiringNames = mutableListOf<String>()
        val ingredientNames = mutableListOf<String>()
        for (i in 0 until items.length()) {
            val obj = items.optJSONObject(i) ?: continue
            val name = obj.optString("name", "").trim()
            if (name.isBlank()) continue
            ingredientNames.add(name)
            val days = obj.optInt("daysToExpiry", 999)
            if (days <= 3) {
                expiringNames.add(name)
            }
        }

        val response = if (expiringNames.isNotEmpty()) {
            fetchRecipe(expiringNames.distinct(), expiringNames.distinct(), studentMode)
                ?: fetchRecipe(ingredientNames.distinct(), expiringNames.distinct(), studentMode)
        } else {
            fetchRecipe(ingredientNames.distinct(), expiringNames.distinct(), studentMode)
        }
        if (response == null) {
            updateWidgetState(
                title = "Couldn't generate recipe",
                subtitle = "Try again later",
                bitmap = null,
                recipeId = null
            )
            return Result.retry()
        }

        val first = response.optJSONArray("recipes")?.optJSONObject(0)
        if (first == null) {
            updateWidgetState(
                title = "Couldn't generate recipe",
                subtitle = "Try again later",
                bitmap = null,
                recipeId = null
            )
            return Result.retry()
        }

        val title = first.optString("title", "Recipe suggestion")
        val imageUrl = first.optString("imageUrl", "")
        val recipeIdRaw = first.optString("id", "")
        val recipeId = if (recipeIdRaw.isNotBlank()) recipeIdRaw else "widget_${System.currentTimeMillis()}"
        val bitmap = if (imageUrl.isNotBlank()) downloadBitmap(imageUrl) else null

        val archived = JSONObject().apply {
            put("archiveId", "widget_${System.currentTimeMillis()}")
            put("recipeId", recipeId)
            put("addedAtMs", System.currentTimeMillis())
            put("title", title)
            put("timeLabel", first.optString("timePill", "20 min"))
            put("expiringCount", first.optInt("expiringCount", 0))
            put("ingredients", first.optJSONArray("ingredients") ?: JSONArray())
            put("steps", first.optJSONArray("steps") ?: JSONArray())
            val tools = first.optJSONArray("tools") ?: JSONArray()
            put("appliances", tools)
            val ovenPlan = first.optJSONObject("ovenPlan")
            if (ovenPlan != null && ovenPlan.has("tempC")) {
                put("ovenTempC", ovenPlan.optInt("tempC"))
            }
            if (first.has("description")) {
                put("description", first.optString("description"))
            }
            if (imageUrl.isNotBlank()) {
                put("imageUrl", imageUrl)
            }
        }

        prefs.edit()
            .putString(KEY_PENDING_RECIPE_JSON, archived.toString())
            .putString(KEY_LAST_RECIPE_ID, recipeId)
            .apply()

        updateWidgetState(
            title = title,
            subtitle = "Tap to open recipe",
            bitmap = bitmap,
            recipeId = recipeId
        )

        return Result.success()
    }

    private fun fetchRecipe(
        ingredients: List<String>,
        expiring: List<String>,
        studentMode: Boolean
    ): JSONObject? {
        val url = URL(WIDGET_RECIPE_ENDPOINT)
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15000
            readTimeout = 20000
            setRequestProperty("Content-Type", "application/json")
            doOutput = true
        }

        val payload = JSONObject()
        payload.put("ingredients", JSONArray(ingredients.distinct()))
        payload.put("extraIngredients", JSONArray())
        payload.put("studentMode", studentMode)
        payload.put("servings", 2)
        payload.put("includeImages", true)
        if (expiring.isNotEmpty()) {
            payload.put(
                "specialRequest",
                "Prioritize these expiring items: ${expiring.distinct().joinToString(", ")}"
            )
        }

        return try {
            OutputStreamWriter(conn.outputStream).use { it.write(payload.toString()) }
            if (conn.responseCode != 200) return null
            val input = BufferedInputStream(conn.inputStream)
            val text = input.readBytes().toString(Charsets.UTF_8)
            JSONObject(text)
        } catch (_: Exception) {
            null
        } finally {
            conn.disconnect()
        }
    }

    private fun parseInventorySnapshot(raw: String): Pair<JSONArray, Boolean> {
        return try {
            val token = JSONTokener(raw).nextValue()
            if (token is JSONArray) {
                Pair(token, false)
            } else if (token is JSONObject) {
                val items = token.optJSONArray("items") ?: JSONArray()
                Pair(items, token.optBoolean("studentMode", false))
            } else {
                Pair(JSONArray(), false)
            }
        } catch (_: Exception) {
            Pair(JSONArray(), false)
        }
    }

    private fun downloadBitmap(url: String): Bitmap? {
        return try {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 12000
            conn.readTimeout = 15000
            conn.doInput = true
            conn.connect()
            val stream = conn.inputStream
            BitmapFactory.decodeStream(stream)
        } catch (_: Exception) {
            null
        }
    }

    private fun updateWidgetState(
        title: String,
        subtitle: String,
        bitmap: Bitmap?,
        recipeId: String?
    ) {
        val views = RemoteViews(ctx.packageName, R.layout.widget_recipe)
        views.setTextViewText(R.id.widget_recipe_title, title)
        views.setTextViewText(R.id.widget_recipe_subtitle, subtitle)
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_recipe_image, bitmap)
        } else {
            views.setImageViewResource(R.id.widget_recipe_image, R.mipmap.ic_launcher)
        }
        val pendingIntent = RecipeWidgetProvider.buildClickIntent(ctx, recipeId)
        views.setOnClickPendingIntent(R.id.widget_recipe_root, pendingIntent)

        val manager = AppWidgetManager.getInstance(ctx)
        val component = ComponentName(ctx, RecipeWidgetProvider::class.java)
        manager.updateAppWidget(component, views)
    }

    companion object {
        private const val WIDGET_PREFS = "widget_prefs"
        private const val KEY_INVENTORY_JSON = "inventory_json"
        private const val KEY_PENDING_RECIPE_JSON = "pending_recipe_json"
        private const val KEY_LAST_RECIPE_ID = "last_recipe_id"

        // TODO: update this endpoint to your widget-specific backend.
        private const val WIDGET_RECIPE_ENDPOINT = "https://project-study-bsh.vercel.app/api/recipe"
    }
}
