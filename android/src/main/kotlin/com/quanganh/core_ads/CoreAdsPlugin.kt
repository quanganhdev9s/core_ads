package com.quanganh.core_ads

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Flutter plugin entry point for the package's native view implementations. */
class CoreAdsPlugin : FlutterPlugin {
    private var collapsibleChannel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        collapsibleChannel = MethodChannel(binding.binaryMessenger, "core_ads/collapsible_native").apply {
            setMethodCallHandler { call, result ->
                val key = call.argument<String>("placementKey")
                if (key == null) {
                    result.error("invalid_arguments", "placementKey is required", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "setCollapsed" -> {
                        val collapsed = call.argument<Boolean>("collapsed")
                        if (collapsed == null) {
                            result.error("invalid_arguments", "collapsed is required", null)
                        } else {
                            NativeCollapsibleState.setCollapsed(
                                key, collapsed, call.argument<String>("collapsedFactoryId"),
                            )
                            result.success(null)
                        }
                    }
                    "clear" -> {
                        NativeCollapsibleState.clear(key)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        collapsibleChannel?.setMethodCallHandler(null)
        collapsibleChannel = null
        NativeCollapsibleState.clearAll()
    }
}
