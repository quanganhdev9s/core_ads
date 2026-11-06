import 'package:core_ads/core_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const json = '''
{
  "settings": {"ads_enable": 2},
  "inter_home": {
    "enable": 3, "refresh_rate": 2000,
    "inter": {"name1": "INTER_HOME"},
    "native_inter": {"name1": "NATIVE_INTER_HOME"}
  },
  "native_intro": {
    "enable": 24, "native_template": "Big4",
    "native_intro1": {"name1": "NATIVE_INTRO_1"},
    "native_intro2": {"name1": "NATIVE_INTRO_2"},
    "native_intro3": {"name1": "NATIVE_INTRO_3"},
    "native_intro4": {"name1": "NATIVE_INTRO_4"}
  },
  "banner_home": {
    "enable": 4, "collap_config": "24/26",
    "native": {"name1": "NATIVE_HOME"},
    "banner_collap": {"name1": "BANNER_HOME"}
  },
  "on_resume": {
    "enable": 2
  }
}
''';

  AdScenarioCoordinator coordinator() {
    return AdScenarioCoordinator(
      script: AdScript.parse(json),
      resolveAdUnitIds: (name, type) => ['$name.high', '$name.all'],
    );
  }

  test('inter and native remain separate with native-only refresh rate', () {
    final plan = coordinator().resolve('inter_home');
    expect(plan.steps.map((step) => step.placement.type), [
      AdType.interstitial,
      AdType.native,
    ]);
    expect(plan.interstitial!.refreshRate, isNull);
    expect(plan.native!.refreshRate, const Duration(milliseconds: 2000));
    expect(plan.native!.ids, [
      'NATIVE_INTER_HOME.high',
      'NATIVE_INTER_HOME.all',
    ]);
  });

  test('remote timing values use milliseconds without rounding', () {
    final script = AdScript.parse('''
{"settings": {}, "inter_home": {
  "enable": 2, "refresh_rate": 1250, "wait_time": 750,
  "native_inter": {"name1": "NATIVE_INTER_HOME"}
}}
''');
    final native = AdScenarioCoordinator(
      script: script,
      resolveAdUnitIds: (name, type) => [name],
    ).resolve('inter_home').native!;
    expect(native.refreshRate, const Duration(milliseconds: 1250));
    expect(native.waitTime, const Duration(milliseconds: 750));
  });

  test('inter_delay_time parses milliseconds and logical ignore keys', () {
    final settings = AdScript.parse('''
{"settings": {
  "inter_delay_time": "time=10000,ignore=ads_splash|inter_language|inter_intro"
}}
''').settings;
    expect(settings.interDelayTime!.interval, const Duration(seconds: 10));
    expect(settings.interDelayTime!.ignoredScenarioKeys, {
      'ads_splash',
      'inter_language',
      'inter_intro',
    });
    expect(
      AdScript.parse(
        '{"settings":{"inter_delay_time":"time=10"}}',
      ).settings.interDelayTime!.interval,
      const Duration(milliseconds: 10),
    );
  });

  test('ignores malformed inter_delay_time without disabling other ads', () {
    for (final value in [
      'time=-1',
      'time=1/2',
      'ignore=inter_home',
      'time=10,ignore=inter_home|',
      'time=10,time=20',
    ]) {
      final script = AdScript.parse('''
{"settings":{"inter_delay_time":"$value"},
 "native_result":{"enable":1,"native":{"name1":"NATIVE_RESULT"}}}
