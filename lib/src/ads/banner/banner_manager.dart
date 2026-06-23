import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_load_status.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../services/ads_service.dart';
import '../../managers/ad_manager.dart';
import '../../consent/consent_manager.dart';
import 'banner_ad_config.dart';

/// Manages banner ad loading and cache state.
class BannerManager implements AdManager {
  /// Creates a banner manager.
  BannerManager({
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

  /// Whether a banner is available to be reused.
  bool get hasCachedBanner => _status == AdLoadStatus.ready;

  @override
  Future<AdResult<void>> load({BannerAdConfig? config}) async {
    if (!consentManager.canRequestAds) {
      _status = AdLoadStatus.failed;
      return const AdResult.failure(AdFailure.consentDenied());
    }

    if (hasCachedBanner) {
      return const AdResult.success(null);
    }

    _status = AdLoadStatus.loading;
    final result = await service.load(placement, bannerConfig: config);
    _status = result.isSuccess ? AdLoadStatus.ready : AdLoadStatus.failed;

    return result;
  }

  @override
  Future<void> dispose() async {
    _status = AdLoadStatus.disposed;
  }
}
