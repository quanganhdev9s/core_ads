import '../core/enums/ad_load_status.dart';
import '../core/enums/ad_type.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import '../services/ads_service.dart';
import 'ad_manager.dart';
import 'consent_manager.dart';

/// Manages rewarded ad preload, show, reward callback, and reload flow.
class RewardManager implements AdManager {
  /// Creates a reward manager.
  RewardManager({required this.service, required this.consentManager});

  final AdsService service;
  final ConsentManager consentManager;

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
    final result = await service.load(AdType.rewarded);
    _status = result.isSuccess ? AdLoadStatus.ready : AdLoadStatus.failed;

    return result;
  }

  /// Shows the preloaded rewarded ad.
  Future<AdResult<void>> show({required void Function() onRewardEarned}) async {
    if (_status != AdLoadStatus.ready) {
      return const AdResult.failure(AdFailure.notReady());
    }

    final result = await service.showRewarded(onRewardEarned: onRewardEarned);
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
