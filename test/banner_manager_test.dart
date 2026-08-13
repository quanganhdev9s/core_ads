import 'dart:async';

import 'package:core_ads/core_ads.dart';
import 'package:core_ads/src/ads/banner/banner_manager.dart';
import 'package:core_ads/src/consent/consent_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const placement = AdPlacement(key: 'home_banner', type: AdType.banner);

  test('reuses cached banner when config is unchanged', () async {
    final service = _FakeAdsService();
    final manager = BannerManager(
      service: service,
      consentManager: ConsentManager(),
      placement: placement,
    );
    const config = BannerAdConfig.banner();

    await manager.load(config: config);
    await manager.load(config: config);

    expect(service.loadedConfigs, [config]);
    expect(manager.status, AdLoadStatus.ready);
  });

  test('reloads cached banner when config changes', () async {
    final service = _FakeAdsService();
    final manager = BannerManager(
      service: service,
      consentManager: ConsentManager(),
      placement: placement,
    );
    const firstConfig = BannerAdConfig.anchoredAdaptive(width: 320);
    const secondConfig = BannerAdConfig.anchoredAdaptive(width: 480);

    await manager.load(config: firstConfig);
    await manager.load(config: secondConfig);

    expect(service.loadedConfigs, [firstConfig, secondConfig]);
    expect(manager.status, AdLoadStatus.ready);
  });

  test('shares in-flight banner load when config is unchanged', () async {
    final loadCompleter = Completer<AdResult<void>>();
    final service = _FakeAdsService(loadCompleter: loadCompleter);
    final manager = BannerManager(
      service: service,
      consentManager: ConsentManager(),
      placement: placement,
    );
    const config = BannerAdConfig.banner();

    final firstLoad = manager.load(config: config);
    final secondLoad = manager.load(config: config);

    expect(service.loadedConfigs, [config]);

    loadCompleter.complete(const AdResult.success(null));

    expect((await firstLoad).isSuccess, isTrue);
    expect((await secondLoad).isSuccess, isTrue);
    expect(service.loadedConfigs, [config]);
    expect(manager.status, AdLoadStatus.ready);
  });

  test('queues in-flight banner load when config changes', () async {
    final firstLoadCompleter = Completer<AdResult<void>>();
    final service = _FakeAdsService(loadCompleter: firstLoadCompleter);
    final manager = BannerManager(
      service: service,
      consentManager: ConsentManager(),
      placement: placement,
    );
    const firstConfig = BannerAdConfig.anchoredAdaptive(width: 320);
    const secondConfig = BannerAdConfig.anchoredAdaptive(width: 480);

    final firstLoad = manager.load(config: firstConfig);
    final secondLoad = manager.load(config: secondConfig);

    expect(service.loadedConfigs, [firstConfig]);

    firstLoadCompleter.complete(const AdResult.success(null));

    expect((await firstLoad).isSuccess, isTrue);
    expect((await secondLoad).isSuccess, isTrue);
    expect(service.loadedConfigs, [firstConfig, secondConfig]);
    expect(manager.status, AdLoadStatus.ready);
  });
}

class _FakeAdsService implements AdsService {
  _FakeAdsService({this.loadCompleter});

  final Completer<AdResult<void>>? loadCompleter;
  final List<BannerAdConfig?> loadedConfigs = [];

  @override
  Future<AdResult<void>> initialize(AdsConfig config) async {
    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async {
    loadedConfigs.add(bannerConfig);
    return loadCompleter?.future ?? const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> show(AdPlacement placement) async {
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
