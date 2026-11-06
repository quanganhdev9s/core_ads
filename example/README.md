# core_ads example

The example follows an app-style flow:

1. `lib/pages/scripted_ads_flow_page.dart` creates and disposes one
   `DemoAdsController` for the app session.
2. `lib/ads/scripted_demo_ads.dart` loads the JSON fixture and maps symbolic
   names to test ad unit IDs. Replace this loader and mapping for production.
   `lib/ads/demo_ad_keys.dart` declares the logical placement keys used by
   the screens.
3. `lib/ads/demo_ads_controller.dart` initializes `CoreAds`, applies updated
   JSON, runs fullscreen and reward scenarios, and records ad events.
4. Each screen in `lib/pages/scripted/` is an independent Navigator route.
   Its file declares the placements rendered on that screen and decides when
   to call `ads.showScenario` or navigate. `demo_screen_widgets.dart` contains
   only reusable page chrome, inline ad, and action widgets.

The example launches with `Ad Script version 100 A.json`. Use the JSON button
in the app bar to switch between the three exported spreadsheet configs. The
refresh button reloads the selected file and resets the local test counters.
Overview also has **Apply next JSON live**, which calls `applyRemoteJson` and
keeps each interstitial's logical call count while reinitializing the ad IDs.
All names in the JSON resolve to Google's platform-specific test ad unit IDs;
no Firebase project is required.

| Config | Splash | Home banner | Resume mode |
| --- | --- | --- | --- |
| 100 A | Inter then full-screen native | Large native to small native | 2 |
| Test B | App open | Large native to banner | 1 |
| Test C | Inter | Native | 0 |

Choose a route from Overview. It lists all 27 placement plans and opens the
matching test route when tapped. Splash, Language, Intro, Home, and Get Start
form a navigation flow. Theme, Icon, Collection, Result,
Wallpaper, Settings, and Back expose the remaining placements. Native catalog
loads one selected native step at a time and can show Full templates in a
full-screen route. Tap the event footer for load, show, and reward results.
In this test flow, each native ad shows its concrete placement key and native
layout name over the ad. Before an interstitial show attempt, a short toast
shows the interstitial placement key.

The screen flow covers `CoreAdSlot`, `showScenario`, numbered native selection,
collapse, `step_count`, native refresh, full-screen native wait time, app open,
interstitial, and rewarded ads. The package does not choose product navigation
or automatically run an ad on app resume; Home shows the resolved resume mode
and provides manual scenario buttons. `settings.ads_enable` and product UI
settings are retained from the JSON but are not applied by the package.

All `wait_time`, `refresh_rate`, and `inter_delay_time.time` values are
milliseconds. Native collapse clicks in these configs use `2/4`; the second
and fourth collapse taps pass through to the ad, while other taps collapse it.

Run on Android or iOS from this directory with `flutter run`. Use
`flutter run --dart-define=LEGACY_ADS_DEMO=true` for the older API showcase.
In debug mode, open the Device Preview tab in Flutter DevTools to simulate
different devices and screen settings.
The package registers its native factories through the example's
`MainActivity` and `AppDelegate`.
