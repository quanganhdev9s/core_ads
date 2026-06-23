import 'package:flutter/widgets.dart';

import '../core/config/ad_placement.dart';
import '../core/config/ads_config.dart';
import '../core/enums/ad_type.dart';
import '../core/results/ad_result.dart';
import '../ads/banner/banner_ad_config.dart';

/// SDK-facing contract implemented by concrete ad network services.
abstract interface class AdsService {
  /// Initializes the ad network SDK.
  Future<AdResult<void>> initialize(AdsConfig config);

  /// Loads an ad for [placement].
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  });

  /// Shows an ad for [placement].
  Future<AdResult<void>> show(AdPlacement placement);

  /// Shows a rewarded ad and calls [onRewardEarned] only when the SDK confirms
  /// the reward.
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  });

  /// Shows a rewarded interstitial ad and calls [onRewardEarned] only when the
  /// SDK confirms the reward.
  Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  });

  /// Builds a banner widget for [placement].
  Widget banner(AdPlacement placement);

  /// Builds a native ad widget for [placement].
  Widget nativeAd(AdPlacement placement);

  /// Clears cached ad resources for [placement].
  Future<void> clear(AdPlacement placement);

  /// Clears cached ad resources for all placements of [type].
  Future<void> clearType(AdType type);

  /// Disposes resources owned by this service.
  Future<void> dispose();
}
