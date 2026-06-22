import '../../core/config/ad_placement.dart';
import '../../core/results/ad_result.dart';

/// Public domain contract for ads operations.
abstract interface class AdsRepository {
  /// Initializes the underlying ads implementation.
  Future<AdResult<void>> initialize();

  /// Loads an ad for [placement].
  Future<AdResult<void>> load(AdPlacement placement);

  /// Shows an interstitial ad when one is ready.
  Future<AdResult<void>> showInterstitial(AdPlacement placement);

  /// Shows a rewarded ad and completes after the reward flow finishes.
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  });

  /// Shows an app open ad when one is ready and valid.
  Future<AdResult<void>> showAppOpen(AdPlacement placement);

  /// Disposes all managed ads resources.
  Future<void> dispose();
}
