import 'package:flutter/widgets.dart';

import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_load_status.dart';
import '../../core/enums/ad_type.dart';
import '../../core/results/ad_result.dart';
import '../../ads/banner/banner_ad_config.dart';

/// Public domain contract for ads operations.
abstract interface class AdsRepository {
  /// Initializes the underlying ads implementation.
  Future<AdResult<void>> initialize();

  /// Loads an ad for [placement].
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  });

  /// Returns current load/cache status for [placement].
  AdLoadStatus loadStatusOf(AdPlacement placement);

  /// Builds a banner widget for [placement].
  Widget banner(AdPlacement placement);

  /// Builds a native ad widget for [placement].
  Widget nativeAd(AdPlacement placement);

  /// Shows an interstitial ad when one is ready.
  Future<AdResult<void>> showInterstitial(AdPlacement placement);

  /// Shows a rewarded ad and completes after the reward flow finishes.
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  });

  /// Shows a rewarded interstitial ad and completes after the reward flow finishes.
  Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  });

  /// Shows an app open ad when one is ready and valid.
  Future<AdResult<void>> showAppOpen(AdPlacement placement);

  /// Handles an app resume event for an app open ad placement.
  Future<AdResult<void>> handleAppResume(AdPlacement placement);

  /// Clears cached ad resources for [placement].
  Future<void> clear(AdPlacement placement);

  /// Clears cached ad resources for all placements of [type].
  Future<void> clearType(AdType type);

  /// Disposes all managed ads resources.
  Future<void> dispose();
}
