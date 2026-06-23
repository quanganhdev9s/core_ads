import 'package:flutter/widgets.dart';

import 'core/config/ads_config.dart';
import 'core/config/ad_placement.dart';
import 'core/results/ad_failure.dart';
import 'core/results/ad_result.dart';
import 'data/repositories/ads_repository_impl.dart';
import 'domain/repositories/ads_repository.dart';
import 'services/ads_service.dart';
import 'services/google_ads_service.dart';
import 'managers/google_consent_manager.dart';

/// Public entry-point used by applications to interact with ads.
class FlutterAds {
  FlutterAds._();

  static AdsRepository? _repository;

  /// Initializes the ads package.
  ///
  /// A custom [repository] can be provided by advanced integrations. Most apps
  /// should pass [config] and let the package create its internal repository.
  static Future<AdResult<void>> initialize(
    AdsConfig config, {
    AdsRepository? repository,
    AdsService? service,
  }) async {
    if (repository != null) {
      _repository = repository;
      return _repository!.initialize();
    }

    final resolvedService = service ?? GoogleAdsService();

    _repository = AdsRepositoryImpl(
      config: config,
      service: resolvedService,
      consentManager: service == null ? GoogleConsentManager() : null,
    );

    return _repository!.initialize();
  }

  /// Shows an interstitial ad for [placement] if one is ready.
  static Future<AdResult<void>> showInterstitial(AdPlacement placement) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showInterstitial(placement);
  }

  /// Shows a rewarded ad for [placement] if one is ready.
  ///
  /// [onRewardEarned] is called only after the underlying ad network confirms
  /// the user earned the reward.
  static Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showRewarded(
      placement: placement,
      onRewardEarned: onRewardEarned,
    );
  }

  /// Shows a rewarded interstitial ad for [placement] if one is ready.
  ///
  /// [onRewardEarned] is called only after the underlying ad network confirms
  /// the user earned the reward.
  static Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showRewardedInterstitial(
      placement: placement,
      onRewardEarned: onRewardEarned,
    );
  }

  /// Shows an app open ad for [placement] if one is ready and valid.
  static Future<AdResult<void>> showAppOpen(AdPlacement placement) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showAppOpen(placement);
  }

  /// Handles an app resume event for an app open ad [placement].
  static Future<AdResult<void>> handleAppResume(AdPlacement placement) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.handleAppResume(placement);
  }

  /// Requests loading an ad for [placement].
  ///
  /// This is mainly useful for explicit preloading in advanced flows.
  static Future<AdResult<void>> load(AdPlacement placement) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.load(placement);
  }

  /// Builds a banner widget for [placement].
  static Widget banner(AdPlacement placement) {
    final repository = _repository;
    if (repository == null) {
      return const SizedBox.shrink();
    }

    return repository.banner(placement);
  }

  /// Builds a native ad widget for [placement].
  static Widget nativeAd(AdPlacement placement) {
    final repository = _repository;
    if (repository == null) {
      return const SizedBox.shrink();
    }

    return repository.nativeAd(placement);
  }

  /// Disposes ads resources.
  static Future<void> dispose() async {
    await _repository?.dispose();
    _repository = null;
  }
}
