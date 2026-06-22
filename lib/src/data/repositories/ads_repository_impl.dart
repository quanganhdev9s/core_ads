import '../../core/config/ads_config.dart';
import '../../core/enums/ad_type.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../domain/repositories/ads_repository.dart';
import '../../managers/app_open_manager.dart';
import '../../managers/banner_manager.dart';
import '../../managers/consent_manager.dart';
import '../../managers/interstitial_manager.dart';
import '../../managers/native_manager.dart';
import '../../managers/reward_manager.dart';
import '../../services/ads_service.dart';

/// Default repository that coordinates app calls with ad managers.
class AdsRepositoryImpl implements AdsRepository {
  /// Creates an ads repository.
  factory AdsRepositoryImpl({
    required AdsConfig config,
    required AdsService service,
    ConsentManager? consentManager,
    BannerManager? bannerManager,
    InterstitialManager? interstitialManager,
    RewardManager? rewardManager,
    AppOpenManager? appOpenManager,
    NativeManager? nativeManager,
  }) {
    final resolvedConsentManager = consentManager ?? ConsentManager();

    return AdsRepositoryImpl._(
      config: config,
      service: service,
      consentManager: resolvedConsentManager,
      bannerManager:
          bannerManager ??
          BannerManager(
            service: service,
            consentManager: resolvedConsentManager,
          ),
      interstitialManager:
          interstitialManager ??
          InterstitialManager(
            service: service,
            consentManager: resolvedConsentManager,
          ),
      rewardManager:
          rewardManager ??
          RewardManager(
            service: service,
            consentManager: resolvedConsentManager,
          ),
      appOpenManager:
          appOpenManager ??
          AppOpenManager(
            service: service,
            consentManager: resolvedConsentManager,
          ),
      nativeManager:
          nativeManager ??
          NativeManager(
            service: service,
            consentManager: resolvedConsentManager,
          ),
    );
  }

  const AdsRepositoryImpl._({
    required this.config,
    required this.service,
    required this.consentManager,
    required this.bannerManager,
    required this.interstitialManager,
    required this.rewardManager,
    required this.appOpenManager,
    required this.nativeManager,
  });

  /// Runtime ads configuration.
  final AdsConfig config;

  /// SDK-facing ads service.
  final AdsService service;

  /// Consent lifecycle manager.
  final ConsentManager consentManager;

  /// Banner lifecycle manager.
  final BannerManager bannerManager;

  /// Interstitial lifecycle manager.
  final InterstitialManager interstitialManager;

  /// Rewarded lifecycle manager.
  final RewardManager rewardManager;

  /// App open lifecycle manager.
  final AppOpenManager appOpenManager;

  /// Native lifecycle manager.
  final NativeManager nativeManager;

  @override
  Future<AdResult<void>> initialize() async {
    final consentResult = await consentManager.requestConsent();
    if (consentResult.isFailure) {
      return consentResult;
    }

    final initializeResult = await service.initialize(config);
    if (initializeResult.isFailure) {
      return initializeResult;
    }

    await interstitialManager.load();
    await rewardManager.load();
    await appOpenManager.load();

    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> load(AdType type) {
    return switch (type) {
      AdType.banner => bannerManager.load(),
      AdType.interstitial => interstitialManager.load(),
      AdType.rewarded => rewardManager.load(),
      AdType.rewardedInterstitial => Future.value(
        const AdResult.failure(
          AdFailure(
            code: 'unsupported_ad_type',
            message: 'Rewarded interstitial is not implemented yet.',
          ),
        ),
      ),
      AdType.native => nativeManager.load(),
      AdType.appOpen => appOpenManager.load(),
    };
  }

  @override
  Future<AdResult<void>> showInterstitial() {
    return interstitialManager.show();
  }

  @override
  Future<AdResult<void>> showRewarded({
    required void Function() onRewardEarned,
  }) {
    return rewardManager.show(onRewardEarned: onRewardEarned);
  }

  @override
  Future<AdResult<void>> showAppOpen() {
    return appOpenManager.show();
  }

  @override
  Future<void> dispose() async {
    await bannerManager.dispose();
    await interstitialManager.dispose();
    await rewardManager.dispose();
    await appOpenManager.dispose();
    await nativeManager.dispose();
    await service.dispose();
  }
}
