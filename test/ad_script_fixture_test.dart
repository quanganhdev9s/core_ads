import 'package:core_ads/core_ads.dart';
import 'package:flutter_test/flutter_test.dart';

// Test the same config v2 string that the example starts with.
// ignore: avoid_relative_lib_imports
import '../example/lib/ads/demo_ad_config.dart';

void main() {
  test('the official example config resolves both v2 scenarios', () {
    for (final audience in [
      const AdScriptAudience(),
      const AdScriptAudience(isMarketingUser: true),
    ]) {
      final script = AdScript.parse(
        demoAdConfigJson,
        audience: audience,
        useTestIds: true,
      );
      final scenarios = AdScenarioCoordinator(
        script: script,
        resolveAdUnitIds: (name, type) => ['test-$name'],
      );
      expect(script.scenario, isNotNull);
      expect(scenarios.resolve('ads_splash').isEnabled, isTrue);
      expect(scenarios.resolve('banner_home').isEnabled, isTrue);
      expect(scenarios.buildAdUnitIds().typedValues, isNotEmpty);
    }
  });
}
