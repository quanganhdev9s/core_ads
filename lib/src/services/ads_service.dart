import 'package:flutter/widgets.dart';

import '../core/config/ad_placement.dart';
import '../core/config/ads_config.dart';
import '../core/results/ad_result.dart';

/// SDK-facing contract implemented by concrete ad network services.
abstract interface class AdsService {
  /// Initializes the ad network SDK.
  Future<AdResult<void>> initialize(AdsConfig config);

  /// Loads an ad for [placement].
  Future<AdResult<void>> load(AdPlacement placement);

  /// Shows an ad for [placement].
  Future<AdResult<void>> show(AdPlacement placement);

  /// Shows a rewarded ad and calls [onRewardEarned] only when the SDK confirms
  /// the reward.
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  });

  /// Builds a banner widget for [placement].
  Widget banner(AdPlacement placement);

  /// Disposes resources owned by this service.
  Future<void> dispose();
}
