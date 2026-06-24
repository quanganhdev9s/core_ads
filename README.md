# core_ads

A reusable Flutter ads package that keeps app code independent from ad network
SDKs.

Apps import only:

```dart
import 'package:core_ads/core_ads.dart';
```

## API Summary

```dart
AppAds.initialize(config);
AppAds.load(placement);
AppAds.banner(placement);
AppAds.nativeAd(placement);
AppAds.showInterstitial(placement);
AppAds.showRewarded(placement: placement, onRewardEarned: () {});
AppAds.showRewardedInterstitial(placement: placement, onRewardEarned: () {});
AppAds.showAppOpen(placement);
AppAds.handleAppResume(placement);
AppAds.clear(placement);
AppAds.clearType(type);
AppAds.dispose();
```

## Placements

`AdType` describes the format. `AdPlacement` describes where that format is used
in your app. Define placements in the host app:

```dart
class AppAdPlacements {
  static const homeTopBanner = AdPlacement(
    key: 'home_top_banner',
    type: AdType.banner,
  );

  static const levelCompleteInterstitial = AdPlacement(
    key: 'level_complete_interstitial',
    type: AdType.interstitial,
  );

  static const doubleReward = AdPlacement(
    key: 'double_reward',
    type: AdType.rewarded,
  );

  static const levelBonusRewardedInterstitial = AdPlacement(
    key: 'level_bonus_rewarded_interstitial',
    type: AdType.rewardedInterstitial,
  );

  static const appOpen = AdPlacement(
    key: 'app_open',
    type: AdType.appOpen,
  );

  static const articleNative = AdPlacement(
    key: 'article_native',
    type: AdType.native,
  );
}
```

Use multiple placements for the same format only when the app needs separate ad
unit IDs, cache, or analytics.

## Initialize

```dart
await AppAds.initialize(
  AdsConfig(
    environment: AdsEnvironment.production,
    adUnitIds: AdUnitIds({
      AppAdPlacements.homeTopBanner: 'ca-app-pub-xxx/banner',
      AppAdPlacements.levelCompleteInterstitial: 'ca-app-pub-xxx/interstitial',
      AppAdPlacements.doubleReward: 'ca-app-pub-xxx/rewarded',
      AppAdPlacements.levelBonusRewardedInterstitial:
          'ca-app-pub-xxx/rewarded_interstitial',
      AppAdPlacements.appOpen: 'ca-app-pub-xxx/app_open',
      AppAdPlacements.articleNative: 'ca-app-pub-xxx/native',
    }),
    bannerAdConfigs: BannerAdConfigs({
      AppAdPlacements.homeTopBanner: BannerAdConfig.banner(),
    }),
    nativeAdConfigs: NativeAdConfigs({
      AppAdPlacements.articleNative: NativeAdConfig(
        factoryId: 'article_native_factory',
        height: 140,
      ),
    }),
    fullscreenCooldown: FullscreenAdCooldownConfig(
      interstitialInterval: Duration(seconds: 7),
      appOpenInterval: Duration(seconds: 7),
      interstitialAppOpenInterval: Duration(seconds: 7),
    ),
    consent: AdsConsentConfig(
      enabled: true,
      tagForUnderAgeOfConsent: false,
      requestTrackingAuthorizationOnIos: true,
    ),
    request: AdsRequestConfig(
      maxAdContentRating: AdsMaxAdContentRating.t,
      tagForChildDirectedTreatment: false,
      tagForUnderAgeOfConsent: false,
    ),
    enableDebugLogs: true,
  ),
);
```

## Consent And ATT

Google UMP runs during initialization when consent is enabled. Ads are only
requested when `canRequestAds` allows it.

For consent testing:

```dart
AdsConsentConfig(
  debugGeography: AdsConsentDebugGeography.eea,
  testDeviceIds: ['TEST_DEVICE_ID'],
  resetOnInitialize: true,
);
```

`resetOnInitialize` should only be used while testing consent flows.

On iOS, ATT is requested after UMP consent allows ads. The host app must add
`NSUserTrackingUsageDescription` to `ios/Runner/Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
```

If another native permission dialog appears during first launch, adjust:

```dart
AdsConsentConfig(
  trackingAuthorizationDelay: Duration(milliseconds: 500),
);
```

## Banner

