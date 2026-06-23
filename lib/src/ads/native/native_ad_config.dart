import '../../core/config/ad_placement.dart';

/// Native ad rendering configuration for one placement.
class NativeAdConfig {
  /// Creates native ad configuration.
  const NativeAdConfig({
    required this.factoryId,
    this.width = double.infinity,
    this.height = 120,
    this.customOptions,
  });

  /// Platform factory ID registered by the host app.
  final String factoryId;

  /// Width used by the default native ad widget container.
  final double width;

  /// Height used by the default native ad widget container.
  final double height;

  /// Optional custom values passed to the native ad factory.
  final Map<String, Object>? customOptions;
}

/// Native ad configuration grouped by placement.
class NativeAdConfigs {
  /// Creates native ad configurations.
  const NativeAdConfigs(this.values);

  /// Placement-to-native-config values.
  final Map<AdPlacement, NativeAdConfig> values;

  /// Returns native config for [placement].
  NativeAdConfig? configFor(AdPlacement placement) => values[placement];
}
