/// Configuration for controlling interstitial-like ad frequency.
class AdFrequencyConfig {
  /// Creates frequency rules for ads.
  const AdFrequencyConfig({
    this.showEveryActions = 1,
    this.cooldown = Duration.zero,
  }) : assert(showEveryActions > 0, 'showEveryActions must be greater than 0');

  /// Number of tracked actions required before an ad can be shown.
  final int showEveryActions;

  /// Minimum time between two allowed ad shows.
  final Duration cooldown;
}
