package com.example.core_ads_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.quanganh.core_ads.CoreAdsNativeFactories

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CoreAdsNativeFactories.register(flutterEngine, this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CoreAdsNativeFactories.unregister(flutterEngine)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
