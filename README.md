# core_ads

A reusable Flutter ads package that keeps app code independent from ad network
SDKs.

Apps import only:

```dart
import 'package:core_ads/core_ads.dart';
```

## Quick Start

1. Define placements in the host app:

```dart
class AppAdPlacements {
  static const homeBanner = AdPlacement(
    key: 'home_banner',
    type: AdType.banner,
  );

  static const articleNative = AdPlacement(
    key: 'article_native',
    type: AdType.native,
  );

  static const levelCompleteInterstitial = AdPlacement(
    key: 'level_complete_interstitial',
    type: AdType.interstitial,
  );

  static const doubleReward = AdPlacement(
    key: 'double_reward',
    type: AdType.rewarded,
  );

  static const appOpen = AdPlacement(
    key: 'app_open',
    type: AdType.appOpen,
  );
}
```

`AdType` describes the ad format. `AdPlacement` describes where or why that ad
is used in the app.

2. Initialize ads:

```dart
await AppAds.initialize(
  AdsConfig(
    environment: AdsEnvironment.production,
    adUnitIds: AdUnitIds({
      AppAdPlacements.homeBanner: 'ca-app-pub-xxx/banner',
      AppAdPlacements.articleNative: 'ca-app-pub-xxx/native',
      AppAdPlacements.levelCompleteInterstitial: 'ca-app-pub-xxx/interstitial',
      AppAdPlacements.doubleReward: 'ca-app-pub-xxx/rewarded',
      AppAdPlacements.appOpen: 'ca-app-pub-xxx/app_open',
    }),
    bannerAdConfigs: BannerAdConfigs({
      AppAdPlacements.homeBanner: BannerAdConfig.anchoredAdaptive(),
    }),
    nativeAdConfigs: NativeAdConfigs({
      AppAdPlacements.articleNative: NativeAdConfig(
        factoryId: 'article_native_factory',
        height: 140,
      ),
    }),
    consent: AdsConsentConfig(
      enabled: true,
      requestTrackingAuthorizationOnIos: true,
    ),
    request: AdsRequestConfig(
      maxAdContentRating: AdsMaxAdContentRating.t,
    ),
    fullscreenCooldown: FullscreenAdCooldownConfig(),
    enableDebugLogs: false,
  ),
);
```

3. Render or show ads:

```dart
const AdsBanner(placement: AppAdPlacements.homeBanner);

const AdsNative(
  placement: AppAdPlacements.articleNative,
  loading: AdsLoadingWidget(height: 140),
);

await AppAds.load(AppAdPlacements.levelCompleteInterstitial);
await AppAds.showInterstitial(AppAdPlacements.levelCompleteInterstitial);
```

Always inspect returned results when the action controls app flow:

```dart
final result = await AppAds.initialize(config);
if (result case AdFailed(:final failure)) {
  debugPrint('Ads init failed: ${failure.code}');
}
```

## Platform Setup

The host app must configure a Google Mobile Ads app ID before initializing ads.

Android `android/app/src/main/AndroidManifest.xml`:

```xml
<application>
  <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-xxx~yyy" />
</application>
```

iOS `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxx~yyy</string>
```

Use Google's sample app IDs only in test apps. Production builds should use the
real app IDs from AdMob.

## Public API

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

## Banner

Use `AdsBanner` for widget-rendered banner ads:

```dart
const AdsBanner(
  placement: AppAdPlacements.homeBanner,
  config: BannerAdConfig.banner(),
);
```

Supported sizes:

- `BannerAdConfig.banner()`
- `BannerAdConfig.largeBanner()`
- `BannerAdConfig.mediumRectangle()`
- `BannerAdConfig.fullBanner()`
- `BannerAdConfig.leaderboard()`
- `BannerAdConfig.anchoredAdaptive()`

Adaptive banner width is resolved from the widget layout:

```dart
const AdsBanner(
  placement: AppAdPlacements.homeBanner,
  config: BannerAdConfig.anchoredAdaptive(),
);
```

Retry and local callbacks:

```dart
AdsBanner(
  placement: AppAdPlacements.homeBanner,
  showRetryButton: true,
  onLoaded: () {},
  onFailed: (failure) {},
  errorBuilder: (context, retry) {
    return TextButton(
      onPressed: retry,
      child: const Text('Retry ad'),
    );
  },
);
```

By default, `AdsBanner` clears its cached ad when the widget is disposed. Set
`clearOnDispose: false` only when the app intentionally wants to keep the
placement cached.

If multiple banner widgets can exist at the same time, use multiple placements.
Those placements can share the same ad unit ID:

```dart
AdUnitIds({
  AppAdPlacements.homeBanner: 'ca-app-pub-xxx/banner',
  AppAdPlacements.detailBanner: 'ca-app-pub-xxx/banner',
});
```

This avoids reusing one `BannerAd` object in multiple `AdWidget`s.

## Native

Native ads require a platform factory. The `factoryId` in Dart must match the
factory registered on Android and iOS.

1. Configure native in Dart:

```dart
AdsConfig(
  adUnitIds: AdUnitIds({
    AppAdPlacements.articleNative: 'ca-app-pub-xxx/native',
  }),
  nativeAdConfigs: NativeAdConfigs({
    AppAdPlacements.articleNative: NativeAdConfig(
      factoryId: 'article_native_factory',
      height: 140,
    ),
  }),
);
```

