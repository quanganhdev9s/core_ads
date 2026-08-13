import 'package:core_ads/core_ads.dart';
import 'package:flutter/widgets.dart';
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

  @override
  Future<AdResult<void>> initialize() async {
    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async {
    return const AdResult.success(null);
  }

  @override
  AdLoadStatus getStatus(AdPlacement placement) => AdLoadStatus.ready;

  @override
  bool canShow(AdPlacement placement) => false;

  @override
  Widget banner(AdPlacement placement) => const SizedBox.shrink();

  @override
  Widget nativeAd(AdPlacement placement) => const SizedBox.shrink();

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
