/// Cooldown rules for fullscreen ads.
class FullscreenAdCooldownConfig {
  /// Creates fullscreen ad cooldown configuration.
  const FullscreenAdCooldownConfig({
    this.interstitialInterval = const Duration(seconds: 7),
    this.appOpenInterval = const Duration(seconds: 7),
    this.interstitialAppOpenInterval = const Duration(seconds: 7),
    this.ignoredInterstitialPlacementKeys = const {},
  });

  /// Minimum duration between two interstitial ads.
  final Duration interstitialInterval;

  /// Concrete interstitial placement keys excluded from the inter-to-inter gap.
  /// They still participate in the interstitial-to-app-open gap.
  final Set<String> ignoredInterstitialPlacementKeys;

  /// Minimum duration between two app open ads.
  final Duration appOpenInterval;

  /// Minimum duration between interstitial and app open ads.
  final Duration interstitialAppOpenInterval;
}
