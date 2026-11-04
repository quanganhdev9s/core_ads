import 'package:core_ads/core_ads.dart';
import 'package:core_ads/src/consent/consent_manager.dart';
import 'package:core_ads/src/core/events/ads_consent_event.dart';
import 'package:core_ads/src/data/repositories/ads_repository_impl.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await CoreAds.dispose();
  });

  test('CoreAds notifies when consent request completes', () async {
    final events = <AdsConsentEvent>[];
    void listener(AdsConsentEvent event) {
      events.add(event);
    }

    CoreAds.addConsentListener(listener);
    addTearDown(() => CoreAds.removeConsentListener(listener));

    await CoreAds.initialize(_config(), service: _FakeAdsService());

    expect(events, hasLength(1));
    expect(events.single.result.isSuccess, isTrue);
    expect(events.single.canRequestAds, isTrue);
    expect(events.single.failure, isNull);
  });

  test(
    'repository notifies consent completion before skipping service init',
    () async {
      final events = <AdsConsentEvent>[];
      void listener(AdsConsentEvent event) {
        events.add(event);
      }

      CoreAds.addConsentListener(listener);
      addTearDown(() => CoreAds.removeConsentListener(listener));

      final service = _FakeAdsService();
      final repository = AdsRepositoryImpl(
        config: _config(),
        service: service,
        consentManager: _FakeConsentManager(canRequestAdsAfterRequest: false),
      );

      final result = await repository.initialize();

      expect(result.isSuccess, isTrue);
      expect(service.initializeCount, 0);
      expect(events, hasLength(1));
      expect(events.single.result.isSuccess, isTrue);
      expect(events.single.canRequestAds, isFalse);
    },
  );

  test('repository notifies consent failure', () async {
    final events = <AdsConsentEvent>[];
    void listener(AdsConsentEvent event) {
      events.add(event);
    }

    CoreAds.addConsentListener(listener);
    addTearDown(() => CoreAds.removeConsentListener(listener));

    final repository = AdsRepositoryImpl(
      config: _config(),
      service: _FakeAdsService(),
      consentManager: _FakeConsentManager(
        result: const AdResult.failure(
          AdFailure(code: 'consent_failed', message: 'Consent failed'),
        ),
        canRequestAdsAfterRequest: false,
      ),
    );

    final result = await repository.initialize();

    expect(result.isFailure, isTrue);
    expect(events, hasLength(1));
    expect(events.single.result.isFailure, isTrue);
    expect(events.single.canRequestAds, isFalse);
    expect(events.single.failure?.code, 'consent_failed');
  });
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

class _FakeConsentManager extends ConsentManager {
  _FakeConsentManager({
    this.result = const AdResult.success(null),
    required this.canRequestAdsAfterRequest,
  });

  final AdResult<void> result;
  final bool canRequestAdsAfterRequest;

  @override
  Future<AdResult<void>> requestConsent(AdsConfig config) async {
    updateCanRequestAds(canRequestAdsAfterRequest);
    return result;
  }
}

class _FakeAdsService implements AdsService {
  int initializeCount = 0;

  @override
  Future<AdResult<void>> initialize(AdsConfig config) async {
    initializeCount += 1;
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