```dart
const AdsBanner(
  placement: AppAdPlacements.homeTopBanner,
  config: BannerAdConfig.banner(),
);
```

Supported sizes are `banner`, `largeBanner`, `mediumRectangle`, `fullBanner`,
`leaderboard`, and `anchoredAdaptive`.

```dart
const AdsBanner(
  placement: AppAdPlacements.homeTopBanner,
  config: BannerAdConfig.anchoredAdaptive(),
);
```

With custom placeholders:

```dart
AdsBanner(
  placement: AppAdPlacements.homeTopBanner,
  config: const BannerAdConfig.largeBanner(),
  loading: const AdsLoadingWidget(),
  error: const SizedBox.shrink(),
);
```

With manual retry:

```dart
AdsBanner(
  placement: AppAdPlacements.homeTopBanner,
  errorBuilder: (context, retry) {
    return TextButton(
      onPressed: retry,
      child: const Text('Retry ad'),
    );
  },
);
```

With local callbacks:

```dart
AdsBanner(
  placement: AppAdPlacements.homeTopBanner,
  onLoaded: () {},
  onFailed: (failure) {},
);
```

When `AppAds.clear(placement)` or `AppAds.clearType(AdType.banner)` is called,
visible `AdsBanner` widgets for the cleared placement/type reload automatically.

By default, `AdsBanner` clears its cached ad when the widget is disposed. Set
`clearOnDispose: false` if the app wants to keep the placement cached across
screen changes.

## Native

The host app must register the native ad factory matching the placement
`factoryId` on Android and iOS.

```dart
const AdsNative(
  placement: AppAdPlacements.articleNative,
  loading: AdsLoadingWidget(height: 140),
);
```

## Fullscreen Ads

Preload placements before showing:

```dart
await AppAds.load(AppAdPlacements.levelCompleteInterstitial);
await AppAds.load(AppAdPlacements.doubleReward);
await AppAds.load(AppAdPlacements.levelBonusRewardedInterstitial);
```

Show fullscreen placements:

```dart
await AppAds.showInterstitial(
  AppAdPlacements.levelCompleteInterstitial,
);

await AppAds.showRewarded(
  placement: AppAdPlacements.doubleReward,
  onRewardEarned: () {
    // Grant reward here.
  },
);

await AppAds.showRewardedInterstitial(
  placement: AppAdPlacements.levelBonusRewardedInterstitial,
  onRewardEarned: () {
    // Grant bonus reward here.
  },
);
```

Fullscreen ads share a global lock, so interstitial, rewarded, rewarded
interstitial, and app open ads cannot show on top of each other.

## App Open

```dart
await AppAds.load(AppAdPlacements.appOpen);
await AppAds.showAppOpen(AppAdPlacements.appOpen);
```

Lifecycle helper:

```dart
final adsLifecycleObserver = AdsAppLifecycleObserver(
  appOpenPlacement: AppAdPlacements.appOpen,
);

adsLifecycleObserver.attach();
adsLifecycleObserver.detach();
```

Manual resume handling:

```dart
await AppAds.handleAppResume(AppAdPlacements.appOpen);
```

## Callbacks

```dart
AdsConfig(
  environment: AdsEnvironment.production,
  adUnitIds: AdUnitIds({}),
  callbacks: AdsCallbacks(
    onLoaded: (event) {},
    onFailed: (event) {},
    onShown: (event) {},
    onDismissed: (event) {},
    onClicked: (event) {},
    onImpression: (event) {},
    onPaid: (event) {},
    onRewardEarned: (event) {},
  ),
);
```

Use `onPaid` for ad revenue analytics. Grant rewards inside the `showRewarded`
or `showRewardedInterstitial` `onRewardEarned` callback.

## Clear And Dispose

Clear one placement:

```dart
await AppAds.clear(AppAdPlacements.levelCompleteInterstitial);
```

Clear all cached ads for a type:

```dart
await AppAds.clearType(AdType.interstitial);
```

Dispose all resources:

```dart
await AppAds.dispose();
```

## Design Notes

- Public app code should not import Google Mobile Ads directly.
- The package uses `AdPlacement` instead of raw strings for app-defined slots.
- Managers own ad lifecycle per placement.
- Reward callbacks are only emitted from SDK reward callbacks.
