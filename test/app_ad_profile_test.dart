import 'package:core_ads/core_ads.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/ads/app_ad_profile.dart';

void main() {
  String config(int profile) =>
      '{"ad_settings":{"ads_profile":$profile},"ad_placements":{"full":{},"basic":{}}}';

  test('app selects the scenario for each ads_profile value', () {
    AdScriptScenario select(
      int profile, {
      bool marketing = false,
      bool testDevice = false,
      bool premium = false,
    }) => selectAppAdScenario(
      config(profile),
      isMarketingUser: marketing,
      isTestAdDevice: testDevice,
      isPremium: premium,
    );

    expect(select(0), AdScriptScenario.off);
    expect(select(1), AdScriptScenario.full);
    expect(select(2), AdScriptScenario.basic);
    expect(select(2, marketing: true), AdScriptScenario.full);
    expect(select(3), AdScriptScenario.full);
    expect(select(3, testDevice: true), AdScriptScenario.basic);
    expect(select(1, premium: true), AdScriptScenario.off);
  });

  test('app rejects unsupported ads_profile values', () {
    expect(
      () => selectAppAdScenario(
        config(4),
        isMarketingUser: false,
        isTestAdDevice: false,
        isPremium: false,
      ),
      throwsFormatException,
    );
  });
}