''');
      expect(script.settings.interDelayTime, isNull);
      expect(script['native_result']!.enable, 1);
    }
  });

  test('splash and banner enable values select their documented formats', () {
    final scenarios = AdScenarioCoordinator(
      script: AdScript.parse('''
{
  "settings": {},
  "ads_splash": {
    "enable": 3,
    "app_open": {"name1": "AOA_SPLASH"},
    "inter": {"name1": "INTER_SPLASH"},
    "native_inter": {"name1": "NATIVE_INTER_SPLASH"}
  },
  "banner_home": {
    "enable": 2, "collap_config": 2,
    "banner": {"name1": "BANNER_HOME"},
    "native": {"name1": "NATIVE_HOME"},
    "banner_collap": {"name1": "BANNER_COLLAP_HOME"}
  }
}
'''),
      resolveAdUnitIds: (name, type) => [name],
    );
    expect(scenarios.resolve('ads_splash').steps.map((step) => step.branch), [
      'inter',
      'native_inter',
    ]);
    expect(scenarios.resolve('banner_home').steps.map((step) => step.branch), [
      'native',
      'banner_collap',
    ]);
    expect(
      scenarios.resolve('banner_home').inlineMode,
      AdInlineMode.collapsibleBanner,
    );
    expect(scenarios.resolve('banner_home').native!.collapseClickCounts, {2});
    expect(
      scenarios.resolve('banner_home').banner!.placement.type,
      AdType.banner,
    );
  });

  test('intro 24 selects only screens 2 and 4', () {
    final plan = coordinator().resolve('native_intro');
    expect(plan.nativeForIntro(1), isNull);
    expect(plan.nativeForIntro(2)!.placement.nativeFactoryId, 'Big4');
    expect(plan.nativeForIntro(3), isNull);
    expect(plan.nativeForIntro(4), isNotNull);
  });

  test('native enable values outside supported cases become zero', () {
    for (final enable in [-1, 2, 10]) {
      final script = AdScript.parse('''
{"settings": {}, "native_result": {
  "enable": $enable, "native": {"name1": "NATIVE_RESULT"}
}}
''');
      expect(
        script['native_result']!.enable,
        0,
        reason: 'native_result: $enable',
      );
    }
    for (final enable in [5, 15, 11, 120]) {
      final script = AdScript.parse('''
{"settings": {}, "native_intro": {
  "enable": $enable,
  "native_intro1": {"name1": "INTRO_1"},
  "native_intro2": {"name1": "INTRO_2"},
  "native_intro3": {"name1": "INTRO_3"},
  "native_intro4": {"name1": "INTRO_4"},
  "native_intro5": {"name1": "INTRO_5"}
}}
''');
      expect(
        script['native_intro']!.enable,
        0,
        reason: 'native_intro: $enable',
      );
    }
    final oneIntroBranch = AdScript.parse('''
{"settings": {}, "native_intro": {
  "enable": 2, "native_intro2": {"name1": "INTRO_2"}
}}
''');
    expect(oneIntroBranch['native_intro']!.selectedBranches, ['native_intro2']);
  });

  test(
    'full onboarding uses enable as transition index and a Full factory',
    () {
      final scenarios = AdScenarioCoordinator(
        script: AdScript.parse('''
{"settings": {}, "${AdScenarioKeys.nativeFullOnboarding}": {
  "enable": 3, "native": {"name1": "NATIVE_FULL_ONBOARDING"}
}}
'''),
        resolveAdUnitIds: (name, type) => [name],
      );
      final plan = scenarios.resolve(AdScenarioKeys.nativeFullOnboarding);
      expect(plan.enable, 3);
      expect(plan.native!.branch, 'native');
      expect(plan.native!.placement.nativeFactoryId, 'Full1');

      for (final template in ['Big1', 'Unknown']) {
        final script = AdScript.parse('''
{"settings": {}, "${AdScenarioKeys.nativeFullOnboarding}": {
  "enable": 2, "native_template": "$template",
  "native": {"name1": "NATIVE_FULL_ONBOARDING"}
}}
''');
        expect(script[AdScenarioKeys.nativeFullOnboarding]!.enable, 0);
      }
      for (final enable in [-2, 0, 1]) {
        final script = AdScript.parse('''
{"settings": {}, "${AdScenarioKeys.nativeFullOnboarding}": {
  "enable": $enable, "native": {"name1": "NATIVE_FULL_ONBOARDING"}
}}
''');
        expect(
          script[AdScenarioKeys.nativeFullOnboarding]!.enable,
          enable < 0 ? 0 : enable,
        );
      }
    },
  );

  test('language and get start select their dedicated native factories', () {
    final scenarios = AdScenarioCoordinator(
      script: AdScript.parse('''
{"settings": {},
 "native_language": {"enable": 1,
   "native_language1": {"name1": "LANG_1"},
   "native_language2": {"name1": "LANG_2"}},
 "native_get_start": {"enable": 2, "native_template": "Big3",
   "native_get_start1": {"name1": "START_1"},
   "native_get_start2": {"name1": "START_2"}}}
