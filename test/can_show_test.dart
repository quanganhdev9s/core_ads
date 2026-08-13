import 'package:core_ads/core_ads.dart';
import 'package:core_ads/src/ads/app_open/app_open_manager.dart';
import 'package:core_ads/src/ads/banner/banner_manager.dart';
import 'package:core_ads/src/ads/interstitial/interstitial_manager.dart';
import 'package:core_ads/src/ads/native/native_manager.dart';
import 'package:core_ads/src/ads/rewarded/reward_manager.dart';
import 'package:core_ads/src/consent/consent_manager.dart';
import 'package:core_ads/src/core/fullscreen/fullscreen_ad_controller.dart';
import 'package:core_ads/src/data/repositories/ads_repository_impl.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('banner and native placements cannot be shown directly', () async {
    final service = _FakeAdsService();
    final bannerManager = BannerManager(
      service: service,
      consentManager: ConsentManager(),
      placement: _banner,
    );
    final nativeManager = NativeManager(
      service: service,
      consentManager: ConsentManager(),
      placement: _native,
    );

    await bannerManager.load();
    await nativeManager.load();

    expect(bannerManager.canShow, isFalse);
    expect(nativeManager.canShow, isFalse);
  });

  test(
    'interstitial canShow depends on ready status, lock, and cooldown',
    () async {
      final fullscreenAdController = FullscreenAdController(
        cooldown: const FullscreenAdCooldownConfig(
          interstitialInterval: Duration(seconds: 7),
        ),
        now: () => _now,
      );
      final manager = InterstitialManager(
        service: _FakeAdsService(),
        consentManager: ConsentManager(),
        placement: _interstitial,
        fullscreenAdController: fullscreenAdController,
        preloadAfterShow: true,
      );

      expect(manager.canShow, isFalse);

      await manager.load();

      expect(manager.canShow, isTrue);

      fullscreenAdController.tryAcquire(_rewarded);
      expect(manager.canShow, isFalse);
      fullscreenAdController.release(_rewarded);

      fullscreenAdController.markShown(_interstitial);
      expect(manager.canShow, isFalse);
    },
  );

  test(
    'rewarded canShow depends on ready status and fullscreen lock',
    () async {
      final fullscreenAdController = FullscreenAdController();
      final manager = RewardManager(
        service: _FakeAdsService(),
        consentManager: ConsentManager(),
        placement: _rewarded,
        fullscreenAdController: fullscreenAdController,
        preloadAfterShow: true,
      );

      expect(manager.canShow, isFalse);

      await manager.load();

      expect(manager.canShow, isTrue);

      fullscreenAdController.tryAcquire(_interstitial);
      expect(manager.canShow, isFalse);
    },
  );

  test(
    'app open canShow depends on ready status, expiration, lock, and cooldown',
    () async {
      var now = _now;
      final fullscreenAdController = FullscreenAdController(
        cooldown: const FullscreenAdCooldownConfig(
          appOpenInterval: Duration(seconds: 7),
        ),
        now: () => now,
      );
      final manager = AppOpenManager(
        service: _FakeAdsService(),
        consentManager: ConsentManager(),
        placement: _appOpen,
        fullscreenAdController: fullscreenAdController,
        preloadAfterShow: true,
        expiration: const Duration(minutes: 1),
        now: () => now,
      );

      expect(manager.canShow, isFalse);

      await manager.load();

      expect(manager.canShow, isTrue);

      fullscreenAdController.tryAcquire(_rewarded);
      expect(manager.canShow, isFalse);
      fullscreenAdController.release(_rewarded);

      fullscreenAdController.markShown(_appOpen);
      expect(manager.canShow, isFalse);

      now = _now.add(const Duration(seconds: 8));
      expect(manager.canShow, isTrue);

      now = _now.add(const Duration(minutes: 2));
      expect(manager.canShow, isFalse);
    },
  );

  test(
    'repository updates cooldown for existing fullscreen managers',
    () async {
      final fullscreenAdController = FullscreenAdController(now: () => _now);
      final repository = AdsRepositoryImpl(
        config: _config(
          fullscreenCooldown: const FullscreenAdCooldownConfig(
            interstitialInterval: Duration(seconds: 7),
          ),
        ),
        service: _FakeAdsService(),
        consentManager: ConsentManager(),
        fullscreenAdController: fullscreenAdController,
      );

      await repository.load(_interstitial);
      expect(repository.canShow(_interstitial), isTrue);

      fullscreenAdController.markShown(_interstitial);
      expect(repository.canShow(_interstitial), isFalse);

      repository.updateFullscreenCooldown(
        const FullscreenAdCooldownConfig(interstitialInterval: Duration.zero),
      );

      expect(repository.canShow(_interstitial), isTrue);
    },
  );
}

final _now = DateTime(2026, 1, 1);

const _banner = AdPlacement(key: 'banner', type: AdType.banner);
const _native = AdPlacement(
  key: 'native',
  type: AdType.native,
  nativeFactoryId: 'native_factory',
);
const _interstitial = AdPlacement(
  key: 'interstitial',
  type: AdType.interstitial,
);
const _rewarded = AdPlacement(key: 'rewarded', type: AdType.rewarded);
const _appOpen = AdPlacement(key: 'app_open', type: AdType.appOpen);

AdsConfig _config({FullscreenAdCooldownConfig? fullscreenCooldown}) {
  return AdsConfig(
    environment: AdsEnvironment.test,
    adUnitIds: AdUnitIds({
      _interstitial: 'interstitial-ad-unit-id',
      _appOpen: 'app-open-ad-unit-id',
    }),
    fullscreenCooldown:
        fullscreenCooldown ?? const FullscreenAdCooldownConfig(),
  );
}

class _FakeAdsService implements AdsService {
  @override
  Future<AdResult<void>> initialize(AdsConfig config) async {
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
  Future<AdResult<void>> show(AdPlacement placement) async {
    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) async {
    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) async {
    return const AdResult.success(null);
  }

  @override
  Widget banner(AdPlacement placement) => const SizedBox.shrink();

  @override
  Widget nativeAd(AdPlacement placement) => const SizedBox.shrink();

  @override
  Future<void> clear(AdPlacement placement) async {}

  @override
  Future<void> clearType(AdType type) async {}

  @override
  Future<void> dispose() async {}
}
