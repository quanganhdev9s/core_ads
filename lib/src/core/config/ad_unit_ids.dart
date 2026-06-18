import '../enums/ad_type.dart';

/// Stores ad unit IDs for every supported ad format.
class AdUnitIds {
  /// Creates ad unit IDs grouped by ad format.
  const AdUnitIds({
    this.banner,
    this.interstitial,
    this.rewarded,
    this.rewardedInterstitial,
    this.native,
    this.appOpen,
  });

  /// Banner ad unit ID.
  final String? banner;

  /// Interstitial ad unit ID.
  final String? interstitial;

  /// Rewarded ad unit ID.
  final String? rewarded;

  /// Rewarded interstitial ad unit ID.
  final String? rewardedInterstitial;

  /// Native ad unit ID.
  final String? native;

  /// App open ad unit ID.
  final String? appOpen;

  /// Returns the ad unit ID for [type], or null when it is not configured.
  String? idFor(AdType type) {
    return switch (type) {
      AdType.banner => banner,
      AdType.interstitial => interstitial,
      AdType.rewarded => rewarded,
      AdType.rewardedInterstitial => rewardedInterstitial,
      AdType.native => native,
      AdType.appOpen => appOpen,
    };
  }
}