'''),
      resolveAdUnitIds: (name, type) => [name],
    );
    expect(
      scenarios.resolve('native_language').native!.placement.nativeFactoryId,
      'LanguageStart1',
    );
    expect(
      scenarios.resolve('native_get_start').native!.placement.nativeFactoryId,
      'LanguageStart2',
    );
  });

  test('language and get start treat every other enable value as zero', () {
    for (final key in ['native_language', 'native_get_start']) {
      for (final enable in [-1, 3, 12, 21]) {
        final script = AdScript.parse('''
{"settings": {}, "$key": {"enable": $enable,
 "${key}1": {"name1": "NATIVE_1"},
 "${key}2": {"name1": "NATIVE_2"}}}
''');
        expect(script[key]!.enable, 0, reason: '$key: $enable');
        expect(script[key]!.selectedBranches, isEmpty);
      }
    }
  });

  test(
    'multiple native branches use enable digits; one native uses 0 or 1',
    () {
      final multiple = AdScenarioCoordinator(
        script: AdScript.parse('''
{"settings": {}, "native_intro": {
  "enable": 24,
  "native_intro1": {"name1": "NATIVE_INTRO_1"},
  "native_intro2": {"name1": "NATIVE_INTRO_2"},
  "native_intro3": {"name1": "NATIVE_INTRO_3"},
  "native_intro4": {"name1": "NATIVE_INTRO_4"}
}}
'''),
        resolveAdUnitIds: (name, type) => [name],
      );
      expect(
        multiple.resolve('native_intro').steps.map((step) => step.branch),
        ['native_intro2', 'native_intro4'],
      );
      expect(
        AdScript.parse('''
{"settings": {}, "native_language": {
  "enable": 0,
  "native_language1": {"name1": "NATIVE_LANGUAGE_1"},
  "native_language2": {"name1": "NATIVE_LANGUAGE_2"}
}}
''')['native_language']!.enable,
        0,
      );

      for (final enable in [0, 1]) {
        final single = AdScenarioCoordinator(
          script: AdScript.parse('''
{"settings": {}, "native_result": {
  "enable": $enable,
  "native": {"name1": "NATIVE_RESULT"}
}}
'''),
          resolveAdUnitIds: (name, type) => [name],
        );
        expect(
          single.resolve('native_result').steps.map((step) => step.branch),
          enable == 1 ? ['native'] : isEmpty,
        );
      }

      expect(
        AdScript.parse('''
{"settings": {}, "native_result": {
  "enable": 2, "native": {"name1": "NATIVE_RESULT"}
}}
''')['native_result']!.enable,
        0,
      );
      expect(
        AdScript.parse('''
{"settings": {}, "native_language": {
  "enable": 24,
  "native_language1": {"name1": "NATIVE_LANGUAGE_1"},
  "native_language2": {"name1": "NATIVE_LANGUAGE_2"}
}}
''')['native_language']!.enable,
        0,
      );
    },
  );

  test('slash-separated collapse taps remain distinct from intro digits', () {
    final active = coordinator().resolve('banner_home');
    expect(active.native!.collapseClickCounts, {24, 26});
    expect(active.inlineMode, AdInlineMode.collapsibleNative);
    expect(active.banner, isNull);
    expect(active.steps.map((step) => step.branch), ['native', 'native_small']);
    expect(active.native!.placement.nativeFactoryId, 'Big4');
    expect(active.collapsedNative!.placement.nativeFactoryId, 'Small1');
    expect(coordinator().script.settings.adsEnable, 2);
    expect(active.isEnabled, isTrue);
    expect(coordinator().resolve('inter_home').isEnabled, isTrue);
  });

  test('digit selection is limited to multi-native placements', () {
    final script = AdScript.parse('''
{"settings": {},
 "reward_home": {
   "enable": 24,
   "reward1": {"name1": "REWARD_1"},
   "reward2": {"name1": "REWARD_2"}
 },
 "reward_daily": {
   "enable": 1,
   "reward": {"name1": "REWARD_DAILY"}
 }}
