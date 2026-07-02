import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_load_status.dart';
import '../../core/fullscreen/fullscreen_ad_controller.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../services/ads_service.dart';
import '../../managers/ad_manager.dart';
import '../../consent/consent_manager.dart';

/// Manages rewarded ad preload, show, reward callback, and reload flow.
class RewardManager implements AdManager {
  /// Creates a reward manager.
  RewardManager({
    required this.service,
    required this.consentManager,
    required this.placement,
    required this.fullscreenAdController,
    required this.preloadAfterShow,
  });

  final AdsService service;
  final ConsentManager consentManager;
  final AdPlacement placement;
  final FullscreenAdController fullscreenAdController;
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

  /// Shows the preloaded rewarded ad.
  Future<AdResult<void>> show({required void Function() onRewardEarned}) async {
    if (_status != AdLoadStatus.ready) {
      return const AdResult.failure(AdFailure.notReady());
    }

    final lockResult = fullscreenAdController.tryAcquire(placement);
    if (lockResult.isFailure) {
      return lockResult;
    }

    final AdResult<void> result;
    try {
      result = await service.showRewarded(
        placement: placement,
        onRewardEarned: onRewardEarned,
      );
    } finally {
      fullscreenAdController.release(placement);
    }
    _status = result.isSuccess ? AdLoadStatus.idle : AdLoadStatus.failed;

    if (result.isSuccess && preloadAfterShow) {
      await load();
    }

    return result;
  }

  @override
  Future<void> dispose() async {
    _loadFuture = null;
    _status = AdLoadStatus.idle;
  }
}
