import 'package:core_ads/core_ads.dart';
import 'package:flutter/services.dart';

import 'example_ad_unit_ids.dart';

enum DemoScriptFixture {
  scriptA('100 A · Inter + native', 'assets/Ad Script version 100 A.json'),
  scriptB(
    'Test B · AOA + banner collapse',
    'assets/Core Ads Test B - AOA Banner2.json',
  ),
  scriptC(
    'Test C · Inter + native banner',
    'assets/Core Ads Test C - Inter Banner3.json',
  );

  const DemoScriptFixture(this.label, this.assetPath);

  final String label;
  final String assetPath;
}

/// Loads the JSON exported from the three spreadsheet test tabs.
/// Replace [loadFixture] with Firebase Remote Config in a real app.
abstract final class ScriptedDemoAds {
  static Future<AdScenarioController> loadFixture([
    DemoScriptFixture fixture = DemoScriptFixture.scriptA,
  ]) async {
    final json = await rootBundle.loadString(fixture.assetPath);
    return fromJson(json);
  }

  static AdScenarioController fromJson(String json) {
    return AdScenarioController(
      initialScript: AdScript.parse(json),
      resolveAdUnitIds: (name, type) => [
        switch (type) {
          AdType.appOpen => ExampleAdUnitIds.appOpen,
          AdType.interstitial => ExampleAdUnitIds.interstitial,
          AdType.native => ExampleAdUnitIds.native,
          AdType.banner => ExampleAdUnitIds.banner,
          AdType.rewarded => ExampleAdUnitIds.rewarded,
          AdType.rewardedInterstitial => ExampleAdUnitIds.rewardedInterstitial,
        },
      ],
      buildAdsConfig: (ids) => AdsConfig(
        environment: AdsEnvironment.test,
        adUnitIds: ids,
        consent: const AdsConsentConfig(enabled: false),
        enableDebugLogs: true,
      ),
    );
  }
}
