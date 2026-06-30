import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_load_status.dart';
import '../../core/fullscreen/fullscreen_ad_cooldown_config.dart';
import '../../core/fullscreen/fullscreen_ad_controller.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../services/ads_service.dart';
import '../../managers/ad_manager.dart';
import '../../consent/consent_manager.dart';

/// Manages interstitial ad preload, show, and reload flow.
class InterstitialManager implements AdManager {
  /// Creates an interstitial manager.
  InterstitialManager({
    required this.service,
    required this.consentManager,
    required this.placement,
    required this.fullscreenAdController,
    required this.fullscreenCooldown,
    required this.preloadAfterShow,
  });

  final AdsService service;
  final ConsentManager consentManager;
  final AdPlacement placement;
  final FullscreenAdController fullscreenAdController;
  final FullscreenAdCooldownConfig fullscreenCooldown;
  final bool preloadAfterShow;

  AdLoadStatus _status = AdLoadStatus.idle;
  Future<AdResult<void>>? _loadFuture;

  @override
  AdLoadStatus get status => _status;

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
    _status = result.isSuccess ? AdLoadStatus.ready : AdLoadStatus.failed;

    return result;
  }

  /// Shows the preloaded interstitial ad.
  Future<AdResult<void>> show() async {
    if (_status != AdLoadStatus.ready) {
      return const AdResult.failure(AdFailure.notReady());
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

    final AdResult<void> result;
    try {
      result = await service.show(placement);
    } finally {
      fullscreenAdController.release(placement);
    }
    _status = result.isSuccess ? AdLoadStatus.shown : AdLoadStatus.failed;

    if (result.isSuccess) {
      fullscreenAdController.markShown(placement);
      if (preloadAfterShow) {
        await load();
      }
    }

    return result;
  }

  @override
  Future<void> dispose() async {
    _loadFuture = null;
    _status = AdLoadStatus.disposed;
  }
}
