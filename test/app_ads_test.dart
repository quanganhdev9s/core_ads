import 'package:core_ads/core_ads.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AppAds.dispose();
  });

  tearDown(() async {
    await AppAds.dispose();
  });

  test('initialize failure does not publish failed repository', () async {
    final failingRepository = _FakeAdsRepository(
      initializeResult: const AdResult.failure(
        AdFailure(code: 'init_failed', message: 'Init failed'),
      ),
    );

    final initializeResult = await AppAds.initialize(
      _config(),
      repository: failingRepository,
    );
    final loadResult = await AppAds.load(_placement);

    expect(initializeResult.isFailure, isTrue);
    expect(failingRepository.disposeCount, 1);
    expect(failingRepository.loadCount, 0);
    expect(loadResult, isA<AdFailed<void>>());
    expect((loadResult as AdFailed<void>).failure.code, 'not_ready');
  });

  test(
    'successful reinitialize swaps repository and disposes old one',
    () async {
      final firstRepository = _FakeAdsRepository();
      final failingRepository = _FakeAdsRepository(
        initializeResult: const AdResult.failure(
          AdFailure(code: 'init_failed', message: 'Init failed'),
        ),
      );
      final secondRepository = _FakeAdsRepository();

      await AppAds.initialize(_config(), repository: firstRepository);
      await AppAds.initialize(_config(), repository: failingRepository);
      final loadResult = await AppAds.load(_placement);

      expect(loadResult.isSuccess, isTrue);
      expect(firstRepository.loadCount, 1);
      expect(firstRepository.disposeCount, 0);
      expect(failingRepository.disposeCount, 1);

      await AppAds.initialize(_config(), repository: secondRepository);

      expect(firstRepository.disposeCount, 1);
      expect(secondRepository.disposeCount, 0);
    },
  );
}

const _placement = AdPlacement(
  key: 'test_interstitial',
  type: AdType.interstitial,
);

AdsConfig _config() {
  return AdsConfig(
    environment: AdsEnvironment.test,
    adUnitIds: AdUnitIds({_placement: 'test-ad-unit-id'}),
  );
}

class _FakeAdsRepository implements AdsRepository {
  _FakeAdsRepository({this.initializeResult = const AdResult.success(null)});

  final AdResult<void> initializeResult;

  int initializeCount = 0;
  int loadCount = 0;
  int disposeCount = 0;

  @override
  Future<AdResult<void>> initialize() async {
    initializeCount += 1;
    return initializeResult;
  }

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async {
    loadCount += 1;
    return const AdResult.success(null);
  }

  @override
  AdLoadStatus getStatus(AdPlacement placement) => AdLoadStatus.idle;

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
  Future<void> clear(AdPlacement placement) async {}

  @override
  Future<void> clearType(AdType type) async {}

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}
