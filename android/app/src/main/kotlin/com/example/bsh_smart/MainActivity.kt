package com.example.bsh_smart

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "widget_channel"
    private val miSpeechChannelName = "bsh_smart/mi_speech"
    private var channel: MethodChannel? = null
    private var miSpeechChannel: MethodChannel? = null
    private var pendingSpeechResult: MethodChannel.Result? = null
    private val widgetPrefs = "widget_prefs"
    private val keyInventoryJson = "inventory_json"
    private val keyPendingRecipeJson = "pending_recipe_json"
    private val keyLastRecipeId = "last_recipe_id"
    private val keyPendingOpenRecipeId = "pending_open_recipe_id"
    private val speechRequestCode = 0x5342

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
                else -> result.notImplemented()
            }
        }

        miSpeechChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, miSpeechChannelName)
        miSpeechChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSpeechSupport" -> {
                    val manufacturer = Build.MANUFACTURER.lowercase(Locale.ROOT)
                    val available = SpeechRecognizer.isRecognitionAvailable(this)
                    result.success(
                        mapOf(
                            "available" to available,
                            "manufacturer" to manufacturer,
                        )
                    )
                }
                "recognizeOnce" -> {
                    if (pendingSpeechResult != null) {
                        result.error("busy", "Speech recognition is already running.", null)
                        return@setMethodCallHandler
                    }

                    val locale = call.argument<String>("locale") ?: "zh_CN"
                    val prompt = call.argument<String>("prompt") ?: "Speak now"

                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(
                            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                        )
                        putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                    }

                    val canResolve = intent.resolveActivity(packageManager) != null
                    if (!canResolve) {
                        result.error("not_available", "No speech recognizer activity available.", null)
                        return@setMethodCallHandler
                    }

                    pendingSpeechResult = result
                    try {
                        startActivityForResult(intent, speechRequestCode)
                    } catch (e: Exception) {
                        pendingSpeechResult = null
                        result.error("launch_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getInitialRoute(): String? {
        val route = intent?.getStringExtra("route")
        val recipeId = intent?.getStringExtra("recipe_id")
        Log.d("WidgetNav", "getInitialRoute: route=$route recipeId=$recipeId")
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
        Log.d("WidgetNav", "onNewIntent: route=$route recipeId=$recipeId")
        if (route != null) {
            if (!recipeId.isNullOrBlank()) {
                val prefs = getSharedPreferences(widgetPrefs, Context.MODE_PRIVATE)
                prefs.edit().putString(keyPendingOpenRecipeId, recipeId).apply()
            }
            channel?.invokeMethod("openRoute", route)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != speechRequestCode) return

        val result = pendingSpeechResult ?: return
        pendingSpeechResult = null
        if (resultCode == Activity.RESULT_OK) {
            val text = data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
            result.success(text)
        } else {
            result.success(null)
        }
    }
}
