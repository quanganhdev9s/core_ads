import Flutter
import GoogleMobileAds
import UIKit

/// IDs for the built-in iOS native ad layouts. Existing Android IDs remain usable.
public enum CoreAdsNativeFactories {
  public static let ids = NativeAdTemplate.allCases.map(\.rawValue)
}

/// Builds a configured native view for google_mobile_ads.
///
/// The host app adds FLTNativeAdFactory conformance when registering this with
/// google_mobile_ads, whose Swift package is a separate Flutter dependency.
public final class CoreAdsNativeFactory: NSObject {
  private let template: NativeAdTemplate

  public init(template: String) {
    self.template = NativeAdTemplate(rawValue: template) ?? .small1
  }

  @objc public func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let placementKey = customOptions?["placementKey"] as? String
    let style = NativeAdStyle(options: customOptions?[NativeAdStyleKeys.factoryOption])
    let layouts = NativeAdLayouts()
    let view = layouts.build(
      template, ad: nativeAd,
      placementKey: placementKey, style: style
    )
    if let placementKey {
      NativeCollapsibleState.shared.bind(
        placementKey, view: view, ad: nativeAd, template: template, layouts: layouts,
        style: style
      )
    }
    return view
  }
}
