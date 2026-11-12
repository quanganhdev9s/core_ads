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
value (for example, `ad_config`) to the package. `core_ads` does not own a
Firebase project or fetch interval.

```dart
final ads = AdScenarioController(
  initialScript: AdScript.parse(
    bundledFallbackJson,
    scenario: appSelectedScenario, // full, basic, or off
  ),
  resolveAdUnitIds: (name, type) => appAdUnitIds[name] ?? const [],
  buildAdsConfig: (ids) => AdsConfig(
    environment: AdsEnvironment.production,
    adUnitIds: ids,
  ),
);
await ads.applyRemoteJson(
  remoteConfigJson,
  scenario: appSelectedScenario,
); // Keeps fallback on parse failure.
await ads.initialize();

// At a screen's inline ad location:
CoreAdSlot(controller: ads, placementKey: 'banner_home');

// Optional preload; disabled keys return an empty result map.
await ads.preloadNative('native_language');
await ads.preloadScenario('inter_home');

// At the app-defined moment for a full-screen scenario:
final result = await ads.showFullscreenAds(
  context,
  'inter_home',
  loading: const Center(child: CircularProgressIndicator()),
  preloadNextAd: true, // Default: load the following native while inter shows.
);
// Continue product navigation after the ad sequence finishes.
```

The app-provided `loading` widget fills a temporary route while an interstitial
or app-open ad is loading and starting to show. It also replaces the loading
placeholder inside a full-screen native ad. The temporary route closes when
the SDK reports that the fullscreen ad is shown, or when loading/showing fails.
An already ready ad shows without it.
Set `preloadNextAd: false` to wait until the preceding fullscreen ad closes
before loading the following native ad.
Call `preloadScenario(key)` to load every enabled step of a key, or
`preloadNative(key)` to load only its enabled native steps. Both return a map of
placement to load result and leave the interstitial `step` counter unchanged.

Config v2 is the supported Remote Config schema. The JSON must contain
`ad_placements`, grouped under `full` and `basic`. The app interprets
`ad_settings.ads_profile` and passes `AdScriptScenario.full`, `.basic`, or `.off`
to the parser. The package does not inspect user attribution, test-device, or
premium state. Placement key prefixes identify the ad group; `format` chooses
its display mode. A placement
present in the selected group is enabled unless `enable` is `false`. Native page
selection lives in the separate `pages` value (or the JSON's top-level
`pages` object). `open_ad_on_clicks` is a list of collapse-button tap counts.
A v1 JSON without `ad_placements` is rejected with `FormatException`.

```json
{
  "ad_settings": {"ads_profile": 2, "full_inter_gap_ms": 10000},
  "ad_placements": {
    "full": {"banner_home": {"format": "native_collapsible", "enable": true, "template": "Collap1"}},
    "basic": {"banner_home": {"format": "banner", "enable": true}}
  },
  "pages": {"native_onboarding": [1]},
  "ad_templates": {}
}
```

The key groups are `ads_*` (splash), `inter_*`, `banner_*`, `native_*`,
`reward_*`, `reward_inter_*`, and `on_resume`. `reward_inter_*` is checked
before `reward_*`. Splash supports `aoa`, `inter`, and
`inter_then_native_full`; inter supports `inter`, `native_full`, and
`inter_then_native_full`; banner supports `banner`, `banner_collapsible`,
`native`, and `native_collapsible`; `on_resume` supports `aoa` and
`welcome_back`. Native and reward placements do not use `format`.
For `on_resume.format = "welcome_back"`, configure an enabled
`inter_welcome_back` placement with `format = "inter_then_native_full"`.
Calling `showFullscreenAds(context, 'on_resume')` uses the same interstitial
and full-screen native placements, IDs, `step`, `wait_ms`, and `template` as
`inter_welcome_back`. Its native ad unit is `native_inter_welcome_back`.
If that placement is missing, disabled, or uses another format, `on_resume`
is disabled. With `format = "aoa"`, it uses the `on_resume` app-open ad unit.
Omitted formats default to `inter`, `banner`, or `aoa` for the corresponding
key group. Invalid formats disable only that placement. `AdConfigType` is
inferred internally from the key; `AdConfigFormat` and `AdConfigTemplate`
represent the format and template values. Template `Collap1` resolves to
factory `Collap1Expanded`, which is paired with `Collap1Collapsed` for the
same loaded ad. The parser checks `ad_templates` by each placement's `template`
name before falling back to a built-in template. A new name resolves to its
`base` factory; an entry named like a built-in template updates that factory's
style without changing its layout. Built-in entries may omit `base` or name
themselves as `base`.
The valid color, size, corner, stroke, and padding fields override only those
properties in the Android/iOS native view; omitted or malformed fields keep
the base layout's values. Numeric fields outside their supported range are
clamped. An invalid child-template field keeps the valid value inherited from
its base. For example, `native_setting.template = "setting_card_amber"` uses the
`Big2` layout and its configured `cta_bg` color. `card_stroke_dp` alone changes
an existing border; `card_stroke` adds a border with width 1 when the base has
none. `media_height_dp` does not apply to Full layouts. Custom styles are
passed with the placement and reapplied when a collapsible native ad changes
layout. `body_color` applies to the description text; the current layouts do
not render a separate advertiser-name view. A custom `card_bg` on a Full layout also colors
the Flutter background around the native view and the system bars.

For all `native_*` enable cases, see the
[Vietnamese implementation note](NATIVE_AD_CASES.md).

