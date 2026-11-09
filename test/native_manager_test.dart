import 'dart:async';

import 'package:core_ads/core_ads.dart';
import 'package:core_ads/src/ads/native/native_manager.dart';
import 'package:core_ads/src/consent/consent_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const placement = AdPlacement(key: 'feed_native', type: AdType.native);

  test('shares in-flight native load for the same placement', () async {
    final loadCompleter = Completer<AdResult<void>>();
    final service = _FakeAdsService(loadCompleter: loadCompleter);
    final manager = NativeManager(
      service: service,
      consentManager: ConsentManager(),
      placement: placement,
    );

    final firstLoad = manager.load();
    final secondLoad = manager.load();

    expect(service.loadCount, 1);

    loadCompleter.complete(const AdResult.success(null));

    expect((await firstLoad).isSuccess, isTrue);
    expect((await secondLoad).isSuccess, isTrue);
    expect(service.loadCount, 1);
    expect(manager.status, AdLoadStatus.ready);
  });

  test('dispose leaves a pending native load cancelled and idle', () async {
    final completer = Completer<AdResult<void>>();
    final manager = NativeManager(
      service: _FakeAdsService(loadCompleter: completer),
      consentManager: ConsentManager(),
      placement: placement,
    );
    final pending = manager.load();
    await manager.dispose();
    completer.complete(const AdResult.success(null));
    final result = await pending;
    expect(result, isA<AdFailed<void>>());
    expect((result as AdFailed<void>).failure.code, 'load_cancelled');
    expect(manager.status, AdLoadStatus.idle);
  });
}

class _FakeAdsService implements AdsService {
  _FakeAdsService({this.loadCompleter});

  final Completer<AdResult<void>>? loadCompleter;
  int loadCount = 0;

  @override
  Future<AdResult<void>> initialize(AdsConfig config) async {
    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async {
    loadCount += 1;
    return loadCompleter?.future ?? const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> show(
    AdPlacement placement, {
    void Function()? onShown,
  }) async {
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
