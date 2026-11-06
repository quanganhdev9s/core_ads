# core_ads

A reusable Flutter ads package that keeps app code independent from ad network
SDKs.

Apps import only:

```dart
import 'package:core_ads/core_ads.dart';
```

Detailed lifecycle notes:

- [Ads Load And Cache](ADS_LOAD_AND_CACHE.md)
- [Ads Show](ADS_SHOW.md)

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
    nativeFactoryId: 'Small1',
  );

  static const levelCompleteInterstitial = AdPlacement(
    key: 'level_complete_interstitial',
    type: AdType.interstitial,
    preloadAfterShow: true,
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
CoreAds.addConsentListener((event) {
  final canRequestAds = event.canRequestAds;
  final failure = event.failure;
  // Update consent-related UI here.
});

await CoreAds.initialize(
  AdsConfig(
    environment: AdsEnvironment.production,
    adUnitIds: AdUnitIds.typed({
      AppAdPlacements.homeBanner: AdUnitId.single('ca-app-pub-xxx/banner'),
      AppAdPlacements.articleNative: AdUnitId.single('ca-app-pub-xxx/native'),
      AppAdPlacements.levelCompleteInterstitial: AdUnitId.waterfall([
        'ca-app-pub-xxx/interstitial_high',
        'ca-app-pub-xxx/interstitial_mid',
        'ca-app-pub-xxx/interstitial_backfill',
      ]),
      AppAdPlacements.doubleReward: AdUnitId.single(
        'ca-app-pub-xxx/rewarded',
      ),
      AppAdPlacements.appOpen: AdUnitId.single('ca-app-pub-xxx/app_open'),
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
  height: 140,
  loading: AdsLoadingWidget(height: 140),
);

await CoreAds.load(AppAdPlacements.levelCompleteInterstitial);
if (CoreAds.canShow(AppAdPlacements.levelCompleteInterstitial)) {
  await CoreAds.showInterstitial(AppAdPlacements.levelCompleteInterstitial);
}
```

Always inspect returned results when the action controls app flow:

```dart
final result = await CoreAds.initialize(config);
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

## Remote Config ad script

The host app fetches and activates Firebase Remote Config, then passes the JSON
value (for example, `ad_script_100`) to the package. `core_ads` does not own a
Firebase project or fetch interval.

```dart
final ads = AdScenarioController(
  initialScript: AdScript.parse(bundledFallbackJson),
  resolveAdUnitIds: (name, type) => appAdUnitIds[name] ?? const [],
  buildAdsConfig: (ids) => AdsConfig(
    environment: AdsEnvironment.production,
    adUnitIds: ids,
  ),
);
await ads.applyRemoteJson(remoteConfigJson); // Keeps fallback on parse failure.
await ads.initialize();

// At a screen's inline ad location:
CoreAdSlot(controller: ads, placementKey: 'banner_home');

// At the app-defined moment for a full-screen scenario:
final result = await ads.showScenario(context, 'inter_home');
// Continue product navigation after the ad sequence finishes.
```

Each scenario step maps to an existing single-format `AdPlacement`. A `native_*`
placement with multiple numbered native branches uses each digit of `enable`
to select a branch: `native_intro.enable = 24` selects intro 2 and 4. A
special rule for `native_language` and `native_get_start` accepts only `0`, `1`,
or `2`; every other value disables the placement (see the note linked below). `native_intro`
accepts only screen numbers 1–4. `native_full_onboarding.enable` selects the
1-based onboarding transition that opens a full-screen native ad. A
placement with one unnumbered native branch accepts only `0` (off) or `1` (on). The package keeps
`collap_config` as slash-separated collapse-button tap numbers, and associates `refresh_rate`
with the native branch. `on_resume` can be read from `settings.on_resume` when
there is no placement object; a placement object takes precedence if present.
Other placement families do not interpret `enable` as a string of digits;
without a documented scenario rule, they accept `1` with exactly one ad branch.
`AdScriptPlacement` validates `enable` and stores the selected branches once;
`AdScenarioCoordinator` uses that list to build the ad steps.
`settings.ads_enable` is retained but does not change placements yet, because
that scenario belongs to each app.

For all `native_*` enable cases, see the
[Vietnamese implementation note](NATIVE_AD_CASES.md).

`CoreAdSlot` chooses the inline format from `enable` and rebuilds after a
successful script update. For `banner_*`: 0 hides; 1 shows banner; 2 shows a
large native that collapses to `banner_collap`; 3 shows native; 4 shows a large
native that collapses to a small native. Mode 4 uses the same `native` ID for
two separate native placements, with `Big4` and `Small1` factories by default.
The app can supply other default factory IDs to `AdScenarioController`. If
`native_template` names `Collap1Expanded`, `Collap2Expanded`, or
`Collap3Expanded`, the package pairs it with the matching `Collapsed` factory.
An ordinary native template such as `Small1` stays a normal native even when
its JSON contains `collap_config`. The `native_inter` branch defaults to
`Full1` when its template is omitted.

The slot takes its default native height from the selected factory. Pass
`nativeHeight` or `collapsedNativeHeight` only when the screen needs an
override. Native loading uses a template-shaped shimmer: compact icon and CTA
for Tiny, icon and text for Small, media and CTA for Big, a full-height media
area for Full, and separate expanded/compact shapes for Collap.

`showScenario` loads and shows a selected interstitial or app-open ad, then
opens the package's full-screen native route when selected. It opens that native
route even when the preceding full-screen ad is skipped or unavailable. The
app chooses when to call it and where to navigate after it returns. `refresh_rate`
in `inter_home` applies to `NATIVE_INTER_HOME`, not `INTER_HOME`.

`step_count` gates calls to the scenario's interstitial step separately for
each interstitial placement. With `step_count: 2`, calls 1 and 3 return
`AdFailed` with code `step_count_skipped`; calls 2 and 4 attempt to show the
ad and return its actual result. `preload` does not increment the count.
The controller preserves counts across successful script updates. The native
step remains available in the plan even when an inter
call is skipped. Calls to the lower-level `CoreAds.showInterstitial` API do not
use this script counter.

The close button appears `wait_time` milliseconds after the first native ad is
rendered. The widget reloads the native ad `refresh_rate` milliseconds after each
render while the route is current and the app is resumed. A failed first load
shows the close button immediately. The app decides when to push the route and
where to navigate after it closes.

`CoreAdSlot` also applies `refresh_rate` to an inline native ad while its route
is current and the app is resumed. The interval starts after each successful
render. For a collapsible ad, it applies to the expanded native view.

Remote Config time values use milliseconds throughout. For example,
`"refresh_rate": 2000` means 2 seconds and `"wait_time": 5000` means 5 seconds.
The app-owned `language_delay_millis` and `introN_setup` `delay` values use the
same unit. `settings.inter_delay_time` is parsed as
`time=<milliseconds>,ignore=<scenario-key>|<scenario-key>`. When present,
`AdScenarioController` passes `time` to the existing fullscreen interstitial
cooldown. Ignored interstitials bypass that inter-to-inter gap and do not reset
its timer; they still obey the separate interstitial-to-app-open cooldown.
For example, `ignore=ads_splash|inter_language` matches the script's logical
keys, not ad unit names. If the setting is absent, the app's `AdsConfig`
fullscreen cooldown remains in effect. The gap is checked when showing an ad,
and a successful show starts the timer after the interstitial closes.

Google [recommends ads persist for at least 60 seconds](https://support.google.com/admob/answer/2936217?hl=en)
and warns that faster refresh can reduce fill. Review a Remote Config value such
as `refresh_rate: 2000` before using it with live ad units.

The host app fetches Remote Config and supplies the mapping from symbolic names
like `INTER_HOME` to platform-specific ad unit IDs. `applyRemoteJson` parses a
new script and, after initialization, reinitializes `CoreAds` with its new ID
map before notifying slots. Call it at a safe point when no ad is on screen;
if the whole JSON cannot be parsed, the previous script and ID map remain
active. The app should
dispose the controller and `CoreAds` at its chosen lifetime boundary.

An enabled `ads_splash`, `inter_*`, `banner_*`, or `native_*` placement must
contain every branch selected by its `enable` value. If one placement has an
invalid `enable`, timing value, or selected branch, the package prints a prominent
`[CORE_ADS][REMOTE_CONFIG_ERROR]` message and disables only that placement.
Other ads in the same JSON remain available. A malformed known setting is
ignored with a log. Missing placement keys resolve to a disabled plan, so ad
widgets and scenario calls do not interrupt product navigation. The lower
level `AdScriptStore` is still available for manual integration.
`settings.ads_enable` is retained but does not currently change placements.

## Public API

```dart
CoreAds.initialize(config);
CoreAds.addConsentListener((event) {});
CoreAds.removeConsentListener(listener);
CoreAds.load(placement);
CoreAds.canShow(placement);
CoreAds.updateFullscreenCooldown(cooldown);
CoreAds.banner(placement);
CoreAds.nativeAd(placement);
CoreAds.showInterstitial(placement);
CoreAds.showRewarded(placement: placement, onRewardEarned: () {});
CoreAds.showRewardedInterstitial(placement: placement, onRewardEarned: () {});
CoreAds.showAppOpen(placement);
CoreAds.handleAppResume(placement);
CoreAds.clear(placement);
CoreAds.clearType(type);
CoreAds.dispose();
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

`AdUnitIds({...})` still accepts the simple `Map<AdPlacement, String>` form.
Use `AdUnitIds.typed({...})` when a placement needs `AdUnitId.waterfall([...])`.
Waterfall IDs are loaded in order. The package tries the next ID only when the
previous ID fails to load, and reports load failure only after every ID fails.

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

Native ads require a platform factory. The `nativeFactoryId` in `AdPlacement`
must match the factory registered on Android and iOS.
The package supplies the Tiny, Small, Big, Full, and Collap factory families,
plus `Card1`, on Android and iOS. Apps may still register their own factory IDs.
`AdsNative` and `AdsCollapsibleNative` show the matching `NativeAdShimmer` while
loading unless the app supplies a custom loading widget.

1. Configure native in Dart:

```dart
class AppAdPlacements {
  static const articleNative = AdPlacement(
    key: 'article_native',
    type: AdType.native,
    nativeFactoryId: 'Small1',
  );
}

AdsConfig(
  adUnitIds: AdUnitIds({
    AppAdPlacements.articleNative: 'ca-app-pub-xxx/native',
  }),
);
```

2. Register the factory on Android:

```kotlin
CoreAdsNativeFactories.register(flutterEngine, this)
```

Android factory IDs follow the [WaveZ native ad design](https://www.figma.com/design/bMsTcAN9Uk50hlbcdW3LIA/Untitled?node-id=183-78):

| Layout | Factory IDs | Flutter default height |
| --- | --- | --- |
| Tiny | `Tiny1`, `Tiny2` | 80dp, 74dp |
| Small | `Small1`–`Small5` | 136dp, 138dp, 136dp, 130dp, 136dp |
| Big | `Big1`–`Big6`; `Big7`–`Big8`; `Big9` | 36%; 33%; 30% of screen height |
| Full | `Full1`–`Full5` | Fill the host height |
| Collapsible | `Collap1Expanded`/`Collapsed`; `Collap2Expanded`/`Collapsed`; `Collap3Expanded`/`Collapsed` | 36%/Tiny1; 40%/Tiny2; 33%/Tiny1 |
| Card | `Card1` | 240dp |

The public `NativeAdType` enum keeps each factory ID and its Flutter height
rule in one place. For example, `NativeAdType.big4.factoryId` is `Big4`, and
`NativeAdType.big4.resolveHeight(screenHeight)` returns 36% on Android and
39% on iOS. `CoreAdSlot` and `NativeAdTemplate.heightForScreen` select the
current platform automatically.
`CoreAdSlot` uses `MediaQuery.sizeOf(context).height` for this calculation.
Full-screen types return `null`; their host provides the available height.

`Small5` remains registered as an alias of `Small3` for existing placements. For collapsible and full-screen layouts, the Flutter widget owns the close or next navigation action. The Android factory renders the ad content; apps should supply an appropriately sized host for each layout.

3. Register the factory on iOS:

```swift
extension CoreAdsNativeFactory: FLTNativeAdFactory {}
for id in CoreAdsNativeFactories.ids {
  FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
    registry,
    factoryId: id,
    nativeAdFactory: CoreAdsNativeFactory(template: id)
  )
}
```

iOS provides the same factory IDs, including `Card1`. At the Figma reference
widths, the iPhone/iPad heights are:

| Layout | Flutter height on iOS | Figma iPhone reference (390pt wide) | Figma iPad reference (834pt wide) |
| --- | --- | --- | --- |
| Small1–4 | Fixed height from the factory metadata | 138, 146, 146, 130pt | 138, 166, 166, 130pt |
| Big1–2, Collap1Expanded | 42% of screen height | 356pt | 356pt |
| Big3–4 | 39% of screen height | 328pt | 328pt |
| Big5 | 36% of screen height | 300pt | 300pt |
| Collap2Expanded | 40% of screen height | — | — |
| Full1–3 | Host height | 844pt | 1194pt |
| Card1 | 27% of screen height | 230pt at 280pt width | 230pt at 360pt width |

`Card2` also has the 27% iOS height rule in Flutter metadata. Its native
factory is not registered yet.
On iOS, the legacy `Big6`–`Big9` and `Collap3Expanded` IDs inherit the height
of the layouts they map to (`Big2`–`Big5` and `Collap2Expanded`).
`Small5` inherits `Small3` height: 146pt on iPhone and 166pt on iPad.
Pass `screenWidth` to `heightForScreen` when calculating an iPad height outside
`CoreAdSlot`; the slot supplies it from `MediaQuery` automatically.

The iOS registry also accepts the Android-only IDs so a shared placement can
resolve on both platforms. `Small5` maps to `Small3`; `Big6`–`Big9` map to
`Big2`–`Big5`; `Full4`/`Full5` map to `Full2`/`Full3`; and the third collapsible
pair maps to the second iOS collapsible style. Flutter owns the close, collapse,
and next navigation controls.

4. Render native ad:

```dart
const AdsNative(
  placement: AppAdPlacements.articleNative,
  height: 140,
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

Set `clearOnDispose: true` when the widget should clear its cached ad when it
is disposed.

Like banners, multiple native widgets that can exist at the same time should use
multiple placements. Those placements can still share one native ad unit ID.

### Collapsible Native

`CoreAdSlot` selects the collapse destination from the script. With `enable=2`,
the large native collapses to the `banner_collap` banner. With `enable=4`, it
collapses to another native placement using the same ad unit name and the
`Small1` factory by default. The app can control re-expansion:

```dart
CoreAdSlot(
  controller: ads,
  placementKey: 'banner_home',
  expanded: isNativeExpanded,
  onCollapsed: () {
    setState(() {
      isNativeExpanded = false;
    });
  },
);
```

`collap_config` accepts a slash-separated string of positive, one-based tap
numbers. For example, `"24/26"` selects taps 24 and 26, not taps 2, 4, and 6.
On a selected tap, the close button ignores the pointer and the native ad
underneath receives it; other taps
collapse to the configured smaller ad. The counter lives for this widget
state's lifetime, including re-expansion, and resets when the widget is disposed or
the native placement changes. A tap on a close control reaching an ad can
create [accidental-click risk](https://support.google.com/admob/answer/3342054?hl=en);
review the UI and account policy before release.

A normal native placement such as `native_result` with `native_template: "Small1"`
does not acquire a collapse button merely because its JSON contains
`collap_config`. That field is ignored for non-collapsible placements.

If the app wants to expand the native ad again after navigation, listen for the
route pop in the parent widget and set `isNativeExpanded = true`.

## Fullscreen Ads

Preload before showing:

```dart
await CoreAds.load(AppAdPlacements.levelCompleteInterstitial);
await CoreAds.load(AppAdPlacements.doubleReward);
```

Show fullscreen ads:

```dart
await CoreAds.showInterstitial(
  AppAdPlacements.levelCompleteInterstitial,
);

await CoreAds.showRewarded(
  placement: AppAdPlacements.doubleReward,
  onRewardEarned: () {
    // Grant reward here.
  },
);

await CoreAds.showRewardedInterstitial(
  placement: AppAdPlacements.levelBonusRewardedInterstitial,
  onRewardEarned: () {
    // Grant bonus reward here.
  },
);
```

Fullscreen ads share a global lock, so interstitial, rewarded, rewarded
interstitial, and app open ads cannot show on top of each other.

By default, each fullscreen placement preloads again in the background after a
successful show. The show future returns the show result and does not wait for
that next preload. Disable this on the placement when the app wants to decide
the next preload moment manually:

```dart
static const levelCompleteInterstitial = AdPlacement(
  key: 'level_complete_interstitial',
  type: AdType.interstitial,
  preloadAfterShow: false,
);
```

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

Update after initialization when the app needs to change the fullscreen gap at
runtime:

```dart
CoreAds.updateFullscreenCooldown(
  const FullscreenAdCooldownConfig(
    interstitialInterval: Duration(seconds: 3),
    appOpenInterval: Duration(seconds: 10),
    interstitialAppOpenInterval: Duration(seconds: 10),
  ),
);
```

## App Open

Manual flow:

```dart
await CoreAds.load(AppAdPlacements.appOpen);
await CoreAds.showAppOpen(AppAdPlacements.appOpen);
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
await CoreAds.handleAppResume(AppAdPlacements.appOpen);
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

Use `onPaid` for ad revenue analytics such as Adjust. `AdsPaidEvent` includes
`revenue` (converted from micros), `valueMicros`, `currencyCode`, `precision`,
`adUnitId`, `placement`, `type`, `network`, and available mediation metadata:
`responseId`, `mediationAdapterClassName`, `adSourceName`, `adSourceId`,
`adSourceInstanceName`, `adSourceInstanceId`. Grant rewards inside the
`showRewarded` or `showRewardedInterstitial` `onRewardEarned` callback.

Banner ads can refresh automatically by the SDK, so banner `onLoaded` can be
called again even when the app does not call `load` again.

## Failure Codes

Every operation returns `AdResult<void>`. Important failure codes:

- `not_ready`: no ad is ready to show, or ads were not initialized yet.
- `missing_ad_unit_id`: no ad unit ID is configured for the placement.
- `invalid_banner_size`: adaptive banner size could not be resolved.
- `missing_native_factory_id`: native placement has no `nativeFactoryId`.
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
await CoreAds.clear(AppAdPlacements.levelCompleteInterstitial);
```

Clear all cached ads for a type:

```dart
await CoreAds.clearType(AdType.interstitial);
```

Dispose all resources:

```dart
await CoreAds.dispose();
```

When `CoreAds.clear(placement)` or `CoreAds.clearType(type)` is called, visible
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
- Register every native ad factory used by `AdPlacement.nativeFactoryId` on both
  Android and iOS.
- Keep `enableDebugLogs` off unless you intentionally want package logs.
