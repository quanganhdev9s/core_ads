# core_ads

A reusable Flutter ads package that keeps app code independent from ad network
SDKs.

The package exposes a small public API through `FlutterAds` and hides concrete
SDK details behind managers and services.

## AdPlacement

`AdType` describes the ad format, such as banner, interstitial, rewarded, native,
or app open.

`AdPlacement` describes where or why that ad is used in your app. The package
does not define placements for you, because placement names belong to each app.

Define placements inside your application:

```dart
import 'package:core_ads/core_ads.dart';

class AppAdPlacements {
  static const homeTopBanner = AdPlacement(
    key: 'home_top_banner',
    type: AdType.banner,
  );

  static const resultBottomBanner = AdPlacement(
    key: 'result_bottom_banner',
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

Use one `AdType.banner` for all banner ads, and create multiple placements when
the app needs multiple banner positions.

## Initialize

Pass ad unit IDs as a map from app-defined placement to ad unit ID:

```dart
await FlutterAds.initialize(
  AdsConfig(
    environment: AdsEnvironment.production,
    adUnitIds: AdUnitIds({
      AppAdPlacements.homeTopBanner: 'ca-app-pub-xxx/home_top_banner',
      AppAdPlacements.resultBottomBanner: 'ca-app-pub-xxx/result_bottom_banner',
      AppAdPlacements.levelCompleteInterstitial: 'ca-app-pub-xxx/interstitial',
      AppAdPlacements.doubleReward: 'ca-app-pub-xxx/rewarded',
      AppAdPlacements.levelBonusRewardedInterstitial:
          'ca-app-pub-xxx/rewarded_interstitial',
      AppAdPlacements.articleNative: 'ca-app-pub-xxx/native',
    }),
    nativeAdConfigs: NativeAdConfigs({
      AppAdPlacements.articleNative: NativeAdConfig(
        factoryId: 'article_native_factory',
        height: 140,
      ),
    }),
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
    callbacks: AdsCallbacks(
      onLoaded: (event) {
        // Log loaded event.
      },
      onFailed: (event) {
        // Log event.failure.
      },
      onImpression: (event) {
        // Log impression.
      },
      onPaid: (event) {
        // Log ad revenue using event.valueMicros and event.currencyCode.
      },
      onRewardEarned: (event) {
        // Log reward analytics. Grant rewards in show callbacks.
      },
    ),
    enableDebugLogs: true,
  ),
);
```

For consent testing, configure debug geography and test device IDs from the app:

```dart
AdsConfig(
  environment: AdsEnvironment.test,
  adUnitIds: AdUnitIds({
    AppAdPlacements.homeTopBanner: 'ca-app-pub-xxx/test_banner',
  }),
  consent: AdsConsentConfig(
    debugGeography: AdsConsentDebugGeography.eea,
    testDeviceIds: ['TEST_DEVICE_ID'],
    resetOnInitialize: true,
  ),
  request: AdsRequestConfig(
    testDeviceIds: ['TEST_DEVICE_ID'],
  ),
);
```

`resetOnInitialize` should only be used while testing consent flows.

On iOS, ATT is requested after UMP consent allows ads. The host app must add
`NSUserTrackingUsageDescription` to `ios/Runner/Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
```

If the app shows another native permission dialog during first launch, consider
delaying ads initialization or increasing `trackingAuthorizationDelay`:

```dart
AdsConsentConfig(
  requestTrackingAuthorizationOnIos: true,
  trackingAuthorizationDelay: Duration(milliseconds: 500),
);
```

## Load And Show

Load each placement independently:

```dart
await FlutterAds.load(AppAdPlacements.homeTopBanner);
await FlutterAds.load(AppAdPlacements.resultBottomBanner);
await FlutterAds.load(AppAdPlacements.levelCompleteInterstitial);
await FlutterAds.load(AppAdPlacements.doubleReward);
await FlutterAds.load(AppAdPlacements.levelBonusRewardedInterstitial);
await FlutterAds.load(AppAdPlacements.appOpen);
await FlutterAds.load(AppAdPlacements.articleNative);
```

Render a banner placement without importing Google Mobile Ads:

```dart
const AdsBanner(
  placement: AppAdPlacements.homeTopBanner,
);
```

Customize banner loading and error placeholders:

```dart
AdsBanner(
  placement: AppAdPlacements.homeTopBanner,
  loading: const AdsLoadingWidget(),
  error: const SizedBox.shrink(),
);
```

Or build the banner through the facade:

```dart
FlutterAds.banner(AppAdPlacements.resultBottomBanner);
```

Render a native ad placement:

```dart
const AdsNative(
  placement: AppAdPlacements.articleNative,
  loading: AdsLoadingWidget(height: 140),
);
```

The host app must register the native ad factory matching `factoryId` on Android
and iOS.

Show fullscreen ads with the matching placement:

```dart
await FlutterAds.showInterstitial(
  AppAdPlacements.levelCompleteInterstitial,
);

await FlutterAds.showRewarded(
  placement: AppAdPlacements.doubleReward,
  onRewardEarned: () {
    // Grant the reward here.
  },
);

await FlutterAds.showRewardedInterstitial(
  placement: AppAdPlacements.levelBonusRewardedInterstitial,
  onRewardEarned: () {
    // Grant the bonus reward here.
  },
);
```

Handle app open ads when the app resumes:

```dart
final adsLifecycleObserver = AdsAppLifecycleObserver(
  appOpenPlacement: AppAdPlacements.appOpen,
);

adsLifecycleObserver.attach();

// Later, when the app no longer needs ads lifecycle handling:
adsLifecycleObserver.detach();
```

You can also call the resume handler manually:

```dart
await FlutterAds.handleAppResume(AppAdPlacements.appOpen);
```

Dispose resources when the app no longer needs ads:

```dart
await FlutterAds.dispose();
```

## Design Notes

- App code should depend on `core_ads`, not Google Mobile Ads directly.
- The package uses `AdPlacement` instead of raw strings for safer app-defined ad
  slots.
- Managers own ad lifecycle per placement.
- Reward callbacks should only grant rewards from the SDK reward callback.
