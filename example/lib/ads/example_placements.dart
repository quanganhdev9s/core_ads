import 'package:core_ads/core_ads.dart';

class ExamplePlacements {
  const ExamplePlacements._();

  static const banner = AdPlacement(key: 'example_banner', type: AdType.banner);

  static const native = AdPlacement(
    key: 'example_native',
    type: AdType.native,
    nativeFactoryId: 'example_native_factory',
  );

  static const collapsibleNative = AdPlacement(
    key: 'example_collapsible_native',
    type: AdType.native,
    nativeFactoryId: 'example_native_factory',
  );

  static const collapsedBanner = AdPlacement(
    key: 'example_collapsed_banner',
    type: AdType.banner,
  );

  static const interstitial = AdPlacement(
    key: 'example_interstitial',
    type: AdType.interstitial,
    preloadAfterShow: false,
  );

  static const splashInterstitial = AdPlacement(
    key: 'example_splash_interstitial',
    type: AdType.interstitial,
    preloadAfterShow: false,
  );

  static const returnHomeInterstitial = AdPlacement(
    key: 'example_return_home_interstitial',
    type: AdType.interstitial,
    preloadAfterShow: false,
  );

  static const rewarded = AdPlacement(
    key: 'example_rewarded',
    type: AdType.rewarded,
  );

  static const rewardedInterstitial = AdPlacement(
    key: 'example_rewarded_interstitial',
    type: AdType.rewardedInterstitial,
  );

  static const appOpen = AdPlacement(
    key: 'example_app_open',
    type: AdType.appOpen,
  );

  static const values = [
    banner,
    native,
    collapsibleNative,
    collapsedBanner,
    interstitial,
    splashInterstitial,
    returnHomeInterstitial,
    rewarded,
    rewardedInterstitial,
    appOpen,
  ];
}
