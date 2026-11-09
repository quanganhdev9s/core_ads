import 'package:core_ads/core_ads.dart';
import 'package:flutter_test/flutter_test.dart';

// Test uses the same inline JSON string as the example app.
// ignore: avoid_relative_lib_imports
import '../example/lib/ads/demo_ad_config.dart';

void main() {
  const json = demoAdConfigJson;

  AdScenarioCoordinator coordinator(AdScript script) => AdScenarioCoordinator(
    script: script,
    resolveAdUnitIds: (name, type) => ['test-$name'],
  );

  test('key groups allow their supported formats', () {
    final allowed = <AdConfigType, Set<AdConfigFormat>>{
      AdConfigType.splash: {
        AdConfigFormat.aoa,
        AdConfigFormat.inter,
        AdConfigFormat.interThenNativeFull,
      },
      AdConfigType.inter: {
        AdConfigFormat.inter,
        AdConfigFormat.nativeFull,
        AdConfigFormat.interThenNativeFull,
      },
      AdConfigType.banner: {
        AdConfigFormat.banner,
        AdConfigFormat.bannerCollapsible,
        AdConfigFormat.native,
        AdConfigFormat.nativeCollapsible,
      },
      AdConfigType.resume: {AdConfigFormat.aoa, AdConfigFormat.welcomeBack},
      AdConfigType.native: {},
      AdConfigType.reward: {},
      AdConfigType.rewardInter: {},
    };
    for (final type in AdConfigType.values) {
      for (final format in AdConfigFormat.values) {
        expect(type.allows(format), allowed[type]!.contains(format));
      }
    }
  });

  test('reward types resolve to their own ad formats in full and basic', () {
    for (final audience in [
      const AdScriptAudience(),
      const AdScriptAudience(isMarketingUser: true),
    ]) {
      final scenarios = coordinator(
        AdScript.parse(json, audience: audience, useTestIds: true),
      );
      final reward = scenarios.resolve('reward_test').steps.single;
      expect(reward.branch, 'reward');
      expect(reward.placement.type, AdType.rewarded);
      expect(reward.placement.key, 'reward_test.reward');
      expect(reward.ids, ['test-reward_test']);

      final rewardInter = scenarios.resolve('reward_inter_test').steps.single;
      expect(rewardInter.branch, 'reward_inter');
      expect(rewardInter.placement.type, AdType.rewardedInterstitial);
      expect(rewardInter.placement.key, 'reward_inter_test.reward_inter');
      expect(rewardInter.ids, ['test-reward_inter_test']);
    }
  });

  test('reward types reject format and keep later placements', () {
    const source = '''{
      "ad_settings":{"ads_profile":1},
      "ad_placements":{"full":{
        "reward_bad":{"format":"inter","enable":true},
        "reward_inter_good":{"enable":true}
      }}
    }''';
    final scenarios = coordinator(AdScript.parse(source, useTestIds: true));
    expect(scenarios.resolve('reward_bad').isEnabled, isFalse);
    expect(
      scenarios.resolve('reward_inter_good').steps.single.placement.type,
      AdType.rewardedInterstitial,
    );
  });

  test('key prefix and presence replace the old placement defaults', () {
    const source = '''{
      "ad_settings":{"ads_profile":2},
      "ad_placements":{
        "full":{
          "banner_home":{"format":"native_collapsible"},
          "reward_inter_bonus":{},
          "unknown_bonus":{}
        },
        "basic":{"banner_home":{"format":"banner"}}
      }
    }''';
    final fullScript = AdScript.parse(
      source,
      audience: const AdScriptAudience(isMarketingUser: true),
      useTestIds: true,
    );
    final full = coordinator(fullScript);
    expect(fullScript['ads_splash'], isNull);
    expect(
      full.resolve('banner_home').inlineMode,
      AdInlineMode.collapsibleNative,
    );
    expect(
      full.resolve('reward_inter_bonus').steps.single.placement.type,
      AdType.rewardedInterstitial,
    );
    expect(full.resolve('unknown_bonus').isEnabled, isFalse);

    final basicScript = AdScript.parse(source, useTestIds: true);
    final basic = coordinator(basicScript);
    expect(basic.resolve('banner_home').inlineMode, AdInlineMode.banner);
    expect(basicScript['reward_inter_bonus'], isNull);
  });

  test('language placements select separate native ad units', () {
    const source = '''{
      "ad_settings":{"ads_profile":1},
      "ad_placements":{"full":{
        "native_language":{"enable":true},
        "native_language_2":{"enable":true,"template":"LanguageStart2"},
        "native_get_start":{"enable":true}
      }}
    }''';
    final scenarios = coordinator(AdScript.parse(source, useTestIds: true));
    expect(scenarios.resolve('native_language').native!.branch, 'native');
    expect(
      scenarios.resolve('native_language').native!.placement.nativeFactoryId,
      'Big1',
    );
    expect(
      scenarios.resolve('native_language_2').native!.placement.nativeFactoryId,
      'LanguageStart2',
    );
    expect(
      scenarios.resolve('native_language_2').native!.placement.key,
      'native_language_2.native',
    );
    expect(scenarios.resolve('native_get_start').native!.branch, 'native');
    expect(
      scenarios.resolve('native_get_start').native!.placement.nativeFactoryId,
      'Big1',
    );
  });

  test(
    'custom style accepts every color and dimension in the templates tab',
    () {
      final values = <String, Object?>{
        'cta_bg': '#112233',
        'cta_text': '#AA112233',
        'card_bg': '#223344',
        'card_stroke': '#334455',
        'title_color': '#445566',
        'body_color': '#556677',
        'cta_corner_dp': 100,
        'card_corner_dp': 12,
        'card_stroke_dp': 2,
        'cta_height_dp': 52,
        'cta_text_sp': 15,
        'title_text_sp': 17,
        'body_text_sp': 13,
        'media_height_dp': 160,
        'icon_size_dp': 64,
        'card_padding_dp': 16,
      };
      expect(NativeAdStyle.fromJson(values)!.values, values);
    },
  );

  test(
    'profile 2 sends natural users to basic and marketing users to full',
    () {
      final basic = coordinator(AdScript.parse(json, useTestIds: true));
      expect(basic.script.scenario, AdScriptScenario.basic);
      expect(basic.resolve('ads_splash').steps.single.branch, 'app_open');
      expect(basic.resolve('banner_home').inlineMode, AdInlineMode.banner);
      expect(basic.resolve('inter_home').interstitial, isNotNull);
      expect(basic.resolve('inter_language').steps, isEmpty);
      expect(basic.resolve('inter_language_fallback').interstitial, isNotNull);
      expect(basic.resolve('native_splash').steps, isEmpty);
      expect(basic.resolve('banner_setting').inlineMode, AdInlineMode.banner);
      expect(
        basic.script.settings.gapFor(basic.script.scenario).interval,
        const Duration(seconds: 90),
      );

      final full = coordinator(
        AdScript.parse(
          json,
          audience: const AdScriptAudience(isMarketingUser: true),
          useTestIds: true,
        ),
      );
      expect(full.script.scenario, AdScriptScenario.full);
      expect(full.resolve('ads_splash').steps.map((step) => step.branch), [
        'inter',
        'native_inter',
      ]);
      expect(
        full.resolve('native_splash').native!.placement.nativeFactoryId,
        'Big5',
      );
      expect(
        full.resolve('native_splash').native!.placement.nativeStyle!.values,
        containsPair(NativeAdStyleKeys.ctaBackground, '#7B2FA6'),
      );
      expect(full.resolve('native_language').native!.branch, 'native');
      expect(
        full.resolve('native_language').native!.placement.nativeFactoryId,
        'LanguageStart1',
      );
      expect(
        full.resolve('native_setting').native!.placement.nativeFactoryId,
        'Big2',
      );
      expect(
        full
            .resolve('native_setting')
            .native!
            .placement
            .nativeStyle!
            .values[NativeAdStyleKeys.ctaBackground],
        '#FFC107',
      );
      expect(full.resolve('native_get_start').native!.branch, 'native');
      expect(
        full.resolve('native_get_start').native!.placement.nativeFactoryId,
        'LanguageStart1',
      );
      expect(full.resolve('native_onboarding').nativeForIntro(2), isNotNull);
      expect(full.resolve('native_onboarding').nativeForIntro(3), isNull);
      expect(full.script['native_full_onboarding']!.pages, {2});
      expect(
        full.resolve('on_resume').native!.placement.nativeFactoryId,
        'Big5',
      );
      expect(
        full.resolve('banner_home').inlineMode,
        AdInlineMode.collapsibleNative,
      );
      expect(full.resolve('banner_home').native!.collapseClickCounts, {2, 4});
      expect(
        full.script.settings.gapFor(full.script.scenario).interval,
        const Duration(seconds: 10),
      );
    },
  );

  test('sample JSON exposes every key group and format', () {
    final full = coordinator(
      AdScript.parse(
        json,
        audience: const AdScriptAudience(isMarketingUser: true),
        useTestIds: true,
      ),
    );
    final basic = coordinator(AdScript.parse(json, useTestIds: true));
    final covered = <String>{};
    for (final scenarios in [full, basic]) {
      for (final key in scenarios.script.placements.keys) {
        final plan = scenarios.resolve(key);
        if (plan.isEnabled && plan.configType != null && plan.format != null) {
          covered.add('${plan.configType!.key}/${plan.format!.key}');
        }
      }
    }
    expect(covered, {
      for (final type in AdConfigType.values)
        for (final format in AdConfigFormat.values)
          if (type.allows(format)) '${type.key}/${format.key}',
    });
    for (final key in [
      'ads_test_aoa',
      'ads_test_inter',
      'inter_test_native_full',
      'banner_test_collapsible',
      'banner_test_native_banner',
      'banner_test_native_banner_collapsible',
      'banner_test_native',
      'native_test_collap',
    ]) {
      expect(full.resolve(key).steps, isNotEmpty, reason: key);
    }
    expect(full.resolve('native_test_disabled').isEnabled, isFalse);
    expect(basic.resolve('native_test_disabled').isEnabled, isFalse);
    expect(
      basic.resolve('native_setting').native!.placement.nativeFactoryId,
      'Big2',
    );
    expect(
      basic.resolve('native_setting').native!.placement.nativeStyle!.values,
      containsPair('cta_bg', '#FFC107'),
    );
    expect(
      full.resolve('native_test_collap').inlineMode,
      AdInlineMode.collapsibleNative,
    );
    expect(
      full.resolve('banner_test_collapsible').inlineMode,
      AdInlineMode.adMobCollapsibleBanner,
    );
  });

  test('premium disables all ads and external pages override embedded pages', () {
    final off = coordinator(
      AdScript.parse(json, audience: const AdScriptAudience(isPremium: true)),
    );
    expect(off.script.scenario, AdScriptScenario.off);
    expect(off.resolve('ads_splash').steps, isEmpty);
    final full = coordinator(
      AdScript.parse(
        json,
        audience: const AdScriptAudience(isMarketingUser: true),
        pagesJson:
            '{"native_language":2,"native_onboarding":[1,3],"native_full_onboarding":[3]}',
        useTestIds: true,
      ),
    );
    expect(full.resolve('native_language').native!.branch, 'native');
    expect(full.resolve('native_onboarding').nativeForIntro(3), isNotNull);
    expect(full.resolve('native_onboarding').nativeForIntro(2), isNull);
    expect(full.script['native_full_onboarding']!.pages, {3});
  });

  test('Collap template keeps one native placement for both layouts', () {
    const source = '''{
      "ad_settings":{"ads_profile":1},
      "ad_placements":{"full":{
        "native_home_feed":{"template":"Collap1Expanded"}
      }},
      "ad_ids":{"native_home_feed":["native-test-id"]}
    }''';
    final plan = coordinator(
      AdScript.parse(source),
    ).resolve('native_home_feed');
    expect(plan.inlineMode, AdInlineMode.collapsibleNative);
    expect(plan.steps.map((step) => step.branch), ['native']);
    expect(plan.native!.placement.nativeFactoryId, 'Collap1Expanded');
    expect(plan.native!.ids, ['native-test-id']);
    expect(
      NativeAdTemplate.forFactory(
        plan.native!.placement.nativeFactoryId,
      ).collapsedFactoryId,
      'Collap1Collapsed',
    );
  });

  test('banner key format selects its native unit', () {
    const source = '''{
      "ad_settings":{"ads_profile":1},
      "ad_placements":{"full":{
        "banner_setting":{"format":"welcome_back"},
        "banner_home":{"format":"native_collapsible","template":"Collap1"},
        "banner_offer":{"format":"banner_collapsible","enable":true}
      }},
      "ad_ids":{
        "native_collap_home":["native-home-id"],
        "banner_offer":["banner-offer-id"]
      }
    }''';
    final scenarios = coordinator(AdScript.parse(source));
    expect(scenarios.resolve('banner_setting').isEnabled, isFalse);
    final home = scenarios.resolve('banner_home');
    expect(home.configType, AdConfigType.banner);
    expect(home.format, AdConfigFormat.nativeCollapsible);
    expect(home.inlineMode, AdInlineMode.collapsibleNative);
    expect(home.steps.single.branch, 'native_collap');
    expect(home.native!.ids, ['native-home-id']);
    expect(home.native!.placement.nativeFactoryId, 'Collap1Expanded');
    final offer = scenarios.resolve('banner_offer');
    expect(offer.inlineMode, AdInlineMode.adMobCollapsibleBanner);
    expect(offer.banner!.ids, ['banner-offer-id']);
  });

  test('custom template resolves its base and rejects an unknown name', () {
    const source = '''{
      "ad_settings":{"ads_profile":1},
      "ad_placements":{"full":{
        "native_splash":{"template":"dark_card","enable":true},
        "native_home_feed":{"template":"missing","enable":true}
      }},
      "ad_ids":{"native_splash":["native-id"],"native_home_feed":["feed-id"]},
      "ad_templates":{"dark_card":{"base":"Big1","card_bg":"#1E1E1E"}}
    }''';
    final scenarios = coordinator(AdScript.parse(source));
    expect(
      scenarios.resolve('native_splash').native!.placement.nativeFactoryId,
      'Big1',
    );
    expect(
      scenarios.resolve('native_splash').native!.placement.nativeStyle!.values,
      containsPair('card_bg', '#1E1E1E'),
    );
    expect(scenarios.resolve('native_home_feed').isEnabled, isFalse);
  });

  test('an invalid placement does not remove later placements', () {
    const source = '''{
      "ad_settings":{"ads_profile":1},
      "ad_placements":{"full":{
        "native_bad":{"template":"unknown","enable":true},
        "native_good":{"template":"Big2","enable":true}
      }}
    }''';
    final scenarios = coordinator(AdScript.parse(source, useTestIds: true));
    expect(scenarios.resolve('native_bad').isEnabled, isFalse);
    expect(
      scenarios.resolve('native_good').native!.placement.nativeFactoryId,
      'Big2',
    );
  });

  test(
    'dynamic names and built-in overrides follow the placement template',
    () {
      const source = '''{
      "ad_settings":{"ads_profile":1},
      "pages":{"native_language":2},
      "ad_placements":{"full":{
        "ads_splash":{"format":"inter_then_native_full"},
        "native_splash":{"template":"Big2","enable":true},
        "native_home_feed":{"template":"dusk_card","enable":true},
        "banner_home":{"format":"native_collapsible","enable":true},
        "native_language":{"enable":true,"template":"LanguageStart2"}
      }},
      "ad_templates":{
        "Big2":{"base":"Big2","cta_bg":"#112233"},
        "dusk_card":{"base":"Big2","body_color":"#AABBCC"},
        "Collap1":{"card_bg":"#223344"},
        "LanguageStart2":{"cta_bg":"#334455"},
        "Full1":{"title_color":"#445566"}
      }
    }''';
      final scenarios = coordinator(AdScript.parse(source, useTestIds: true));
      final splash = scenarios.resolve('native_splash').native!.placement;
      expect(splash.nativeFactoryId, 'Big2');
      expect(
        splash.nativeStyle!.values[NativeAdStyleKeys.ctaBackground],
        '#112233',
      );

      final custom = scenarios.resolve('native_home_feed').native!.placement;
      expect(custom.nativeFactoryId, 'Big2');
      expect(custom.nativeStyle!.values, {
        NativeAdStyleKeys.ctaBackground: '#112233',
        NativeAdStyleKeys.bodyColor: '#AABBCC',
      });

      final banner = scenarios.resolve('banner_home').native!.placement;
      expect(banner.nativeFactoryId, 'Collap1Expanded');
      expect(
        banner.nativeStyle!.values[NativeAdStyleKeys.cardBackground],
        '#223344',
      );

      final language = scenarios.resolve('native_language').native!.placement;
      expect(language.nativeFactoryId, 'LanguageStart2');
      expect(
        language.nativeStyle!.values[NativeAdStyleKeys.ctaBackground],
        '#334455',
      );

      final full = scenarios.resolve('ads_splash').native!.placement;
      expect(full.nativeFactoryId, 'Full1');
      expect(full.nativeStyle!.values[NativeAdStyleKeys.titleColor], '#445566');
    },
  );

  test(
    'custom template inherits base fields, ignores invalid values and clamps numbers',
    () {
      const source = '''{
      "ad_settings":{"ads_profile":1},
      "ad_placements":{"full":{
        "native_splash":{"template":"child","enable":true}
      }},
      "ad_ids":{"native_splash":["native-id"]},
      "ad_templates":{
        "parent":{"base":"Big5","cta_bg":"#112233","card_bg":"#FFEEDD","title_color":"#123456"},
        "child":{"base":"parent","cta_bg":"#445566","card_bg":"invalid","title_color":"","cta_height_dp":52,"icon_size_dp":500,"cta_corner_dp":-9}
      }
    }''';
      final placement = coordinator(
        AdScript.parse(source),
      ).resolve('native_splash').native!.placement;
      expect(placement.nativeFactoryId, 'Big5');
      expect(placement.nativeStyle!.values, {
        'cta_bg': '#445566',
        'card_bg': '#FFEEDD',
        'title_color': '#123456',
        'cta_height_dp': 52,
        'icon_size_dp': 96,
        'cta_corner_dp': 0,
      });
    },
  );

  test('profile 3 uses basic on test devices; boolean enable only toggles', () {
    const source = '''{
      "ad_settings":{"ads_profile":3},
      "ad_placements":{
        "full":{"ads_splash":{"enable":false}},
        "basic":{"ads_splash":{"enable":true,"format":"aoa"}}
      },
      "ad_ids":{"aoa_splash":["first","second"]}
    }''';
    final regular = coordinator(AdScript.parse(source));
    expect(regular.script.scenario, AdScriptScenario.full);
    expect(regular.resolve('ads_splash').steps, isEmpty);
    final testDevice = coordinator(
      AdScript.parse(
        source,
        audience: const AdScriptAudience(isTestAdDevice: true),
      ),
    );
    expect(testDevice.script.scenario, AdScriptScenario.basic);
    expect(testDevice.resolve('ads_splash').steps.single.ids, [
      'first',
      'second',
    ]);
  });
}
