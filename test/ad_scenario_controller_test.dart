import 'dart:async';

import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String script(int enable) =>
      '''
{
  "ad_settings": {"ads_profile": 1},
  "ad_placements": {"full": {
    "banner_home": {
      "enable": ${enable != 0},
      "format": "${switch (enable) {
        1 => 'banner',
        2 => 'banner_collapsible',
        3 => 'native',
        4 => 'native_collapsible',
        _ => 'invalid',
      }}"
    }
  }}
}
''';

  AdScenarioController controller(
    String source, {
    AdScriptScenario scenario = AdScriptScenario.full,
    bool Function()? shouldFail,
  }) => AdScenarioController(
    initialScript: AdScript.parse(source, scenario: scenario),
    resolveAdUnitIds: (name, type) => [name],
    buildAdsConfig: (ids) =>
        AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
    initializeAds: (config) async => shouldFail?.call() == true
        ? const AdResult.failure(
            AdFailure(code: 'init_failed', message: 'Test failure'),
          )
        : const AdResult.success(null),
  );

  testWidgets('one slot changes format when the active script changes', (
    tester,
  ) async {
    final ads = controller(script(1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoreAdSlot(controller: ads, placementKey: 'banner_home'),
        ),
      ),
    );
    expect(find.byType(AdsBanner), findsNothing);

    expect((await ads.initialize()).isSuccess, isTrue);
    await tester.pump();
    expect(find.byType(AdsBanner), findsOneWidget);

    expect((await ads.applyRemoteJson(script(2))).isSuccess, isTrue);
    await tester.pump();
    final bannerCollapse = tester.widget<AdsBanner>(find.byType(AdsBanner));
    expect(bannerCollapse.placement.key, 'banner_home.banner');
    expect(bannerCollapse.config.collapsible, isTrue);

    expect((await ads.applyRemoteJson(script(3))).isSuccess, isTrue);
    await tester.pump();
    expect(find.byType(AdsCollapsibleNative), findsNothing);
    expect(find.byType(AdsNative), findsOneWidget);

    expect((await ads.applyRemoteJson(script(4))).isSuccess, isTrue);
    await tester.pump();
    final nativeCollapse = tester.widget<AdsCollapsibleNative>(
      find.byType(AdsCollapsibleNative),
    );
    expect(nativeCollapse.bannerPlacement, isNull);
    expect(nativeCollapse.collapsedNativePlacement, isNull);
    expect(nativeCollapse.nativePlacement.key, 'banner_home.native_collap');
    expect(nativeCollapse.nativePlacement.nativeFactoryId, 'Collap1Expanded');
    expect(
      NativeAdTemplate.forFactory(
        nativeCollapse.nativePlacement.nativeFactoryId,
      ).collapsedFactoryId,
      'Collap1Collapsed',
    );
    expect(nativeCollapse.collapsedFactoryId, 'Small1');

    expect((await ads.applyRemoteJson(script(0))).isSuccess, isTrue);
    await tester.pump();
    expect(find.byType(AdsBanner), findsNothing);
    expect(find.byType(AdsNative), findsNothing);

    expect((await ads.applyRemoteJson(script(9))).isSuccess, isTrue);
    await tester.pump();
    expect(ads.resolve('banner_home').isEnabled, isFalse);
    expect(find.byType(AdsBanner), findsNothing);
    expect(find.byType(AdsNative), findsNothing);
    ads.dispose();
  });

  testWidgets('slot selects the native for a zero-based onboarding page', (
    tester,
  ) async {
    const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "native_onboarding": {"enable": true, "template": "Big4", "pages": [2, 4]}
}}}
''';
    final ads = controller(source);
    expect((await ads.initialize()).isSuccess, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoreAdSlot(
            controller: ads,
            placementKey: 'native_onboarding',
            onboardingPageIndex: 1,
          ),
        ),
      ),
    );
    expect(
      tester.widget<AdsNative>(find.byType(AdsNative)).placement.key,
      'native_onboarding.native_onboarding2',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoreAdSlot(
            controller: ads,
            placementKey: 'native_onboarding',
            onboardingPageIndex: 2,
          ),
        ),
      ),
    );
    expect(find.byType(AdsNative), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoreAdSlot(
            controller: ads,
            placementKey: 'native_onboarding',
            onboardingPageIndex: 3,
          ),
        ),
      ),
    );
    expect(
      tester.widget<AdsNative>(find.byType(AdsNative)).placement.key,
      'native_onboarding.native_onboarding4',
    );
    ads.dispose();
  });

  testWidgets('fullscreen plan in CoreAdSlot does not stop sibling ads', (
    tester,
  ) async {
    const source = '''
{
  "ad_settings": {"ads_profile": 1},
  "ad_placements": {"full": {
    "inter_language": {"format": "inter_then_native_full"},
    "native_home_feed": {"template": "Big1"}
  }}
}
''';
    final ads = controller(source);
    expect((await ads.initialize()).isSuccess, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CoreAdSlot(controller: ads, placementKey: 'inter_language'),
              CoreAdSlot(controller: ads, placementKey: 'native_home_feed'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AdsNative), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
  });

  testWidgets('Small1 native_result refreshes without a collapse widget', (
    tester,
  ) async {
    const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "native_result": { "enable": true,
    "refresh_ms": 20, "open_ad_on_clicks": [24,26], "template": "Small1"}
}}}
''';
    final ads = controller(source);
    expect((await ads.initialize()).isSuccess, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoreAdSlot(controller: ads, placementKey: 'native_result'),
        ),
      ),
    );
    expect(find.byType(AdsCollapsibleNative), findsNothing);
    expect(
      tester.widget<AdsNative>(find.byType(AdsNative)).refreshRate,
      const Duration(milliseconds: 20),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
  });

  testWidgets(
    'invalid native config skips its ad and keeps navigation running',
    (tester) async {
      const initialSource = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
 "native_result": { "enable": true},
 "banner_home": {"format": "banner"}
}}}
''';
      const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
 "native_result": { "template": "missing"},
 "banner_home": {"format": "banner"}
}}}
''';
      final ads = controller(initialSource);
      expect((await ads.initialize()).isSuccess, isTrue);
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CoreAdSlot(controller: ads, placementKey: 'native_result'),
                CoreAdSlot(controller: ads, placementKey: 'banner_home'),
                Builder(
                  builder: (context) => FilledButton(
                    onPressed: () async {
                      await ads.showFullscreenAds(context, 'native_result');
                      continued = true;
                    },
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(AdsNative), findsOneWidget);
      expect(find.byType(AdsBanner), findsOneWidget);
      expect((await ads.applyRemoteJson(source)).isSuccess, isTrue);
      await tester.pump();
      expect(ads.lastError, isNull);
      expect(find.byType(AdsNative), findsNothing);
      expect(find.byType(AdsBanner), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(continued, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      ads.dispose();
    },
  );

  testWidgets('Collap template selects the matching slot sizes', (
    tester,
  ) async {
    const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "native_result": { "enable": true,
    "open_ad_on_clicks": [24,26], "template": "Collap2"}
}}}
''';
    final ads = controller(source);
    expect((await ads.initialize()).isSuccess, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoreAdSlot(controller: ads, placementKey: 'native_result'),
        ),
      ),
    );
    final collapse = tester.widget<AdsCollapsibleNative>(
      find.byType(AdsCollapsibleNative),
    );
    final screenHeight = MediaQuery.sizeOf(
      tester.element(find.byType(AdsCollapsibleNative)),
    ).height;
    expect(
      collapse.nativeHeight,
      NativeAdType.collap2Expanded.resolveHeight(screenHeight),
    );
    expect(collapse.collapsedNativeHeight, isNull);
    expect(collapse.collapseClickCounts, {24, 26});
    expect(collapse.collapsedNativePlacement, isNull);
    expect(
      NativeAdTemplate.forFactory(
        collapse.nativePlacement.nativeFactoryId,
      ).collapsedFactoryId,
      NativeAdType.collap2Collapsed.factoryId,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoreAdSlot(
            controller: ads,
            placementKey: 'native_result',
            expanded: false,
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(AdsCollapsibleNative)).height,
      NativeAdType.collap2Collapsed.height,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
  });

  test(
    'failed update retains the active script and its inter call count',
    () async {
      const interScript = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "inter_home": { "format": "inter", "enable": true, "step": 2}
}}}
''';
      var failNext = false;
      final ads = controller(interScript, shouldFail: () => failNext);
      expect((await ads.initialize()).isSuccess, isTrue);
      expect(
        (await ads.coordinator.showInterstitial('inter_home') as AdFailed<void>)
            .failure
            .code,
        'step_count_skipped',
      );

      final revision = ads.revision;
      failNext = true;
      expect((await ads.applyRemoteJson(interScript)).isFailure, isTrue);
      expect(ads.revision, revision);
      expect(ads.resolve('inter_home').interstitial, isNotNull);
      failNext = false;
      expect((await ads.applyRemoteJson(interScript)).isSuccess, isTrue);
      expect(
        (await ads.coordinator.showInterstitial('inter_home') as AdFailed<void>)
            .failure
            .code,
        'not_ready',
      );
      ads.dispose();
    },
  );

  test('malformed JSON keeps the active script available', () async {
    final ads = controller(script(1));
    expect((await ads.initialize()).isSuccess, isTrue);
    final revision = ads.revision;
    expect((await ads.applyRemoteJson('{invalid')).isFailure, isTrue);
    expect(ads.revision, revision);
    expect(ads.resolve('banner_home').inlineMode, AdInlineMode.banner);
    ads.dispose();
  });

  test(
    'scenario applies remote fullscreen gaps for the selected profile',
    () async {
      const source = '''
{"ad_settings": {"ads_profile": 1,
  "full_inter_gap_ms": 10000,
  "full_inter_gap_ignore": ["ads_splash", "inter_language", "inter_intro"],
  "full_open_gap_ms": 30000,
  "full_open_inter_gap_ms": 15000
}, "ad_placements": {"full": {}}}
''';
      final configs = <AdsConfig>[];
      final ads = AdScenarioController(
        initialScript: AdScript.parse(source),
        resolveAdUnitIds: (name, type) => [name],
        buildAdsConfig: (ids) => AdsConfig(
          environment: AdsEnvironment.test,
          adUnitIds: ids,
          fullscreenCooldown: const FullscreenAdCooldownConfig(
            appOpenInterval: Duration(milliseconds: 3000),
            interstitialAppOpenInterval: Duration(milliseconds: 4000),
          ),
        ),
        initializeAds: (config) async {
          configs.add(config);
          return const AdResult.success(null);
        },
      );

      expect((await ads.initialize()).isSuccess, isTrue);
      expect(
        configs.single.fullscreenCooldown.interstitialInterval,
        const Duration(milliseconds: 10000),
      );
      expect(
        configs.single.fullscreenCooldown.ignoredInterstitialPlacementKeys,
        {'ads_splash.inter', 'inter_language.inter', 'inter_intro.inter'},
      );
      expect(
        configs.single.fullscreenCooldown.appOpenInterval,
        const Duration(milliseconds: 30000),
      );
      expect(
        configs.single.fullscreenCooldown.interstitialAppOpenInterval,
        const Duration(milliseconds: 15000),
      );

      expect(
        (await ads.applyRemoteJson(
          '{"ad_settings":{"ads_profile":1,"full_inter_gap_ms":20,"full_inter_gap_ignore":["inter_home"]},"ad_placements":{"full":{}}}',
        )).isSuccess,
        isTrue,
      );
      expect(
        configs.last.fullscreenCooldown.interstitialInterval,
        const Duration(milliseconds: 20),
      );
      expect(configs.last.fullscreenCooldown.ignoredInterstitialPlacementKeys, {
        'inter_home.inter',
      });
      expect(
        configs.last.fullscreenCooldown.appOpenInterval,
        const Duration(milliseconds: 3000),
      );
      expect(
        configs.last.fullscreenCooldown.interstitialAppOpenInterval,
        const Duration(milliseconds: 4000),
      );
      ads.dispose();
    },
  );

  test('basic profile selects its app-open gaps', () async {
    const source = '''
{"ad_settings": {"ads_profile": 2,
  "basic_inter_gap_ms": 90000,
  "basic_open_gap_ms": 90000,
  "basic_open_inter_gap_ms": 30000
}, "ad_placements": {"basic": {}}}
''';
    final configs = <AdsConfig>[];
    final ads = AdScenarioController(
      initialScript: AdScript.parse(source, scenario: AdScriptScenario.basic),
      resolveAdUnitIds: (name, type) => [name],
      buildAdsConfig: (ids) =>
          AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
      initializeAds: (config) async {
        configs.add(config);
        return const AdResult.success(null);
      },
    );

    expect((await ads.initialize()).isSuccess, isTrue);
    expect(ads.script.scenario, AdScriptScenario.basic);
    expect(
      configs.single.fullscreenCooldown.interstitialInterval,
      const Duration(milliseconds: 90000),
    );
    expect(
      configs.single.fullscreenCooldown.appOpenInterval,
      const Duration(milliseconds: 90000),
    );
    expect(
      configs.single.fullscreenCooldown.interstitialAppOpenInterval,
      const Duration(milliseconds: 30000),
    );
    ads.dispose();
  });

  test('app can switch full to basic when applying remote JSON', () async {
    const source = '''
{"ad_settings":{},"ad_placements":{
  "full":{"banner_home":{"format":"native"}},
  "basic":{"banner_home":{"format":"banner"}}
}}
''';
    final ads = controller(source);
    expect(ads.script.scenario, AdScriptScenario.full);
    expect(ads.resolve('banner_home').inlineMode, AdInlineMode.native);

    expect(
      (await ads.applyRemoteJson(
        source,
        scenario: AdScriptScenario.basic,
      )).isSuccess,
      isTrue,
    );
    expect(ads.script.scenario, AdScriptScenario.basic);
    expect(ads.resolve('banner_home').inlineMode, AdInlineMode.banner);
    ads.dispose();
  });

  test('invalid remote open gaps keep app cooldown defaults', () async {
    const source = '''
{"ad_settings": {"ads_profile": 1,
  "full_open_gap_ms": -1,
  "full_open_inter_gap_ms": "invalid"
}, "ad_placements": {"full": {}}}
''';
    AdsConfig? applied;
    final ads = AdScenarioController(
      initialScript: AdScript.parse(source),
      resolveAdUnitIds: (name, type) => [name],
      buildAdsConfig: (ids) => AdsConfig(
        environment: AdsEnvironment.test,
        adUnitIds: ids,
        fullscreenCooldown: const FullscreenAdCooldownConfig(
          appOpenInterval: Duration(seconds: 3),
          interstitialAppOpenInterval: Duration(seconds: 4),
        ),
      ),
      initializeAds: (config) async {
        applied = config;
        return const AdResult.success(null);
      },
    );

    expect((await ads.initialize()).isSuccess, isTrue);
    expect(
      applied!.fullscreenCooldown.appOpenInterval,
      const Duration(seconds: 3),
    );
    expect(
      applied!.fullscreenCooldown.interstitialAppOpenInterval,
      const Duration(seconds: 4),
    );
    ads.dispose();
  });

  testWidgets('welcome_back presents native after a skipped inter call', (
    tester,
  ) async {
    const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "on_resume": {"format": "welcome_back"},
  "inter_welcome_back": {"format": "inter_then_native_full", "enable": true, "step": 2}
}}}
''';
    final repository = _ScenarioRepository();
    final ads = AdScenarioController(
      initialScript: AdScript.parse(source),
      resolveAdUnitIds: (name, type) => [name],
      buildAdsConfig: (ids) =>
          AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
      initializeAds: (config) =>
          CoreAds.initialize(config, repository: repository),
    );
    expect((await ads.initialize()).isSuccess, isTrue);

    AdScenarioShowResult? result;
    final shownPlacementKeys = <String>[];
    var skipInterstitial = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await ads.showFullscreenAds(
                  context,
                  'on_resume',
                  skipInterstitial: skipInterstitial,
                  onBeforeInterstitialShow: (placement) async =>
                      shownPlacementKeys.add(placement.key),
                );
              },
              child: const Text('Show scenario'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show scenario'));
    await tester.pumpAndSettle();
    expect(find.byType(AdsFullScreenNative), findsOneWidget);
    expect(repository.interstitialShows, 0);
    expect(shownPlacementKeys, isEmpty);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(result?.nativeAdShown, isTrue);
    expect(
      (result!.fullscreenResult as AdFailed<void>).failure.code,
      'step_count_skipped',
    );

    result = null;
    await tester.tap(find.text('Show scenario'));
    await tester.pumpAndSettle();
    expect(repository.interstitialShows, 1);
    expect(shownPlacementKeys, ['inter_welcome_back.inter']);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(result?.fullscreenResult?.isSuccess, isTrue);
    expect(result?.nativeAdShown, isTrue);

    skipInterstitial = true;
    result = null;
    await tester.tap(find.text('Show scenario'));
    await tester.pumpAndSettle();
    expect(repository.interstitialShows, 1);
    expect(find.byType(AdsFullScreenNative), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(result?.fullscreenResult, isNull);
    expect(result?.nativeAdShown, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    await CoreAds.dispose();
  });

  testWidgets(
    'showFullscreenAds displays app loading until interstitial load ends',
    (tester) async {
      const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "inter_home": {"format": "inter", "enable": true}
}}}
''';
      final repository = _DeferredScenarioRepository();
      final ads = AdScenarioController(
        initialScript: AdScript.parse(source),
        resolveAdUnitIds: (name, type) => [name],
        buildAdsConfig: (ids) =>
            AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
        initializeAds: (config) =>
            CoreAds.initialize(config, repository: repository),
      );
      expect((await ads.initialize()).isSuccess, isTrue);

      AdScenarioShowResult? result;
      var readyCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await ads.showFullscreenAds(
                    context,
                    'inter_home',
                    loading: const Center(child: Text('App ad loading')),
                    onAdReady: () async {
                      readyCalls++;
                    },
                  );
                },
                child: const Text('Show scenario'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show scenario'));
      await tester.pump();
      expect(find.text('App ad loading'), findsOneWidget);
      expect(repository.interstitialShows, 0);

      repository.completeLoad();
      await tester.pump();
      expect(find.text('App ad loading'), findsOneWidget);
      expect(repository.interstitialShows, 1);
      expect(readyCalls, 1);
      expect(result, isNull);

      repository.markShown();
      await tester.pumpAndSettle();
      expect(find.text('App ad loading'), findsNothing);
      expect(repository.interstitialShows, 1);
      expect(result, isNull);

      repository.completeShow();
      await tester.pump();
      expect(result?.fullscreenResult?.isSuccess, isTrue);
      expect(readyCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      ads.dispose();
      await CoreAds.dispose();
    },
  );

  testWidgets('showFullscreenAds removes app loading after load failure', (
    tester,
  ) async {
    const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "inter_home": {"format": "inter", "enable": true}
}}}
''';
    final repository = _DeferredScenarioRepository();
    final ads = AdScenarioController(
      initialScript: AdScript.parse(source),
      resolveAdUnitIds: (name, type) => [name],
      buildAdsConfig: (ids) =>
          AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
      initializeAds: (config) =>
          CoreAds.initialize(config, repository: repository),
    );
    expect((await ads.initialize()).isSuccess, isTrue);

    AdScenarioShowResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await ads.showFullscreenAds(
                  context,
                  'inter_home',
                  loading: const Center(child: Text('App ad loading')),
                );
              },
              child: const Text('Show scenario'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show scenario'));
    await tester.pump();
    expect(find.text('App ad loading'), findsOneWidget);

    repository.failLoad();
    await tester.pumpAndSettle();
    expect(find.text('App ad loading'), findsNothing);
    expect(repository.interstitialShows, 0);
    expect(
      (result?.fullscreenResult as AdFailed<void>).failure.code,
      'test_load_failed',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    await CoreAds.dispose();
  });

  testWidgets('showFullscreenAds stops waiting after its ready timeout', (
    tester,
  ) async {
    const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "inter_home": {"format": "inter", "enable": true}
}}}
''';
    final repository = _DeferredScenarioRepository();
    final ads = AdScenarioController(
      initialScript: AdScript.parse(source),
      resolveAdUnitIds: (name, type) => [name],
      buildAdsConfig: (ids) =>
          AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
      initializeAds: (config) =>
          CoreAds.initialize(config, repository: repository),
    );
    expect((await ads.initialize()).isSuccess, isTrue);

    AdScenarioShowResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await ads.showFullscreenAds(
                  context,
                  'inter_home',
                  loading: const Center(child: Text('App ad loading')),
                  readyTimeout: const Duration(milliseconds: 100),
                );
              },
              child: const Text('Show scenario'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show scenario'));
    await tester.pump();
    expect(find.text('App ad loading'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('App ad loading'), findsNothing);
    expect(repository.interstitialShows, 0);
    expect(
      (result?.fullscreenResult as AdFailed<void>).failure.code,
      'not_ready',
    );

    repository.failLoad();
    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    await CoreAds.dispose();
  });

  test(
    'preloadNative and preloadScenario respect enabled config branches',
    () async {
      const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "inter_home": {"format": "inter_then_native_full", "enable": true, "step": 2},
  "native_off": {"enable": false, "template": "Big1"},
  "native_onboarding": {"enable": true, "pages": [2, 4]},
  "native_full_onboarding": {"enable": true, "template": "Full1", "pages": [2]}
}}}
''';
      final repository = _RecordingPreloadRepository();
      final ads = AdScenarioController(
        initialScript: AdScript.parse(source),
        resolveAdUnitIds: (name, type) => [name],
        buildAdsConfig: (ids) =>
            AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
        initializeAds: (config) =>
            CoreAds.initialize(config, repository: repository),
      );
      expect((await ads.initialize()).isSuccess, isTrue);

      final native = await ads.preloadNative('inter_home');
      expect(native.keys.map((placement) => placement.key), [
        'inter_home.native_inter',
      ]);
      expect(repository.loadedKeys, ['inter_home.native_inter']);

      final scenario = await ads.preloadScenario('inter_home');
      expect(scenario.keys.map((placement) => placement.key), [
        'inter_home.inter',
        'inter_home.native_inter',
      ]);
      expect(scenario.values.every((result) => result.isSuccess), isTrue);
      expect(
        (await ads.coordinator.showInterstitial('inter_home') as AdFailed<void>)
            .failure
            .code,
        'step_count_skipped',
      );

      final onboarding = await ads.preloadNative('native_onboarding');
      expect(onboarding.keys.map((placement) => placement.key), [
        'native_onboarding.native_onboarding2',
        'native_onboarding.native_onboarding4',
      ]);
      final fullOnboarding = await ads.preloadNative('native_full_onboarding');
      expect(fullOnboarding.keys.map((placement) => placement.key), [
        'native_full_onboarding.native',
      ]);
      final loadedCount = repository.loadedKeys.length;
      expect(await ads.preloadNative('native_off'), isEmpty);
      expect(await ads.preloadScenario('native_off'), isEmpty);
      expect(repository.loadedKeys.length, loadedCount);

      ads.dispose();
      await CoreAds.dispose();
    },
  );

  test(
    'preload skips profile off and full onboarding without selected pages',
    () async {
      const offSource = '''
{"ad_settings": {"ads_profile": 0}, "ad_placements": {"full": {
  "inter_home": {"format": "inter_then_native_full", "enable": true}
}}}
''';
      final off = controller(offSource, scenario: AdScriptScenario.off);
      expect(await off.preloadScenario('inter_home'), isEmpty);
      expect(await off.preloadNative('inter_home'), isEmpty);
      off.dispose();

      const emptyPagesSource = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "native_full_onboarding": {"enable": true, "template": "Full1"}
}}}
''';
      final noPages = controller(emptyPagesSource);
      expect(await noPages.preloadScenario('native_full_onboarding'), isEmpty);
      expect(await noPages.preloadNative('native_full_onboarding'), isEmpty);
      noPages.dispose();

      const basicOffSource = '''
{"ad_settings": {"ads_profile": 2}, "ad_placements": {
  "full": {"native_splash": {"enable": true, "template": "Big1"}},
  "basic": {"native_splash": {"enable": false, "template": "Big1"}}
}}
''';
      final basicOff = controller(
        basicOffSource,
        scenario: AdScriptScenario.basic,
      );
      expect(await basicOff.preloadNative('native_splash'), isEmpty);
      basicOff.dispose();
    },
  );

  for (final preload in [true, false]) {
    testWidgets(
      'native starts loading during inter show when preloadNextAd is $preload',
      (tester) async {
        const source = '''
{"ad_settings": {"ads_profile": 1}, "ad_placements": {"full": {
  "inter_home": {"format": "inter_then_native_full", "enable": true}
}}}
''';
        final repository = _NextNativePreloadRepository();
        final ads = AdScenarioController(
          initialScript: AdScript.parse(source),
          resolveAdUnitIds: (name, type) => [name],
          buildAdsConfig: (ids) =>
              AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
          initializeAds: (config) =>
              CoreAds.initialize(config, repository: repository),
        );
        expect((await ads.initialize()).isSuccess, isTrue);

        AdScenarioShowResult? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () async {
                    result = preload
                        ? await ads.showFullscreenAds(context, 'inter_home')
                        : await ads.showFullscreenAds(
                            context,
                            'inter_home',
                            preloadNextAd: false,
                          );
                  },
                  child: const Text('Show scenario'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show scenario'));
        await tester.pump();
        expect(repository.interstitialShows, 1);
        expect(repository.nativeNetworkLoads, preload ? 1 : 0);
        expect(find.byType(AdsFullScreenNative), findsNothing);

        repository.finishInterstitial();
        await tester.pumpAndSettle();
        expect(find.byType(AdsFullScreenNative), findsOneWidget);
        expect(repository.nativeNetworkLoads, 1);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(result?.nativeAdShown, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        ads.dispose();
        await CoreAds.dispose();
      },
    );
  }

  testWidgets('full onboarding native appears only after the selected screen', (
    tester,
  ) async {
    const source =
        '''
{"ad_settings": {"ads_profile": 1},
 "ad_placements": {"full": {
   "${AdScenarioKeys.nativeFullOnboarding}": {"enable": true, "template": "Full1"}
 }},
 "pages": {"${AdScenarioKeys.nativeFullOnboarding}": [2]}
}
''';
    final ads = AdScenarioController(
      initialScript: AdScript.parse(source),
      resolveAdUnitIds: (name, type) => [name],
      buildAdsConfig: (ids) =>
          AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
      initializeAds: (config) =>
          CoreAds.initialize(config, repository: _ScenarioRepository()),
    );
    expect((await ads.initialize()).isSuccess, isTrue);

    final results = <AdScenarioShowResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async => results.add(
                await ads.showFullscreenAds(
                  context,
                  AdScenarioKeys.nativeFullOnboarding,
                ),
              ),
              child: const Text('Next onboarding'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Next onboarding'));
    await tester.pumpAndSettle();
    expect(find.byType(AdsFullScreenNative), findsNothing);
    expect(results.single.nativeAdShown, isFalse);

    await tester.tap(find.text('Next onboarding'));
    await tester.pumpAndSettle();
    expect(find.byType(AdsFullScreenNative), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(results.last.nativeAdShown, isTrue);

    await tester.tap(find.text('Next onboarding'));
    await tester.pumpAndSettle();
    expect(find.byType(AdsFullScreenNative), findsNothing);
    expect(results.last.nativeAdShown, isFalse);

    ads.resetNativeFullOnboarding();
    await tester.tap(find.text('Next onboarding'));
    await tester.pumpAndSettle();
    expect(find.byType(AdsFullScreenNative), findsNothing);
    await tester.tap(find.text('Next onboarding'));
    await tester.pumpAndSettle();
    expect(find.byType(AdsFullScreenNative), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    await CoreAds.dispose();
  });
  test(
    'remote update changes a dynamic native template by placement key',
    () async {
      String config(String template, String color) =>
          '''
{
  "ad_settings": {"ads_profile": 1},
  "ad_placements": {"full": {
    "native_splash": {"enable": true, "template": "$template"}
  }},
  "ad_templates": {
    "$template": {"base": "Big2", "cta_bg": "$color"}
  }
}
''';
      final ads = controller(config('setting_blue', '#112233'));
      expect((await ads.initialize()).isSuccess, isTrue);
      expect(
        ads.resolve('native_splash').native!.placement.nativeFactoryId,
        'Big2',
      );
      expect(
        ads
            .resolve('native_splash')
            .native!
            .placement
            .nativeStyle!
            .values[NativeAdStyleKeys.ctaBackground],
        '#112233',
      );

      expect(
        (await ads.applyRemoteJson(
          config('setting_amber', '#FFC107'),
        )).isSuccess,
        isTrue,
      );
      expect(
        ads.resolve('native_splash').native!.placement.nativeFactoryId,
        'Big2',
      );
      expect(
        ads
            .resolve('native_splash')
            .native!
            .placement
            .nativeStyle!
            .values[NativeAdStyleKeys.ctaBackground],
        '#FFC107',
      );
      ads.dispose();
    },
  );
}

class _ScenarioRepository implements AdsRepository {
  int interstitialShows = 0;

  @override
  AdLoadStatus getStatus(AdPlacement placement) => AdLoadStatus.idle;

  @override
  Future<AdResult<void>> initialize() async => const AdResult.success(null);

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async => const AdResult.success(null);

  @override
  Widget nativeAd(AdPlacement placement) => const SizedBox.expand();

  @override
  Future<AdResult<void>> showInterstitial(
    AdPlacement placement, {
    void Function()? onShown,
  }) async {
    interstitialShows++;
    onShown?.call();
    return const AdResult.success(null);
  }

  @override
  bool canShow(AdPlacement placement) => true;

  @override
  Future<void> clear(AdPlacement placement) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredScenarioRepository extends _ScenarioRepository {
  final Completer<AdResult<void>> _loadCompleter = Completer<AdResult<void>>();
  final Completer<AdResult<void>> _showCompleter = Completer<AdResult<void>>();
  AdLoadStatus status = AdLoadStatus.idle;
  void Function()? onShown;

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) {
    status = AdLoadStatus.loading;
    return _loadCompleter.future;
  }

  void completeLoad() {
    status = AdLoadStatus.ready;
    _loadCompleter.complete(const AdResult.success(null));
  }

  void failLoad() {
    status = AdLoadStatus.failed;
    _loadCompleter.complete(
      const AdResult.failure(
        AdFailure(code: 'test_load_failed', message: 'Test load failure'),
      ),
    );
  }

  @override
  Future<AdResult<void>> showInterstitial(
    AdPlacement placement, {
    void Function()? onShown,
  }) {
    interstitialShows++;
    this.onShown = onShown;
    return _showCompleter.future;
  }

  void markShown() {
    onShown?.call();
  }

  void completeShow() {
    _showCompleter.complete(const AdResult.success(null));
  }

  @override
  AdLoadStatus getStatus(AdPlacement placement) => status;

  @override
  bool canShow(AdPlacement placement) => status == AdLoadStatus.ready;
}

class _NextNativePreloadRepository extends _ScenarioRepository {
  final Completer<AdResult<void>> _interstitialComplete =
      Completer<AdResult<void>>();
  bool _nativeReady = false;
  int nativeNetworkLoads = 0;

  @override
  AdLoadStatus getStatus(AdPlacement placement) =>
      placement.type == AdType.native && !_nativeReady
      ? AdLoadStatus.idle
      : AdLoadStatus.ready;

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async {
    if (placement.type == AdType.native && !_nativeReady) {
      nativeNetworkLoads++;
      _nativeReady = true;
    }
    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> showInterstitial(
    AdPlacement placement, {
    void Function()? onShown,
  }) {
    interstitialShows++;
    onShown?.call();
    return _interstitialComplete.future;
  }

  void finishInterstitial() {
    _interstitialComplete.complete(const AdResult.success(null));
  }
}

class _RecordingPreloadRepository extends _ScenarioRepository {
  final List<String> loadedKeys = [];

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async {
    loadedKeys.add(placement.key);
    return const AdResult.success(null);
  }
}