2. Register the factory on Android:

```kotlin
GoogleMobileAdsPlugin.registerNativeAdFactory(
    flutterEngine,
    "article_native_factory",
    ArticleNativeAdFactory(this),
)
```

3. Register the factory on iOS:

```swift
FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
  registry,
  factoryId: "article_native_factory",
  nativeAdFactory: ArticleNativeAdFactory()
)
```

4. Render native ad:

```dart
const AdsNative(
  placement: AppAdPlacements.articleNative,
  loading: AdsLoadingWidget(height: 140),
);
```

Retry and local callbacks:

```dart
AdsNative(
  placement: AppAdPlacements.articleNative,
  showRetryButton: true,
  onLoaded: () {},
  onFailed: (failure) {},
);
```

By default, `AdsNative` clears its cached ad when the widget is disposed. Set
`clearOnDispose: false` only when the app intentionally wants to keep the
placement cached.

Like banners, multiple native widgets that can exist at the same time should use
multiple placements. Those placements can still share one native ad unit ID.

### Collapsible Native

Use `AdsCollapsibleNative` when a native ad should collapse into a smaller
banner. The native and banner must use separate placements:

```dart
class AppAdPlacements {
  static const articleNative = AdPlacement(
    key: 'article_native',
    type: AdType.native,
  );

  static const articleCollapsedBanner = AdPlacement(
    key: 'article_collapsed_banner',
    type: AdType.banner,
  );
}
```

Add the route observer so the native ad can reopen when returning from another
screen:

```dart
MaterialApp(
  navigatorObservers: [AdsRouteObserver.instance],
  home: const HomePage(),
);
```

Render the collapsible ad:

```dart
const AdsCollapsibleNative(
  nativePlacement: AppAdPlacements.articleNative,
  bannerPlacement: AppAdPlacements.articleCollapsedBanner,
  nativeHeight: 140,
  bannerConfig: BannerAdConfig.banner(),
);
```

When the user taps the close button, the native ad is cleared and replaced by
the banner aligned to the bottom-right of the original native area. The native
ad expands again only when a pushed route is popped back to this screen.

## Fullscreen Ads

Preload before showing:

```dart
await AppAds.load(AppAdPlacements.levelCompleteInterstitial);
await AppAds.load(AppAdPlacements.doubleReward);
```

Show fullscreen ads:

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

Default fullscreen cooldowns are 7 seconds:

- interstitial to interstitial
- app open to app open
- interstitial to app open

Override when initializing:

```dart
FullscreenAdCooldownConfig(
  interstitialInterval: Duration(seconds: 7),
  appOpenInterval: Duration(seconds: 7),
  interstitialAppOpenInterval: Duration(seconds: 7),
);
```

## App Open

Manual flow:

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

## Consent And ATT

Google UMP runs during initialization when consent is enabled. Ads are requested
only when UMP reports that ads can be requested.

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

Use `onPaid` for ad revenue analytics. Grant rewards inside the
`showRewarded` or `showRewardedInterstitial` `onRewardEarned` callback.

Banner ads can refresh automatically by the SDK, so banner `onLoaded` can be
called again even when the app does not call `load` again.

## Failure Codes

Every operation returns `AdResult<void>`. Important failure codes:

- `not_ready`: no ad is ready to show, or ads were not initialized yet.
- `missing_ad_unit_id`: no ad unit ID is configured for the placement.
- `invalid_banner_size`: adaptive banner size could not be resolved.
- `missing_native_ad_config`: native placement has no `NativeAdConfig`.
- `missing_native_ad_factory`: platform native factory was not registered.
- `test_ad_unit_in_production`: production config contains Google sample ad
  unit IDs.
- `invalid_request`: the Google SDK rejected the ad request.
- `network_error`: network failed while loading/showing an ad.
- `no_fill`: the ad network returned no fill.
- `unknown`: an unexpected SDK or platform error occurred.

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

When `AppAds.clear(placement)` or `AppAds.clearType(type)` is called, visible
`AdsBanner` and `AdsNative` widgets for the cleared placement/type reload
automatically.

## Design Notes

- Public app code should not import Google Mobile Ads directly.
- The package uses `AdPlacement` instead of raw strings for app-defined slots.
- Managers own ad lifecycle per placement.
- Widget-rendered ads (`banner`, `native`) should not share one placement when
  multiple widgets can exist at the same time.
- Fullscreen ads (`interstitial`, `rewarded`, `rewardedInterstitial`,
  `appOpen`) are cached by placement.
- Reward callbacks are only emitted from SDK reward callbacks.

## Production Checklist

Before releasing:

- Use `AdsEnvironment.production`.
- Replace all Google sample ad unit IDs. `ca-app-pub-3940256099942544/...`
  fails initialization in production mode.
- Disable `resetOnInitialize` for consent.
- Add `NSUserTrackingUsageDescription` on iOS when ATT is enabled.
- Register every native ad factory used by `NativeAdConfig.factoryId` on both
  Android and iOS.
- Keep `enableDebugLogs` off unless you intentionally want package logs.
