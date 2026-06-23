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

  @override
  AdLoadStatus get status => _status;

  /// Whether a native ad is available for rendering.
  bool get hasCachedNativeAd => _status == AdLoadStatus.ready;

  @override
  Future<AdResult<void>> load() async {
    if (!consentManager.canRequestAds) {
      _status = AdLoadStatus.failed;
      return const AdResult.failure(AdFailure.consentDenied());
    }

    if (hasCachedNativeAd) {
      return const AdResult.success(null);
    }

    _status = AdLoadStatus.loading;
    final result = await service.load(placement);
    _status = result.isSuccess ? AdLoadStatus.ready : AdLoadStatus.failed;

    return result;
  }

  @override
  Future<void> dispose() async {
    _status = AdLoadStatus.disposed;
  }
}
