import Flutter
import GoogleMobileAds
import google_mobile_ads
import UIKit

final class ExampleNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.clipsToBounds = true

    let container = UIStackView()
    container.axis = .vertical
    container.alignment = .fill
    container.spacing = 4
    container.layoutMargins = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
    container.isLayoutMarginsRelativeArrangement = true
    container.translatesAutoresizingMaskIntoConstraints = false

    let sponsoredLabel = UILabel()
    sponsoredLabel.text = "Sponsored"
    sponsoredLabel.font = UIFont.systemFont(ofSize: 11)
    sponsoredLabel.numberOfLines = 1
    sponsoredLabel.lineBreakMode = .byTruncatingTail
    sponsoredLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let headlineLabel = UILabel()
    headlineLabel.font = UIFont.boldSystemFont(ofSize: 16)
    headlineLabel.numberOfLines = 1
    headlineLabel.lineBreakMode = .byTruncatingTail
    headlineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let bodyLabel = UILabel()
    bodyLabel.font = UIFont.systemFont(ofSize: 13)
    bodyLabel.numberOfLines = 1
    bodyLabel.lineBreakMode = .byTruncatingTail
    bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let callToActionButton = UIButton(type: .system)
    callToActionButton.titleLabel?.numberOfLines = 1
    callToActionButton.titleLabel?.lineBreakMode = .byTruncatingTail
    callToActionButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    container.addArrangedSubview(sponsoredLabel)
    container.addArrangedSubview(headlineLabel)
    container.addArrangedSubview(bodyLabel)
    container.addArrangedSubview(callToActionButton)
    adView.addSubview(container)

    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      container.topAnchor.constraint(equalTo: adView.topAnchor),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
    ])

    adView.headlineView = headlineLabel
    adView.bodyView = bodyLabel
    adView.callToActionView = callToActionButton

    headlineLabel.text = nativeAd.headline

    bodyLabel.text = nativeAd.body
    bodyLabel.isHidden = nativeAd.body == nil

    callToActionButton.setTitle(nativeAd.callToAction, for: .normal)
    callToActionButton.isHidden = nativeAd.callToAction == nil
    callToActionButton.isUserInteractionEnabled = false

    adView.nativeAd = nativeAd
    return adView
  }
}

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
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      engineBridge.pluginRegistry,
      factoryId: "example_native_factory",
      nativeAdFactory: ExampleNativeAdFactory()
    )
  }
}
