import '../../core/config/ads_config.dart';
import '../../core/enums/ad_type.dart';
import '../../core/results/ad_result.dart';
import '../../domain/repositories/ads_repository.dart';
import '../../services/ads_service.dart';

/// Default repository that coordinates domain calls with the configured service.
class AdsRepositoryImpl implements AdsRepository {
  /// Creates an ads repository.
  const AdsRepositoryImpl({required this.config, required this.service});

  /// Runtime ads configuration.
  final AdsConfig config;

  /// SDK-facing ads service.
  final AdsService service;

  @override
  Future<AdResult<void>> initialize() {
    return service.initialize(config);
  }

  @override
  Future<AdResult<void>> load(AdType type) {
    return service.load(type);
  }

  @override
  Future<AdResult<void>> showInterstitial() {
    return service.show(AdType.interstitial);
  }

  @override
  Future<AdResult<void>> showRewarded({
    required void Function() onRewardEarned,
  }) {
    return service.showRewarded(onRewardEarned: onRewardEarned);
  }

  @override
  Future<AdResult<void>> showAppOpen() {
    return service.show(AdType.appOpen);
  }

  @override
  Future<void> dispose() {
    return service.dispose();
  }
}
