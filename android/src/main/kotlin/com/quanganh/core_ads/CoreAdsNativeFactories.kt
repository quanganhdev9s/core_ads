package com.quanganh.core_ads

import android.content.Context
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileads.NativeAdFactory

/** Registers the Android native ad layouts represented in the WaveZ design. */
object CoreAdsNativeFactories {
    @JvmField
    val ids: List<String> = NativeAdTemplate.entries.map { it.factoryId }

    @JvmStatic
    fun register(engine: FlutterEngine, context: Context) {
        val applicationContext = context.applicationContext
        for (template in NativeAdTemplate.entries) {
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                engine,
                template.factoryId,
                CoreAdsNativeFactory(applicationContext, template),
            )
        }
    }

    @JvmStatic
    fun unregister(engine: FlutterEngine) {
        for (id in ids) {
            GoogleMobileAdsPlugin.unregisterNativeAdFactory(engine, id)
        }
    }
}

private class CoreAdsNativeFactory(
    context: Context,
    private val template: NativeAdTemplate,
) : NativeAdFactory {
    private val layouts = NativeAdLayouts(context)

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView = layouts.build(
        template,
        nativeAd,
        customOptions?.get("placementKey") as? String,
    )
}
