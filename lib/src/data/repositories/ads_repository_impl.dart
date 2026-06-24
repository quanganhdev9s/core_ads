import 'package:flutter/widgets.dart';

import '../../core/config/ad_placement.dart';
import '../../core/config/ads_config.dart';
import '../../core/enums/ad_type.dart';
import '../../core/events/ads_failure_event.dart';
import '../../core/fullscreen/fullscreen_ad_controller.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../domain/repositories/ads_repository.dart';
import '../../ads/app_open/app_open_manager.dart';
import '../../ads/banner/banner_ad_config.dart';
import '../../ads/banner/banner_manager.dart';
import '../../ads/interstitial/interstitial_manager.dart';
import '../../ads/native/native_manager.dart';
import '../../ads/rewarded/reward_manager.dart';
import '../../ads/rewarded_interstitial/rewarded_interstitial_manager.dart';
import '../../consent/consent_manager.dart';
import '../../services/ads_service.dart';

/// Default repository that coordinates app calls with ad managers.
class AdsRepositoryImpl implements AdsRepository {
  /// Creates an ads repository.
  AdsRepositoryImpl({
    required this.config,
    required this.service,
    ConsentManager? consentManager,
    FullscreenAdController? fullscreenAdController,
  }) : consentManager = consentManager ?? ConsentManager(),
       fullscreenAdController =
           fullscreenAdController ?? FullscreenAdController();

  /// Runtime ads configuration.
  final AdsConfig config;

  /// SDK-facing ads service.
  final AdsService service;

  /// Consent lifecycle manager.
  final ConsentManager consentManager;

  /// Shared fullscreen ad controller.
  final FullscreenAdController fullscreenAdController;

  final Map<AdPlacement, BannerManager> _bannerManagers = {};
  final Map<AdPlacement, InterstitialManager> _interstitialManagers = {};
  final Map<AdPlacement, RewardManager> _rewardManagers = {};
  final Map<AdPlacement, RewardedInterstitialManager>
  _rewardedInterstitialManagers = {};
  final Map<AdPlacement, AppOpenManager> _appOpenManagers = {};
  final Map<AdPlacement, NativeManager> _nativeManagers = {};

  @override
  Future<AdResult<void>> initialize() async {
    final consentResult = await consentManager.requestConsent(config);
    if (consentResult.isFailure) {
      return consentResult;
    }

    if (!consentManager.canRequestAds) {
      return const AdResult.success(null);
    }

    final initializeResult = await service.initialize(config);
    if (initializeResult.isFailure) {
      return initializeResult;
    }

    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) async {
    final result = await switch (placement.type) {
      AdType.banner => _bannerManager(placement).load(config: bannerConfig),
      AdType.interstitial => _interstitialManager(placement).load(),
      AdType.rewarded => _rewardManager(placement).load(),
      AdType.rewardedInterstitial => _rewardedInterstitialManager(
        placement,
      ).load(),
      AdType.native => _nativeManager(placement).load(),
      AdType.appOpen => _appOpenManager(placement).load(),
    };

    _emitLoadFailure(placement, result);
    return result;
  }

  @override
  Widget banner(AdPlacement placement) {
    if (placement.type != AdType.banner) {
      return const SizedBox.shrink();
    }

    _bannerManager(placement);
    return service.banner(placement);
  }

  @override
  Widget nativeAd(AdPlacement placement) {
    if (placement.type != AdType.native) {
      return const SizedBox.shrink();
    }

    _nativeManager(placement);
    return service.nativeAd(placement);
  }

  @override
  Future<AdResult<void>> showInterstitial(AdPlacement placement) {
    if (placement.type != AdType.interstitial) {
      return Future.value(_invalidPlacement(placement, AdType.interstitial));
    }

    return _interstitialManager(placement).show();
  }

