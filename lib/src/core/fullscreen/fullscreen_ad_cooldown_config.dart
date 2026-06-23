/// Cooldown rules for fullscreen ads.
class FullscreenAdCooldownConfig {
  /// Creates fullscreen ad cooldown configuration.
  const FullscreenAdCooldownConfig({
    this.interstitialInterval = const Duration(seconds: 7),
    this.appOpenInterval = const Duration(seconds: 7),
    this.interstitialAppOpenInterval = const Duration(seconds: 7),
  });

  /// Minimum duration between two interstitial ads.
  final Duration interstitialInterval;

  /// Minimum duration between two app open ads.
  final Duration appOpenInterval;

  /// Minimum duration between interstitial and app open ads.
  final Duration interstitialAppOpenInterval;
}