''');
    final scenarios = AdScenarioCoordinator(
      script: script,
      resolveAdUnitIds: (name, type) => [name],
    );
    expect(scenarios.resolve('reward_home').isEnabled, isFalse);
    expect(scenarios.resolve('reward_daily').steps.single.branch, 'reward');
    expect(
      scenarios.resolve('reward_daily').steps.single.placement.type,
      AdType.rewarded,
    );
  });

  test('on_resume exposes its selected flow without an ad unit', () {
    final plan = coordinator().resolve('on_resume');
    expect(plan.isEnabled, isTrue);
    expect(plan.resumeMode, 2);
    expect(plan.steps, isEmpty);
  });

  test('on_resume can come from settings without a placement object', () {
    final scenarios = AdScenarioCoordinator(
      script: AdScript.parse('{"settings": {"on_resume": 2}}'),
      resolveAdUnitIds: (name, type) => const [],
    );
    expect(scenarios.resolve('on_resume').resumeMode, 2);
    expect(scenarios.resolve('on_resume').isEnabled, isTrue);
    expect(scenarios.buildAdUnitIds().values, isEmpty);
  });

  test('builds a waterfall from symbolic ad unit names', () {
    final current = coordinator();
    final native = current.resolve('inter_home').native!.placement;
    expect(current.buildAdUnitIds().idsFor(native), [
      'NATIVE_INTER_HOME.high',
      'NATIVE_INTER_HOME.all',
    ]);
  });

  test(
    'step_count counts logical show calls separately per inter placement',
    () async {
      final scenarios = AdScenarioCoordinator(
        script: AdScript.parse('''
{
  "settings": {},
  "inter_home": {
    "enable": 1, "step_count": 2,
    "inter": {"name1": "INTER_HOME"}
  },
  "inter_settings": {
    "enable": 1, "step_count": 3,
    "inter": {"name1": "INTER_SETTINGS"}
  }
}
'''),
        resolveAdUnitIds: (name, type) => [name],
      );

      String failureCode(AdResult<void> result) => switch (result) {
        AdFailed<void>(failure: final failure) => failure.code,
        AdSuccess<void>() => 'shown',
      };

      await scenarios.preload('inter_home');
      expect(
        failureCode(await scenarios.showInterstitial('inter_home')),
        'step_count_skipped',
      );
      expect(
        failureCode(await scenarios.showInterstitial('inter_settings')),
        'step_count_skipped',
      );
      expect(
        failureCode(await scenarios.showInterstitial('inter_home')),
        'not_ready',
      );
      expect(
        failureCode(await scenarios.showInterstitial('inter_settings')),
        'step_count_skipped',
      );
      expect(
        failureCode(await scenarios.showInterstitial('inter_settings')),
        'not_ready',
      );
      expect(
        failureCode(await scenarios.showInterstitial('inter_home')),
        'step_count_skipped',
      );
    },
  );

  test('disables native placement with repeated intro digits', () {
    expect(
      AdScript.parse('''
{"settings": {}, "native_intro": {
  "enable": 22,
  "native_intro1": {"name1": "NATIVE_INTRO_1"},
  "native_intro2": {"name1": "NATIVE_INTRO_2"},
  "native_intro3": {"name1": "NATIVE_INTRO_3"},
  "native_intro4": {"name1": "NATIVE_INTRO_4"}
}}
''')['native_intro']!.enable,
      0,
    );
  });

  test(
    'ordinary native ignores collap_config but keeps refresh and template',
    () {
      final script = AdScript.parse('''
{"settings": {}, "native_result": {
  "enable": 1, "refresh_rate": 20,
  "collap_config": "24/26", "native_template": "Small1",
  "native": {"name1": "NATIVE_RESULT"}
}}
''');
      expect(script['native_result']!.collapseClickCounts, isEmpty);
      expect(
        script['native_result']!.refreshRate,
        const Duration(milliseconds: 20),
      );
      expect(script['native_result']!.nativeTemplate, 'Small1');

      final scenarios = AdScenarioCoordinator(
        script: script,
        resolveAdUnitIds: (name, type) => [name],
      );
      final result = scenarios.resolve('native_result');
      expect(result.steps.single.placement.nativeFactoryId, 'Small1');
      expect(result.native!.refreshRate, const Duration(milliseconds: 20));
      expect(result.native!.collapseClickCounts, isEmpty);
      expect(result.inlineMode, isNull);
    },
  );

  test('Collap template selects its paired factory and tap counts', () {
    final scenarios = AdScenarioCoordinator(
      script: AdScript.parse('''
{"settings": {}, "native_result": {
  "enable": 1, "collap_config": "24/26",
  "native_template": "Collap2Expanded",
  "native": {"name1": "NATIVE_RESULT"}
}}
'''),
      resolveAdUnitIds: (name, type) => [name],
    );
    final result = scenarios.resolve('native_result');
    expect(result.inlineMode, AdInlineMode.collapsibleNative);
    expect(result.native!.placement.nativeFactoryId, 'Collap2Expanded');
    expect(
      result.collapsedNative!.placement.nativeFactoryId,
      'Collap2Collapsed',
    );
    expect(result.native!.collapseClickCounts, {24, 26});
    expect(result.collapsedNative!.ids, ['NATIVE_RESULT']);
  });

  test('native_inter defaults to a full-screen factory', () {
    expect(
      coordinator().resolve('inter_home').native!.placement.nativeFactoryId,
      'Full1',
    );
  });

  test('collap_config parses slash-separated counts for collapse modes', () {
    final script = AdScript.parse('''
{"settings": {}, "banner_home": {
  "enable": 4, "collap_config": "24/26",
  "native": {"name1": "NATIVE_HOME"}
}}
''');
    expect(script['banner_home']!.collapseClickCounts, {24, 26});

    for (final invalid in ['0', '-1', '"1//2"', '"24/24"', '"24/"']) {
      expect(
        AdScript.parse('''
{"settings": {}, "banner_home": {
  "enable": 4, "collap_config": $invalid,
  "native": {"name1": "NATIVE_HOME"}
}}
''')['banner_home']!.enable,
        0,
      );
    }

    expect(
      AdScript.parse('''
{"settings": {}, "native_result": {
  "enable": 1, "collap_config": "invalid/ignored",
  "native": {"name1": "NATIVE_RESULT"}
}}
''')['native_result']!.collapseClickCounts,
      isEmpty,
    );
  });

  test('step_count and wait_time stay single numeric values', () {
    for (final entry in ['"step_count": "2/3"', '"wait_time": "5/10"']) {
      expect(
        AdScript.parse('''
{"settings": {}, "inter_home": {
  "enable": 1, $entry,
  "inter": {"name1": "INTER_HOME"}
}}
''')['inter_home']!.enable,
        0,
      );
    }
  });

  test('disables an enabled scenario with a missing ad branch', () {
    expect(
      AdScript.parse('''
{"settings": {}, "inter_home": {"enable": 3, "inter": {"name1": "INTER_HOME"}}}
''')['inter_home']!.enable,
      0,
    );
  });

  test('banner collapse requires both its large native and banner', () {
    expect(
      AdScript.parse('''
{"settings": {}, "banner_home": {
  "enable": 2, "banner_collap": {"name1": "BANNER_HOME"}
}}
''')['banner_home']!.enable,
      0,
    );
  });

  test(
    'keeps the last script for malformed JSON; skips invalid placements',
    () {
      final store = AdScriptStore(AdScript.parse(json));
      expect(store.tryUpdate('{invalid'), isFalse);
      expect(store.current['inter_home']!.enable, 3);
      expect(store.lastError, isNotNull);
      expect(
        store.tryUpdate('''
{"settings": {}, "inter_home": {"enable": 99}}
'''),
        isTrue,
      );
      expect(store.current['inter_home']!.enable, 0);
      expect(store.lastError, isNull);
    },
  );

  test(
    'invalid placement logs an obvious error and leaves siblings usable',
    () {
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
      try {
        final script = AdScript.parse('''
{"settings": {},
 "native_result": {"enable": 2, "native": {"name1": "NATIVE_RESULT"}},
 "native_home": {"enable": 1, "native": {"name1": "NATIVE_HOME"}},
 "native_empty": {"enable": 1, "native": {"name1": "UNMAPPED"}},
 "native_throw": {"enable": 1, "native": {"name1": "BROKEN"}}}
''');
        final coordinator = AdScenarioCoordinator(
          script: script,
          resolveAdUnitIds: (name, type) {
            if (name == 'BROKEN') throw StateError('missing mapping');
            return name == 'UNMAPPED' ? [] : [name];
          },
        );
        expect(coordinator.resolve('native_result').isEnabled, isFalse);
        expect(coordinator.resolve('native_home').native, isNotNull);
        expect(coordinator.resolve('native_empty').isEnabled, isFalse);
        expect(coordinator.resolve('native_throw').isEnabled, isFalse);
        expect(coordinator.resolve('native_missing').isEnabled, isFalse);
        expect(
          messages.any(
            (message) =>
                message.contains('🚨 [CORE_ADS][REMOTE_CONFIG_ERROR]') &&
                message.contains('native_result') &&
                message.contains('single native'),
          ),
          isTrue,
        );
        expect(
          messages
              .where((message) => message.contains('native_missing'))
              .length,
          1,
        );
      } finally {
        debugPrint = previousDebugPrint;
      }
    },
  );
}
