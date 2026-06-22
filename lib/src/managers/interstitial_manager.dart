import '../core/config/ad_placement.dart';
import '../core/enums/ad_load_status.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import '../services/ads_service.dart';
import 'ad_manager.dart';
import 'consent_manager.dart';

/// Manages interstitial ad preload, show, and reload flow.
class InterstitialManager implements AdManager {
  /// Creates an interstitial manager.
  InterstitialManager({
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

  @override
  Future<AdResult<void>> load() async {
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

    final result = await service.show(placement);
    _status = result.isSuccess ? AdLoadStatus.shown : AdLoadStatus.failed;

    if (result.isSuccess) {
      await load();
    }

    return result;
  }

  @override
  Future<void> dispose() async {
    _status = AdLoadStatus.disposed;
  }
}
