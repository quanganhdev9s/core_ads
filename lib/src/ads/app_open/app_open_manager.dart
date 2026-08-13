import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_load_status.dart';
import '../../core/fullscreen/fullscreen_ad_cooldown_config.dart';
import '../../core/fullscreen/fullscreen_ad_controller.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../services/ads_service.dart';
import '../../managers/ad_manager.dart';
import '../../consent/consent_manager.dart';

/// Manages app open ad cache, expiration, and show flow.
class AppOpenManager implements AdManager {
  /// Creates an app open manager.
  AppOpenManager({
    required this.service,
    required this.consentManager,
    required this.placement,
    required this.fullscreenAdController,
    required this.fullscreenCooldown,
    required this.preloadAfterShow,
    this.expiration = const Duration(minutes: 60),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AdsService service;
  final ConsentManager consentManager;
  final AdPlacement placement;
  final FullscreenAdController fullscreenAdController;
  final FullscreenAdCooldownConfig fullscreenCooldown;
  final bool preloadAfterShow;
  final Duration expiration;
  final DateTime Function() _now;

  AdLoadStatus _status = AdLoadStatus.idle;
  DateTime? _loadedAt;
  bool _isShowing = false;
  Future<AdResult<void>>? _loadFuture;

  @override
  AdLoadStatus get status => _status;

  @override
  bool get canShow {
    if (_isShowing ||
        _status != AdLoadStatus.ready ||
        isExpired ||
        fullscreenAdController.isShowing) {
      return false;
    }

    return fullscreenAdController
        .canShow(placement, fullscreenCooldown)
        .isSuccess;
  }

  /// Whether the cached app open ad has expired.
  bool get isExpired {
    final loadedAt = _loadedAt;
    if (loadedAt == null) {
      return true;
    }

    return _now().difference(loadedAt) >= expiration;
  }

  @override
  Future<AdResult<void>> load() async {
    if (_status == AdLoadStatus.ready) {
      return const AdResult.success(null);
    }

    final existingLoad = _loadFuture;
    if (existingLoad != null) {
      return existingLoad;
    }

    final loadFuture = _load();
    _loadFuture = loadFuture;

    try {
      return await loadFuture;
    } finally {
      if (identical(_loadFuture, loadFuture)) {
        _loadFuture = null;
      }
    }
  }

  Future<AdResult<void>> _load() async {
    if (!consentManager.canRequestAds) {
      _status = AdLoadStatus.failed;
      return const AdResult.failure(AdFailure.consentDenied());
    }

    _status = AdLoadStatus.loading;
    final result = await service.load(placement);
    if (result.isSuccess) {
      _status = AdLoadStatus.ready;
      _loadedAt = _now();
    } else {
      _status = AdLoadStatus.failed;
      _loadedAt = null;
    }

    return result;
  }

  /// Shows the app open ad only when it is ready and not expired.
  Future<AdResult<void>> show() async {
    if (_isShowing) {
      return const AdResult.failure(
        AdFailure(
          code: 'already_showing',
          message: 'App open ad is already showing.',
        ),
      );
    }

    if (_status != AdLoadStatus.ready) {
      return const AdResult.failure(AdFailure.notReady());
    }

    if (isExpired) {
      _status = AdLoadStatus.failed;
      _loadedAt = null;
      return const AdResult.failure(
        AdFailure(code: 'expired', message: 'App open ad has expired.'),
      );
    }

    final cooldownResult = fullscreenAdController.canShow(
      placement,
      fullscreenCooldown,
    );
    if (cooldownResult.isFailure) {
      return cooldownResult;
    }

    final lockResult = fullscreenAdController.tryAcquire(placement);
    if (lockResult.isFailure) {
      return lockResult;
    }

    _isShowing = true;
    final AdResult<void> result;
    try {
      result = await service.show(placement);
    } finally {
      _isShowing = false;
      fullscreenAdController.release(placement);
    }
    _status = result.isSuccess ? AdLoadStatus.idle : AdLoadStatus.failed;

    if (result.isSuccess) {
      fullscreenAdController.markShown(placement);
      if (preloadAfterShow) {
        await load();
      }
    }

    return result;
  }

  /// Handles an app resume event.
  ///
  /// Shows a valid cached app open ad. If none is ready, or the cached ad is
  /// expired, this method loads a fresh ad instead.
  Future<AdResult<void>> handleAppResume() async {
    if (_isShowing || _status == AdLoadStatus.loading) {
      return const AdResult.success(null);
    }

    if (_status != AdLoadStatus.ready) {
      return load();
    }

    if (isExpired) {
      _status = AdLoadStatus.failed;
      _loadedAt = null;
      return load();
    }

    return show();
  }

  @override
  Future<void> dispose() async {
    _status = AdLoadStatus.idle;
    _loadedAt = null;
    _isShowing = false;
    _loadFuture = null;
  }
}
