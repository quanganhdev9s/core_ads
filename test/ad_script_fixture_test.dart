import 'dart:io';

import 'package:core_ads/core_ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the full example JSON selects the expected ad branches', () async {
    final source = await File(
      'example/assets/ad_script_demo.json',
    ).readAsString();
    final script = AdScript.parse(source);
    final scenarios = AdScenarioCoordinator(
      script: script,
      resolveAdUnitIds: (name, type) => ['test-$name'],
    );

    List<String> branches(String key) =>
        scenarios.resolve(key).steps.map((step) => step.branch).toList();

    expect(script.placements.length, 13);
    expect(script.settings.adsEnable, 2);
    expect(script.settings.onResume, 2);
    expect(
      script.settings.interDelayTime!.interval,
      const Duration(seconds: 10),
    );
    expect(script.settings.interDelayTime!.ignoredScenarioKeys, {
      'ads_splash',
      'inter_language',
      'inter_intro',
    });
    expect(branches('native_splash'), ['native']);
    expect(branches('ads_splash'), ['inter', 'native_inter']);
    expect(branches('native_language'), ['native_language1']);
    expect(branches('native_language_small'), ['native']);
    expect(branches('inter_language'), ['inter', 'native_inter']);
    expect(branches('native_intro'), ['native_intro2', 'native_intro4']);
    expect(branches('native_intro_full'), ['native']);
    expect(branches('inter_intro'), ['inter']);
    expect(branches('inter_welcome_back'), ['inter', 'native_inter']);
    expect(branches('native_welcome_back'), ['native']);
    expect(branches('native_get_start'), ['native_get_start2']);
    expect(branches('inter_start'), ['inter', 'native_inter']);
    expect(branches('banner_home'), ['native', 'native_small']);

    final home = scenarios.resolve('banner_home');
    expect(home.native!.placement.nativeFactoryId, 'Big4');
    expect(home.native!.ids, ['test-NATIVE_HOME']);
    expect(home.banner, isNull);
    expect(home.inlineMode, AdInlineMode.collapsibleNative);
    expect(home.collapsedNative!.placement.nativeFactoryId, 'Small1');
    expect(home.collapsedNative!.ids, ['test-NATIVE_HOME']);
    expect(home.native!.collapseClickCounts, isEmpty);
    expect(
      scenarios.resolve('ads_splash').native!.waitTime,
      const Duration(milliseconds: 5000),
    );
    expect(scenarios.buildAdUnitIds().typedValues.length, 19);
  });

  test(
    'spreadsheet JSON fixtures resolve registered native factories',
    () async {
      const files = [
        'example/assets/Ad Script version 100 A.json',
        'example/assets/Core Ads Test B - AOA Banner2.json',
        'example/assets/Core Ads Test C - Inter Banner3.json',
      ];
      final scenarios = <AdScenarioCoordinator>[];
      for (final file in files) {
        final source = await File(file).readAsString();
        final script = AdScript.parse(source);
        expect(script.placements.length, 27, reason: file);
        scenarios.add(
          AdScenarioCoordinator(
            script: script,
            resolveAdUnitIds: (name, type) => ['test-$name'],
          ),
        );
      }

      List<String> branches(AdScenarioCoordinator scenario, String key) =>
          scenario.resolve(key).steps.map((step) => step.branch).toList();

      final a = scenarios[0];
      expect(branches(a, 'ads_splash'), ['inter', 'native_inter']);
      expect(branches(a, 'native_language'), isEmpty);
      expect(a.script['native_language']!.enable, 0);
      expect(branches(a, 'banner_home'), ['native', 'native_small']);
      expect(
        a.resolve('native_result').collapsedNative?.placement.nativeFactoryId,
        'Collap1Collapsed',
      );
      expect(a.resolve('inter_home').interstitial?.stepCount, 2);

      final b = scenarios[1];
      expect(branches(b, 'ads_splash'), ['app_open']);
      expect(branches(b, 'banner_home'), ['native', 'banner_collap']);
      expect(
        b.resolve('native_result').collapsedNative?.placement.nativeFactoryId,
        'Collap3Collapsed',
      );
      expect(
        b.resolve('native_icon_setup').native?.placement.nativeFactoryId,
        'Card1',
      );

      final c = scenarios[2];
      expect(branches(c, 'ads_splash'), ['inter']);
      expect(branches(c, 'banner_home'), ['native']);
      expect(branches(c, 'native_language'), isEmpty);
      expect(c.resolve('on_resume').resumeMode, isNull);
      expect(
        c.resolve('inter_back').native?.placement.nativeFactoryId,
        'Full5',
      );

      final factories = <String>{
        for (final scenario in scenarios)
          for (final key in scenario.script.placements.keys)
            for (final step in scenario.resolve(key).steps)
              if (step.placement.type == AdType.native)
                step.placement.nativeFactoryId!,
      };
      expect(factories, containsAll(['LanguageStart1', 'LanguageStart2']));
      expect(
        factories.difference({
          for (final type in NativeAdType.values) type.factoryId,
        }),
        isEmpty,
      );
    },
  );
}
