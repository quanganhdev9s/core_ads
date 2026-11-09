# core_ads example

The example follows an app-style flow:

1. `lib/pages/scripted_ads_flow_page.dart` creates and disposes one
   `DemoAdsController` for the app session.
2. `lib/ads/scripted_demo_ads.dart` loads config v2 and maps symbolic
   names to test ad unit IDs. Replace this loader and mapping for production.
   `lib/ads/demo_ad_keys.dart` declares the logical placement keys used by
   the screens.
3. `lib/ads/demo_ads_controller.dart` initializes `CoreAds`, applies updated
   JSON, runs fullscreen and reward scenarios, and records ad events.
4. Each screen in `lib/pages/scripted/` is an independent Navigator route.
   Its file declares the placements rendered on that screen and decides when
   to call `ads.showFullscreenAds` or navigate. `demo_screen_widgets.dart` contains
   only reusable page chrome, inline ad, and action widgets.

After initialization, app code can call
`controller.ads.preloadNative(DemoAdKeys.nativeLanguage)` for native only or
`controller.ads.preloadScenario(DemoAdKeys.interHome)` for every enabled step.
Both skip disabled placements. Use `showFullscreenAds` for the fullscreen flow.

The example launches with `demoAdConfigJson` in
`lib/ads/demo_ad_config.dart` (config v2). Edit that string and hot restart
the app to test a new config. The Overview screen shows the selected `full` or `basic` scenario. Toggle **Marketing user**
to test `ads_profile=2`; toggle **Test ad device** to test `ads_profile=3`
after changing that setting in the JSON. **Premium** disables every placement.
The example always resolves ad unit names to Google's test IDs, even when the
export contains production-style IDs.

Settings shows `native_setting` with the `setting_card_amber` custom template in both FULL
and BASIC. Its `base: Big2` uses the existing Big2 layout and
`cta_bg: #FFC107` changes the native CTA background on both platforms. Other
template fields remain at their Big2 values. The `Big5` entry in `ad_templates`
also overrides the built-in Big5 CTA color wherever a placement selects Big5.

Open **Config v2 cases** from Overview and turn on **Marketing user** to test
the additional FULL placements. The fullscreen actions cover splash AOA,
splash interstitial, and interstitial as fullscreen native. The inline picker
covers banner, collapsible banner, native banner, native collapse, and a
disabled placement. The Reward section tests `reward_*` and
`reward_inter_*` keys with Google's test ad units. Existing Splash, Language,
Intro, Home, and Settings routes
cover the remaining formats and page-based native placements. Only
`ads_splash`, `inter_language`, and `inter_onboarding` bypass the FULL
interstitial gap.

For production, let the app determine acquisition source, test device status,
and premium status, then parse the Remote Config JSON with that audience:

```dart
final audience = AdScriptAudience(
  isMarketingUser: isMarketingUser,
  isTestAdDevice: isGooglePlayTester || isAdMobTestDevice,
  isPremium: isPremium,
);
final script = AdScript.parse(adConfigJson, audience: audience,
    pagesJson: pagesRemoteJson);
```

`pagesJson` is a separate Remote Config value. For example:
`{"native_language":2,"native_get_start":1,"native_onboarding":[2,4],"native_full_onboarding":[2]}`.
If omitted, the sample JSON's top-level `pages` object is used. In v2,
`enable` in Remote Config is a boolean. The key prefix determines the ad group,
`format` selects the display mode, and `pages` selects native pages independently.
The parser derives `AdConfigType` internally; JSON does not contain `type`.
A placement present in either the exported `full` or `basic` object is enabled
when its `enable` field is omitted. A missing placement remains absent.

The refresh button reloads the inline config and resets local test counters.
Overview also has **Apply config v2 live**, which calls `applyRemoteJson`
without resetting interstitial call counts. This exercises the update flow
using the current string value. No Firebase project is required.

Choose a route from Overview. It lists the active placement plans and opens the
matching test route when tapped. Splash, Language, Intro, Home, and Get Start
form a navigation flow. Theme, Icon, Collection, Result,
Wallpaper, Settings, and Back expose the remaining placements. Native catalog
loads one selected native step at a time and can show Full templates in a
full-screen route. Tap the event footer for load, show, and reward results.
In this test flow, each native ad shows its concrete placement key and native
layout name over the ad. Before an interstitial show attempt, a short toast
shows the interstitial placement key.

**Native UI gallery** lists every registered native layout, regardless of
which placements are enabled by the selected JSON. Tap a layout to inspect it
on a separate screen with a Google test native ad. Full1–Full5 open through
`AdsFullScreenNative`; the other layouts keep their designed heights inside a
full-screen preview route. Card2 is omitted because its native factory is not
registered yet.

The screen flow covers `CoreAdSlot`, `showFullscreenAds`, native page selection,
collapse, `step`, native refresh, full-screen native wait time, app open,
interstitial, and rewarded ads. The package does not choose product navigation
or automatically run an ad on app resume; Home shows the resolved resume mode
and provides a manual test button. The example applies the language and
onboarding UI settings and uses `splash_fallback` when Splash showed no ad.
Splash preloads its fullscreen ad, stays visible for at least `splash_min_ms`,
and stops waiting at `splash_max_ms`. If the ad is still loading at that point,
it goes to Language and marks the ad for fallback. An ad already showing is
allowed to finish before navigation.

All `*_ms` values are milliseconds. Native collapse clicks use
`open_ad_on_clicks: [2,4]`; the second
and fourth collapse taps pass through to the ad, while other taps collapse it.

Run on Android or iOS from this directory with `flutter run`.
In debug mode, open the Device Preview tab in Flutter DevTools to simulate
different devices and screen settings.
The package registers its native factories through the example's
`MainActivity` and `AppDelegate`.