  @override
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) {
    if (placement.type != AdType.rewarded) {
      return Future.value(_invalidPlacement(placement, AdType.rewarded));
    }

    return _rewardManager(placement).show(onRewardEarned: onRewardEarned);
  }

  @override
  Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) {
    if (placement.type != AdType.rewardedInterstitial) {
      return Future.value(
        _invalidPlacement(placement, AdType.rewardedInterstitial),
      );
    }

    return _rewardedInterstitialManager(
      placement,
    ).show(onRewardEarned: onRewardEarned);
  }

  @override
  Future<AdResult<void>> showAppOpen(AdPlacement placement) {
    if (placement.type != AdType.appOpen) {
      return Future.value(_invalidPlacement(placement, AdType.appOpen));
    }

    return _appOpenManager(placement).show();
  }

  @override
  Future<AdResult<void>> handleAppResume(AdPlacement placement) {
    if (placement.type != AdType.appOpen) {
      return Future.value(_invalidPlacement(placement, AdType.appOpen));
    }

    return _appOpenManager(placement).handleAppResume();
  }

  @override
  Future<void> clear(AdPlacement placement) async {
    switch (placement.type) {
      case AdType.banner:
        await _bannerManagers.remove(placement)?.dispose();
      case AdType.interstitial:
        await _interstitialManagers.remove(placement)?.dispose();
      case AdType.rewarded:
        await _rewardManagers.remove(placement)?.dispose();
      case AdType.rewardedInterstitial:
        await _rewardedInterstitialManagers.remove(placement)?.dispose();
      case AdType.appOpen:
        await _appOpenManagers.remove(placement)?.dispose();
      case AdType.native:
        await _nativeManagers.remove(placement)?.dispose();
    }

    await service.clear(placement);
  }

  @override
  Future<void> clearType(AdType type) async {
    final placements = <AdPlacement>{
      ..._bannerManagers.keys,
      ..._interstitialManagers.keys,
      ..._rewardManagers.keys,
      ..._rewardedInterstitialManagers.keys,
      ..._appOpenManagers.keys,
      ..._nativeManagers.keys,
    }.where((placement) => placement.type == type).toList();

    for (final placement in placements) {
      await clear(placement);
    }

    await service.clearType(type);
  }

  BannerManager _bannerManager(AdPlacement placement) {
    return _bannerManagers.putIfAbsent(
      placement,
      () => BannerManager(
        service: service,
        consentManager: consentManager,
        placement: placement,
      ),
    );
  }

  InterstitialManager _interstitialManager(AdPlacement placement) {
    return _interstitialManagers.putIfAbsent(
      placement,
      () => InterstitialManager(
        service: service,
        consentManager: consentManager,
        placement: placement,
        fullscreenAdController: fullscreenAdController,
        fullscreenCooldown: config.fullscreenCooldown,
      ),
    );
  }

  RewardManager _rewardManager(AdPlacement placement) {
    return _rewardManagers.putIfAbsent(
      placement,
      () => RewardManager(
        service: service,
        consentManager: consentManager,
        placement: placement,
        fullscreenAdController: fullscreenAdController,
      ),
    );
  }

  RewardedInterstitialManager _rewardedInterstitialManager(
    AdPlacement placement,
  ) {
    return _rewardedInterstitialManagers.putIfAbsent(
      placement,
      () => RewardedInterstitialManager(
        service: service,
        consentManager: consentManager,
        placement: placement,
        fullscreenAdController: fullscreenAdController,
      ),
    );
  }

  AppOpenManager _appOpenManager(AdPlacement placement) {
    return _appOpenManagers.putIfAbsent(
      placement,
      () => AppOpenManager(
        service: service,
        consentManager: consentManager,
        placement: placement,
        fullscreenAdController: fullscreenAdController,
        fullscreenCooldown: config.fullscreenCooldown,
      ),
    );
  }

  NativeManager _nativeManager(AdPlacement placement) {
    return _nativeManagers.putIfAbsent(
      placement,
      () => NativeManager(
        service: service,
        consentManager: consentManager,
        placement: placement,
      ),
    );
  }

  AdResult<void> _invalidPlacement(AdPlacement placement, AdType expectedType) {
    return AdResult.failure(
      AdFailure(
        code: 'invalid_placement_type',
        message:
            'Placement ${placement.key} uses ${placement.type.name}, expected ${expectedType.name}.',
      ),
    );
  }

  void _emitLoadFailure(AdPlacement placement, AdResult<void> result) {
    if (result case AdFailed<void>(failure: final failure)) {
      config.callbacks.onFailed?.call(
        AdsFailureEvent(
          placement: placement,
          network: config.network,
          failure: failure,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    final managers = [
      ..._bannerManagers.values,
      ..._interstitialManagers.values,
      ..._rewardManagers.values,
      ..._rewardedInterstitialManagers.values,
      ..._appOpenManagers.values,
      ..._nativeManagers.values,
    ];

    for (final manager in managers) {
      await manager.dispose();
    }

    _bannerManagers.clear();
    _interstitialManagers.clear();
    _rewardManagers.clear();
    _rewardedInterstitialManagers.clear();
    _appOpenManagers.clear();
    _nativeManagers.clear();
    fullscreenAdController.reset();

    await service.dispose();
  }
}
