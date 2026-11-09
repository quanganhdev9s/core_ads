import 'package:core_ads/core_ads.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/ads/splash_timing_config.dart';

void main() {
  AdScriptSettings settings(String fields) => AdScript.parse(
    '{"ad_settings":{$fields},"ad_placements":{"full":{}}}',
  ).settings;

  test('app reads Splash timing from remote settings', () {
    final timing = SplashTimingConfig.fromSettings(
      settings('"splash_min_ms":3000,"splash_max_ms":8000'),
    );
    expect(timing.minimum, const Duration(seconds: 3));
    expect(timing.maximum, const Duration(seconds: 8));
  });

  test('invalid or missing Splash timing uses app defaults', () {
    final defaults = SplashTimingConfig.fromSettings(settings(''));
    expect(defaults.minimum, const Duration(seconds: 3));
    expect(defaults.maximum, const Duration(seconds: 8));

    final invalid = SplashTimingConfig.fromSettings(
      settings('"splash_min_ms":-1,"splash_max_ms":"late"'),
    );
    expect(invalid.minimum, defaults.minimum);
    expect(invalid.maximum, defaults.maximum);
  });

  test('maximum is never earlier than minimum', () {
    final timing = SplashTimingConfig.fromSettings(
      settings('"splash_min_ms":9000,"splash_max_ms":8000'),
    );
    expect(timing.maximum, timing.minimum);
  });
}
