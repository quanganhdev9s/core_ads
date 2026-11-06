import 'dart:async';

import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await CoreAds.dispose();
  });

  tearDown(() async {
    await CoreAds.dispose();
  });

  testWidgets('AdsBanner clears old placement when placement changes', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AdsBanner(
          key: ValueKey('ad'),
          placement: _bannerA,
          clearOnDispose: true,
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AdsBanner(
          key: ValueKey('ad'),
          placement: _bannerB,
          clearOnDispose: true,
        ),
      ),
    );
    await tester.pump();

    expect(repository.clearedPlacements, [_bannerA]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.clearedPlacements, [_bannerA, _bannerB]);
  });

  testWidgets('AdsNative clears old placement when placement changes', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AdsNative(
          key: ValueKey('ad'),
          placement: _nativeA,
          clearOnDispose: true,
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AdsNative(
          key: ValueKey('ad'),
          placement: _nativeB,
          clearOnDispose: true,
        ),
      ),
    );
    await tester.pump();

    expect(repository.clearedPlacements, [_nativeA]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.clearedPlacements, [_nativeA, _nativeB]);
  });

  testWidgets('inline native refresh counts from each render', (tester) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdsNative(
            placement: _nativeA,
            refreshRate: Duration(seconds: 2),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.clearedPlacements, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(repository.clearedPlacements, [_nativeA]);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(repository.clearedPlacements, [_nativeA, _nativeA]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(repository.clearedPlacements, [_nativeA, _nativeA]);
  });

  testWidgets('native load does not start refresh while offstage', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);
    var loaded = 0;
    var visible = 0;

    Widget page(bool offstage) => MaterialApp(
      home: Scaffold(
        body: Offstage(
          offstage: offstage,
          child: AdsNative(
            placement: _nativeA,
            refreshRate: const Duration(seconds: 2),
            onLoaded: () => loaded++,
            onVisible: () => visible++,
          ),
        ),
      ),
    );

    await tester.pumpWidget(page(true));
    await tester.pump();
    expect(loaded, 1);
    expect(visible, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(repository.clearedPlacements, isEmpty);

    await tester.pumpWidget(page(false));
    await tester.pump();
    expect(visible, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(repository.clearedPlacements, [_nativeA]);
  });

  testWidgets('native refresh starts when scrolled into view', (tester) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);
    var visible = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 700),
                AdsNative(
                  placement: _nativeA,
                  refreshRate: const Duration(seconds: 2),
                  onVisible: () => visible++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(visible, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(repository.clearedPlacements, isEmpty);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(visible, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(repository.clearedPlacements, [_nativeA]);
  });

  testWidgets(
    'clearOnDispose false keeps old placement when placement changes',
    (tester) async {
      final repository = _FakeAdsRepository();
      await CoreAds.initialize(_config(), repository: repository);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AdsBanner(
            key: ValueKey('ad'),
            placement: _bannerA,
            clearOnDispose: false,
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AdsBanner(
            key: ValueKey('ad'),
            placement: _bannerB,
            clearOnDispose: false,
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(repository.clearedPlacements, isEmpty);
    },
  );

  testWidgets('configured collapse tap passes through to the native ad', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);
    var collapsed = 0;

    Widget build({bool? expanded}) => MaterialApp(
      home: Scaffold(
        body: AdsCollapsibleNative(
          nativePlacement: _nativeA,
          bannerPlacement: _bannerA,
          nativeHeight: 120,
          expanded: expanded,
          collapseClickCounts: const {2},
          closeButton: const SizedBox.square(
            dimension: 24,
            child: Text('collapse'),
          ),
          onCollapsed: () => collapsed++,
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();
    await tester.tap(find.text('collapse'));
    await tester.pump();
    expect(collapsed, 1);

    await tester.pumpWidget(build(expanded: true));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text('collapse')));
    await tester.pump();
    expect(collapsed, 1);
    expect(repository.nativeTapCount, 1);

    await tester.tap(find.text('collapse'));
    await tester.pump();
    expect(collapsed, 2);
  });

  testWidgets('native collapse changes from large to small native placement', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdsCollapsibleNative(
            nativePlacement: _nativeA,
            collapsedNativePlacement: _nativeB,
            nativeHeight: 170,
            collapsedNativeHeight: 60,
            closeButton: SizedBox.square(
              dimension: 24,
              child: Text('collapse'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<AdsNative>(find.byType(AdsNative)).placement,
      _nativeA,
    );

    await tester.tap(find.text('collapse'));
    await tester.pump();
    expect(
      tester.widget<AdsNative>(find.byType(AdsNative)).placement,
      _nativeB,
    );
    expect(find.byType(AdsBanner), findsNothing);
  });

  testWidgets(
    'collapse control stays hidden during initial and refresh loads',
    (tester) async {
      final repository = _FakeAdsRepository();
      final initialLoad = Completer<AdResult<void>>();
      repository.nextNativeLoad = initialLoad.future;
      await CoreAds.initialize(_config(), repository: repository);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdsCollapsibleNative(
              nativePlacement: _nativeA,
              bannerPlacement: _bannerA,
              nativeHeight: 120,
            ),
          ),
        ),
      );
      expect(find.byType(NativeAdShimmer), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      initialLoad.complete(const AdResult.success(null));
      await tester.pump();
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      final refreshLoad = Completer<AdResult<void>>();
      repository.nextNativeLoad = refreshLoad.future;
      await CoreAds.clear(_nativeA);
      await tester.pump();
      expect(find.byType(NativeAdShimmer), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      refreshLoad.complete(const AdResult.success(null));
      await tester.pump();
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    },
  );

  testWidgets('language selection updates native CTA without reloading ad', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    final calls = <MethodCall>[];
    const channel = MethodChannel('core_ads/language_start_native');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    final controller = AdScenarioController(
      initialScript: AdScript.parse('''
{"settings": {}, "native_language": {"enable": 1,
 "native_language1": {"name1": "LANG_1"},
 "native_language2": {"name1": "LANG_2"}}}
'''),
      resolveAdUnitIds: (name, type) => [name],
      buildAdsConfig: (ids) =>
          AdsConfig(environment: AdsEnvironment.test, adUnitIds: ids),
      initializeAds: (config) =>
          CoreAds.initialize(config, repository: repository),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    Widget page(bool selected) => MaterialApp(
      home: Scaffold(
        body: AdsLanguageStartNative(
          controller: controller,
          placementKey: 'native_language',
          hasSelectedLanguage: selected,
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pump();
    expect(repository.nativeLoadCount, 1);
    expect(find.byType(AdsNative), findsOneWidget);

    await tester.pumpWidget(page(true));
    await tester.pump();
    expect(repository.nativeLoadCount, 1);
    expect(calls.where((call) => call.method == 'setSelected').length, 2);
    expect((calls.last.arguments as Map<Object?, Object?>)['selected'], isTrue);
  });

  testWidgets('full-screen native close and refresh timers start on display', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);
    var closed = 0;
    var visible = 0;
    const step = AdScenarioStep(
      branch: 'native_inter',
      placement: _nativeA,
      ids: ['native-a'],
      waitTime: Duration(seconds: 3),
      refreshRate: Duration(seconds: 2),
      collapseClickCounts: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdsFullScreenNative(
            step: step,
            onClose: () => closed++,
            onVisible: () => visible++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(visible, 1);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(repository.clearedPlacements, [_nativeA]);
    await tester.pump();
    expect(visible, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.close), findsOneWidget);
    final adBounds = tester.getRect(find.byType(AdsNative));
    final closeBounds = tester.getRect(find.byIcon(Icons.close));
    expect(closeBounds.top, greaterThanOrEqualTo(adBounds.top));
    expect(closeBounds.bottom, lessThanOrEqualTo(adBounds.bottom));
    await tester.tap(find.byIcon(Icons.close));
    expect(closed, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    final cleared = repository.clearedPlacements.length;
    await tester.pump(const Duration(seconds: 4));
    expect(repository.clearedPlacements.length, cleared);
  });

  testWidgets('full-screen native refresh pauses while the app is inactive', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    await CoreAds.initialize(_config(), repository: repository);
    const step = AdScenarioStep(
      branch: 'native_inter',
      placement: _nativeA,
      ids: ['native-a'],
      refreshRate: Duration(seconds: 2),
      collapseClickCounts: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdsFullScreenNative(step: step, onClose: () {}),
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(repository.clearedPlacements, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(repository.clearedPlacements, [_nativeA]);
  });
}

const _bannerA = AdPlacement(key: 'banner_a', type: AdType.banner);
const _bannerB = AdPlacement(key: 'banner_b', type: AdType.banner);
const _nativeA = AdPlacement(key: 'native_a', type: AdType.native);
const _nativeB = AdPlacement(key: 'native_b', type: AdType.native);

AdsConfig _config() {
  return AdsConfig(
    environment: AdsEnvironment.test,
    adUnitIds: AdUnitIds({
      _bannerA: 'banner-a',
      _bannerB: 'banner-b',
      _nativeA: 'native-a',
      _nativeB: 'native-b',
    }),
  );
}

class _FakeAdsRepository implements AdsRepository {
  final List<AdPlacement> clearedPlacements = [];
  int nativeLoadCount = 0;
  int nativeTapCount = 0;
  Future<AdResult<void>>? nextNativeLoad;

  @override
  Future<AdResult<void>> initialize() async {
    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async {
    if (placement.type == AdType.native) nativeLoadCount++;
    if (placement.type == AdType.native && nextNativeLoad != null) {
      final load = nextNativeLoad!;
      nextNativeLoad = null;
      return load;
    }
    return const AdResult.success(null);
  }

  @override
  AdLoadStatus getStatus(AdPlacement placement) => AdLoadStatus.ready;

  @override
  bool canAttemptShow(AdPlacement placement) => false;

  @override
  bool canShow(AdPlacement placement) => false;

  @override
  void updateFullscreenCooldown(FullscreenAdCooldownConfig cooldown) {}

  @override
  Widget banner(AdPlacement placement) => const SizedBox.shrink();

  @override
  Widget nativeAd(AdPlacement placement) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => nativeTapCount++,
    child: const SizedBox.expand(),
  );

  @override
  Future<AdResult<void>> showInterstitial(AdPlacement placement) async {
    return const AdResult.failure(AdFailure.notReady());
  }

  @override
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) async {
    return const AdResult.failure(AdFailure.notReady());
  }

  @override
  Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) async {
    return const AdResult.failure(AdFailure.notReady());
  }

  @override
  Future<AdResult<void>> showAppOpen(AdPlacement placement) async {
    return const AdResult.failure(AdFailure.notReady());
  }

  @override
  Future<AdResult<void>> handleAppResume(AdPlacement placement) async {
    return const AdResult.failure(AdFailure.notReady());
  }

  @override
  Future<void> clear(AdPlacement placement) {
    clearedPlacements.add(placement);
    return Future.value();
  }

  @override
  Future<void> clearType(AdType type) async {}

  @override
  Future<void> dispose() async {}
}
