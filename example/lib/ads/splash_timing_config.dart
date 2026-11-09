import 'package:core_ads/core_ads.dart';

/// Quy tắc chờ trên màn Splash do app quyết định từ Remote Config.
final class SplashTimingConfig {
  const SplashTimingConfig({required this.minimum, required this.maximum});

  final Duration minimum;
  final Duration maximum;

  factory SplashTimingConfig.fromSettings(AdScriptSettings settings) {
    final minimumMs = _milliseconds(settings['splash_min_ms']) ?? 3000;
    final maximumMs = _milliseconds(settings['splash_max_ms']) ?? 8000;
    return SplashTimingConfig(
      minimum: Duration(milliseconds: minimumMs),
      maximum: Duration(
        milliseconds: maximumMs < minimumMs ? minimumMs : maximumMs,
      ),
    );
  }

  static int? _milliseconds(Object? value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    final integer = value.toInt();
    return integer == value ? integer : null;
  }
}
