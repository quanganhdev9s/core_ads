import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_load_status.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../services/ads_service.dart';
import '../../managers/ad_manager.dart';
import '../../consent/consent_manager.dart';

/// Manages native ad loading and cache state.
class NativeManager implements AdManager {
  /// Creates a native ad manager.
  NativeManager({
    required this.service,
    required this.consentManager,
    required this.placement,
  });

  final AdsService service;
  final ConsentManager consentManager;
  final AdPlacement placement;

  AdLoadStatus _status = AdLoadStatus.idle;
  Future<AdResult<void>>? _loadFuture;
  bool _disposed = false;

  @override
  AdLoadStatus get status => _status;

  @override
  bool get canShow => false;

  /// Whether a native ad is available for rendering.
  bool get hasCachedNativeAd => _status == AdLoadStatus.ready;

  @override
  Future<AdResult<void>> load() async {
    if (_disposed) {
      return const AdResult.failure(
        AdFailure(code: 'load_cancelled', message: 'Native ad load cancelled'),
      );
    }
    if (!consentManager.canRequestAds) {
      _status = AdLoadStatus.failed;
      return const AdResult.failure(AdFailure.consentDenied());
    }

    if (hasCachedNativeAd) {
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
    _status = AdLoadStatus.loading;
    final result = await service.load(placement);
    if (_disposed) {
      return const AdResult.failure(
        AdFailure(code: 'load_cancelled', message: 'Native ad load cancelled'),
      );
    }
    _status = result.isSuccess ? AdLoadStatus.ready : AdLoadStatus.failed;

    return result;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _loadFuture = null;
    _status = AdLoadStatus.idle;
  }
}
