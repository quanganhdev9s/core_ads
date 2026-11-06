import Flutter
import core_ads
import google_mobile_ads
import UIKit

extension CoreAdsNativeFactory: FLTNativeAdFactory {}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    for id in CoreAdsNativeFactories.ids {
      FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        engineBridge.pluginRegistry,
        factoryId: id,
        nativeAdFactory: CoreAdsNativeFactory(template: id)
      )
    }
  }
}
