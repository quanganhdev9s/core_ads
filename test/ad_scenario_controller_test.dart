import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String script(int enable) =>
      '''
{
  "settings": {},
  "banner_home": {
    "enable": $enable,
    "banner": {"name1": "BANNER_HOME"},
    "banner_collap": {"name1": "BANNER_HOME"},
    "native": {"name1": "NATIVE_HOME"}
  }
}
''';

  AdScenarioController controller(
    String source, {
    bool Function()? shouldFail,
  }) => AdScenarioController(
    initialScript: AdScript.parse(source),
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
    final bannerCollapse = tester.widget<AdsCollapsibleNative>(
      find.byType(AdsCollapsibleNative),
    );
    expect(bannerCollapse.bannerPlacement?.key, 'banner_home.banner_collap');
    expect(bannerCollapse.collapsedNativePlacement, isNull);

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
    expect(
      nativeCollapse.collapsedNativePlacement?.key,
      'banner_home.native_small',
    );

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

  testWidgets('Small1 native_result refreshes without a collapse widget', (
    tester,
  ) async {
    const source = '''
{"settings": {}, "native_result": {
  "enable": 1, "refresh_rate": 20,
  "collap_config": "24/26", "native_template": "Small1",
  "native": {"name1": "NATIVE_RESULT"}
}}
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
{"settings": {},
 "native_result": {"enable": 1, "native": {"name1": "NATIVE_RESULT"}},
 "banner_home": {"enable": 1, "banner": {"name1": "BANNER_HOME"}}}
''';
      const source = '''
{"settings": {},
 "native_result": {"enable": 2, "native": {"name1": "NATIVE_RESULT"}},
 "banner_home": {"enable": 1, "banner": {"name1": "BANNER_HOME"}}}
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
                      await ads.showScenario(context, 'native_result');
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
{"settings": {}, "native_result": {
  "enable": 1, "collap_config": "24/26",
  "native_template": "Collap2Expanded",
  "native": {"name1": "NATIVE_RESULT"}
}}
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
    expect(
      collapse.collapsedNativeHeight,
      NativeAdType.collap2Collapsed.height,
    );
    expect(collapse.collapseClickCounts, {24, 26});
    expect(
      collapse.collapsedNativePlacement?.nativeFactoryId,
      NativeAdType.collap2Collapsed.factoryId,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
  });

  test(
    'failed update retains the active script and its inter call count',
    () async {
      const interScript = '''
{"settings": {}, "inter_home": {
  "enable": 1, "step_count": 2,
  "inter": {"name1": "INTER_HOME"}
}}
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
    'scenario passes remote inter gap to the existing fullscreen cooldown',
    () async {
      const source = '''
{"settings": {
  "inter_delay_time": "time=10000,ignore=ads_splash|inter_language|inter_intro"
}}
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
        const Duration(milliseconds: 3000),
      );
      expect(
        configs.single.fullscreenCooldown.interstitialAppOpenInterval,
        const Duration(milliseconds: 4000),
      );

      expect(
        (await ads.applyRemoteJson(
          '{"settings":{"inter_delay_time":"time=20,ignore=inter_home"}}',
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
      ads.dispose();
    },
  );

  testWidgets('showScenario presents native after a skipped inter call', (
    tester,
  ) async {
    const source = '''
{"settings": {}, "inter_home": {
  "enable": 3, "step_count": 2,
  "inter": {"name1": "INTER_HOME"},
  "native_inter": {"name1": "NATIVE_INTER_HOME"}
}}
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await ads.showScenario(
                  context,
                  'inter_home',
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
    expect(shownPlacementKeys, ['inter_home.inter']);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(result?.fullscreenResult?.isSuccess, isTrue);
    expect(result?.nativeAdShown, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    await CoreAds.dispose();
  });

  testWidgets('full onboarding native appears only after the selected screen', (
    tester,
  ) async {
    const source =
        '''
{"settings": {}, "${AdScenarioKeys.nativeFullOnboarding}": {
  "enable": 2, "native": {"name1": "NATIVE_FULL_ONBOARDING"}
}}
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
                await ads.showScenario(
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
}

class _ScenarioRepository implements AdsRepository {
  int interstitialShows = 0;

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
  Future<AdResult<void>> showInterstitial(AdPlacement placement) async {
    interstitialShows++;
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
