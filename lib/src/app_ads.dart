import 'package:flutter/widgets.dart';

import 'core/config/ads_config.dart';
import 'core/config/ad_placement.dart';
import 'core/consent/ads_consent_notifier.dart';
import 'core/enums/ad_load_status.dart';
import 'core/enums/ad_type.dart';
import 'core/fullscreen/fullscreen_ad_cooldown_config.dart';
import 'core/load/ads_load_notifier.dart';
import 'core/reload/ads_reload_notifier.dart';
import 'core/results/ad_failure.dart';
import 'core/results/ad_result.dart';
import 'ads/banner/banner_ad_config.dart';
import 'data/repositories/ads_repository_impl.dart';
import 'domain/repositories/ads_repository.dart';
import 'services/ads_service.dart';
import 'services/google_ads_service.dart';
import 'consent/google_consent_manager.dart';

/// Public entry-point used by applications to interact with ads.
class CoreAds {
  CoreAds._();

  static AdsRepository? _repository;

  /// Adds a listener for placement load operation progress.
  ///
  /// Use [getStatus] when the app needs the current placement cache status.
  static void addLoadListener(AdsLoadListener listener) {
    AdsLoadNotifier.instance.addListener(listener);
  }

  /// Removes a listener for placement load operation progress.
  static void removeLoadListener(AdsLoadListener listener) {
    AdsLoadNotifier.instance.removeListener(listener);
  }

  /// Adds a listener called when the consent request flow completes.
  static void addConsentListener(AdsConsentListener listener) {
    AdsConsentNotifier.instance.addListener(listener);
  }

  /// Removes a consent completion listener.
  static void removeConsentListener(AdsConsentListener listener) {
    AdsConsentNotifier.instance.removeListener(listener);
  }

  /// Whether the app must show an entry point to the privacy options form.
  ///
  /// True once a user has seen a GDPR message that allows changing the choice
  /// later. Use it to show or hide a settings row that calls
  /// [showPrivacyOptionsForm].
  static Future<bool> isPrivacyOptionsRequired() =>
      GoogleConsentManager.isPrivacyOptionsRequired();

  /// Reopens the privacy options form configured in the AdMob UI.
  static Future<AdResult<void>> showPrivacyOptionsForm() =>
      GoogleConsentManager.showPrivacyOptionsForm();

  /// Initializes the ads package.
  ///
  /// A custom [repository] can be provided by advanced integrations. Most apps
  /// should pass [config] and let the package create its internal repository.
  static Future<AdResult<void>> initialize(
    AdsConfig config, {
    AdsRepository? repository,
    AdsService? service,
  }) async {
    final nextRepository =
        repository ??
        AdsRepositoryImpl(
          config: config,
          service: service ?? GoogleAdsService(),
          consentManager: service == null ? GoogleConsentManager() : null,
        );
    final previousRepository = _repository;
    final result = await nextRepository.initialize();

    if (result.isFailure) {
      if (!identical(nextRepository, previousRepository)) {
        await nextRepository.dispose();
      }
      return result;
    }

    _repository = nextRepository;
    if (!identical(previousRepository, nextRepository)) {
      await previousRepository?.dispose();
    }

    return result;
  }

  /// Shows an interstitial ad for [placement] if one is ready.
  /// [onShown] runs for this show when the SDK confirms the ad is visible.
  static Future<AdResult<void>> showInterstitial(
    AdPlacement placement, {
    void Function()? onShown,
  }) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showInterstitial(placement, onShown: onShown);
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
  /// [onShown] runs for this show when the SDK confirms the ad is visible.
  static Future<AdResult<void>> showAppOpen(
    AdPlacement placement, {
    void Function()? onShown,
  }) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showAppOpen(placement, onShown: onShown);
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
  static Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) {
    final repository = _repository;
    if (repository == null) {
      AdsLoadNotifier.instance.notify(
        placement,
        AdLoadStatus.failed,
        failure: const AdFailure.notReady(),
      );
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.load(placement, bannerConfig: bannerConfig);
  }

  /// Returns current load/cache status for [placement].
  static AdLoadStatus getStatus(AdPlacement placement) {
    return _repository?.getStatus(placement) ?? AdLoadStatus.idle;
  }

  /// Checks whether a fullscreen show attempt is allowed, independent of load status.
  static bool canAttemptShow(AdPlacement placement) {
    return _repository?.canAttemptShow(placement) ?? false;
  }

  /// Returns whether [placement] currently has a showable fullscreen ad.
  static bool canShow(AdPlacement placement) {
    return _repository?.canShow(placement) ?? false;
  }

  /// Updates fullscreen ad cooldown rules after initialization.
  static void updateFullscreenCooldown(FullscreenAdCooldownConfig cooldown) {
    _repository?.updateFullscreenCooldown(cooldown);
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

  /// Clears cached ad resources for [placement].
  static Future<void> clear(AdPlacement placement) async {
    await _repository?.clear(placement);
    AdsReloadNotifier.instance.notifyPlacement(placement);
  }

  /// Clears cached ad resources for all placements of [type].
  static Future<void> clearType(AdType type) async {
    await _repository?.clearType(type);
    AdsReloadNotifier.instance.notifyType(type);
  }

  /// Disposes ads resources.
  static Future<void> dispose() async {
    await _repository?.dispose();
    _repository = null;
  }
}
