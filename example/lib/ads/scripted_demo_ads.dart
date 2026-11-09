import 'package:core_ads/core_ads.dart';

import 'demo_ad_config.dart';
import 'example_ad_unit_ids.dart';
import 'native_ui_preview_catalog.dart';

/// Config v2 là nguồn cấu hình duy nhất của example.
/// Khi tích hợp thật, thay [demoAdConfigJson] bằng JSON từ Remote Config.
abstract final class ScriptedDemoAds {
  static AdScenarioController loadConfig([
    AdScriptAudience audience = const AdScriptAudience(),
  ]) => fromJson(demoAdConfigJson, audience: audience);

  static AdScenarioController fromJson(
    String json, {
    AdScriptAudience audience = const AdScriptAudience(),
  }) {
    return AdScenarioController(
      initialScript: AdScript.parse(json, audience: audience, useTestIds: true),
      audience: audience,
      useTestIds: true,
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
        adUnitIds: NativeUiPreviewCatalog.withTestIds(ids),
        consent: const AdsConsentConfig(enabled: false),
        enableDebugLogs: true,
      ),
    );
  }
}
