package com.quanganh.core_ads

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Flutter plugin entry point for the package's native view implementations. */
class CoreAdsPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "core_ads/language_start_native").apply {
            setMethodCallHandler { call, result ->
                val key = call.argument<String>("placementKey")
                when (call.method) {
                    "setSelected" -> {
                        val selected = call.argument<Boolean>("selected")
                        if (key == null || selected == null) {
                            result.error("invalid_arguments", "placementKey and selected are required", null)
                        } else {
                            NativeLanguageStartState.setSelected(key, selected)
                            result.success(null)
                        }
                    }
                    "clear" -> {
                        if (key != null) NativeLanguageStartState.clear(key)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        NativeLanguageStartState.clearAll()
    }
}
