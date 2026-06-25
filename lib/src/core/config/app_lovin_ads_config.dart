/// AppLovin MAX specific runtime configuration.
class AppLovinAdsConfig {
  /// Creates AppLovin MAX configuration.
  const AppLovinAdsConfig({
    required this.sdkKey,
    this.enableVerboseLogging = false,
  });

  /// AppLovin MAX SDK key from the AppLovin dashboard.
  final String sdkKey;

  /// Whether AppLovin verbose logging should be enabled.
  final bool enableVerboseLogging;
}
