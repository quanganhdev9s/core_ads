import '../../core/results/ad_result.dart';
import '../../core/enums/ad_type.dart';

/// Public domain contract for ads operations.
abstract interface class AdsRepository {
  /// Initializes the underlying ads implementation.
  Future<AdResult<void>> initialize();

  /// Loads an ad for [type].
  Future<AdResult<void>> load(AdType type);

  /// Shows an interstitial ad when one is ready.
  Future<AdResult<void>> showInterstitial();

  /// Shows a rewarded ad and completes after the reward flow finishes.
  Future<AdResult<void>> showRewarded({
    required void Function() onRewardEarned,
  });

  /// Shows an app open ad when one is ready and valid.
  Future<AdResult<void>> showAppOpen();

  /// Disposes all managed ads resources.
  Future<void> dispose();
}
