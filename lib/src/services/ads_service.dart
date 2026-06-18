import '../core/config/ads_config.dart';
import '../core/enums/ad_type.dart';
import '../core/results/ad_result.dart';

/// SDK-facing contract implemented by concrete ad network services.
abstract interface class AdsService {
  /// Initializes the ad network SDK.
  Future<AdResult<void>> initialize(AdsConfig config);

  /// Loads an ad for [type].
  Future<AdResult<void>> load(AdType type);

  /// Shows an ad for [type].
  Future<AdResult<void>> show(AdType type);

  /// Shows a rewarded ad and calls [onRewardEarned] only when the SDK confirms
  /// the reward.
  Future<AdResult<void>> showRewarded({
    required void Function() onRewardEarned,
  });

  /// Disposes resources owned by this service.
  Future<void> dispose();
}