`CoreAdSlot` chooses the inline widget from the key group and `format`. A banner
uses `AdsBanner`; `banner_collapsible` requests an AdMob collapsible banner;
`native` uses `AdsNative`; `native_collapsible` and `Collap*` templates use
`AdsCollapsibleNative`. A collapsible native keeps the loaded ad when its
collapsed layout uses the same placement. The slot rebuilds after a successful
script update. Fullscreen plans belong in `showFullscreenAds`.

`CoreAdSlot` wraps an enabled inline ad in `SafeArea` with `top: false` and
`bottom: true` by default. Set `safeAreaTop` or `safeAreaBottom` on the slot to
override either inset.

The slot takes its default native height from the selected factory. Pass
`nativeHeight` or `collapsedNativeHeight` only when the screen needs an
override. Native loading uses a template-shaped shimmer: compact icon and CTA
for Tiny, icon and text for Small, media and CTA for Big, a full-height media
area for Full, and separate expanded/compact shapes for Collap.

`showFullscreenAds` loads and shows a selected interstitial or app-open ad, then
opens the package's full-screen native route when selected. It opens that native
route even when the preceding full-screen ad is skipped or unavailable. The
app chooses when to call it and where to navigate after it returns. `refresh_ms`
in `inter_home` applies to `NATIVE_INTER_HOME`, not `INTER_HOME`.

`step` gates calls to the scenario's interstitial step separately for
each interstitial placement. With `step: 2`, calls 1 and 3 return
`AdFailed` with code `step_count_skipped`; calls 2 and 4 attempt to show the
ad and return its actual result. `preload` does not increment the count.
The controller preserves counts across successful script updates. The native
step remains available in the plan even when an inter
call is skipped. Calls to the lower-level `CoreAds.showInterstitial` API do not
use this script counter.

The close button appears `wait_ms` milliseconds after the first native ad is
rendered. The widget reloads the native ad `refresh_ms` milliseconds after each
render while the route is current and the app is resumed. A failed first load
shows the close button immediately. The app decides when to push the route and
where to navigate after it closes.

`CoreAdSlot` also applies `refresh_ms` to an inline native ad while its route
is current and the app is resumed. The interval starts after each successful
render. For a collapsible ad, it applies to the expanded native view.

Remote Config time values use milliseconds throughout. For example,
`"refresh_ms": 2000` means 2 seconds and `"wait_ms": 5000` means 5 seconds.
`ad_settings.full_inter_gap_ms` and `basic_inter_gap_ms` set the interstitial
cooldown for each scenario. `full_inter_gap_ignore` lists logical keys exempt
from the FULL interstitial gap. `full_open_gap_ms` and `basic_open_gap_ms` set
the gap between app-open ads. `full_open_inter_gap_ms` and
`basic_open_inter_gap_ms` set the gap between interstitial and app-open ads in
either order. All values are in milliseconds. If an open-gap key is absent,
the corresponding value from the app-provided `AdsConfig.fullscreenCooldown`
is retained. A successful interstitial show starts its gap timer after it
closes.

`splash_min_ms` and `splash_max_ms` belong to the host app's Splash navigation
flow. The package preserves these keys in `AdScriptSettings.values` for the app
to read, but does not time or navigate the Splash screen. The example waits at
least `splash_min_ms` before leaving Splash. If its ad is still loading at
`splash_max_ms`, it goes to Language without showing that ad and marks it for
the `splash_fallback` flow. An ad that starts showing before the deadline is
allowed to finish before navigation.

Google [recommends ads persist for at least 60 seconds](https://support.google.com/admob/answer/2936217?hl=en)
and warns that faster refresh can reduce fill. Review a Remote Config value such
as `refresh_ms: 2000` before using it with live ad units.

The host app fetches Remote Config and supplies the mapping from symbolic names
like `INTER_HOME` to platform-specific ad unit IDs. `applyRemoteJson` parses a
new script and, after initialization, reinitializes `CoreAds` with its new ID
map before notifying slots. Call it at a safe point when no ad is on screen;
if the whole JSON cannot be parsed, the previous script and ID map remain
active. The app should
dispose the controller and `CoreAds` at its chosen lifetime boundary.

Each enabled v2 placement must have a supported key prefix and valid `format`
and native `template` when applicable. If one placement is invalid, the parser logs a
`[CORE_ADS][REMOTE_CONFIG_ERROR]` message and disables only that placement.
A malformed top-level JSON or missing `ad_placements` rejects the update; the
previous script stays active. `AdScriptStore` is available for manual integration.

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

For `banner_*` with `format: native_collapsible` and no `template`, `CoreAdSlot`
uses `Collap1Expanded` and changes to its paired `Collap1Collapsed` layout on
collapse. An explicit `template` overrides the expanded factory. The app can
control re-expansion:

When using `AdsCollapsibleNative` directly, omit both `bannerPlacement` and
`collapsedNativePlacement` to keep the same loaded native ad. The widget changes
its native layout to the matching `Collap*Collapsed` factory (or `Small1`) in
place, without another ad request. Passing a separate collapsed placement loads
that placement's ad instead.

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

`open_ad_on_clicks` accepts a list of positive, one-based tap numbers.
For example, `[2, 4]` lets the second and fourth collapse-button taps pass
through to the native ad. Other taps collapse it. The counter lives for the
widget state's lifetime and resets when the widget is disposed or the native
placement changes. A tap reaching the ad can create
[accidental-click risk](https://support.google.com/admob/answer/3342054?hl=en);
review the UI and account policy before release.

A normal native placement such as `native_result` with `template: "Small1"`
does not acquire a collapse button merely because `open_ad_on_clicks` is set.

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
