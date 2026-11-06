import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import '../../ads/scripted_demo_ads.dart';
import 'back_screen.dart';
import 'collection_screen.dart';
import 'demo_screen_widgets.dart';
import 'get_start_screen.dart';
import 'home_screen.dart';
import 'icon_screen.dart';
import 'intro_screen.dart';
import 'language_screen.dart';
import 'native_catalog_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'splash_screen.dart';
import 'theme_screen.dart';
import 'wallpaper_screen.dart';

/// Entry point for choosing a fixture and opening independent test routes.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: ads,
    title: 'core_ads · overview',
    actions: [
      PopupMenuButton<DemoScriptFixture>(
        tooltip: 'Select JSON config',
        enabled: !ads.isBusy,
        onSelected: ads.initialize,
        itemBuilder: (context) => [
          for (final fixture in DemoScriptFixture.values)
            PopupMenuItem(value: fixture, child: Text(fixture.label)),
        ],
        icon: const Icon(Icons.data_object),
      ),
      IconButton(
        tooltip: 'Reload JSON and reset counters',
        onPressed: ads.isBusy ? null : () => ads.initialize(),
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: (context) {
      final scenarios = ads.scenarios;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ads.fixture.assetPath,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${scenarios.script.placements.length} placements · '
            'ads_enable=${scenarios.script.settings.adsEnable} · '
            'on_resume=${scenarios.resolve(DemoAdKeys.onResume).resumeMode ?? 0} · '
            'rewards earned=${ads.rewardCount}',
          ),
          const SizedBox(height: 8),
          const Text('Open a route below to test its placements.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _open(context, SplashScreen(ads: ads)),
            child: const Text('Start screen flow'),
          ),
          OutlinedButton(
            onPressed: ads.isBusy ? null : ads.applyNextFixture,
            child: const Text('Apply next JSON live (keep inter counts)'),
          ),
          const SizedBox(height: 12),
          Text('Screens', style: Theme.of(context).textTheme.titleLarge),
          Wrap(
            spacing: 8,
            children: [
              for (final screen in _allScreens())
                ActionChip(
                  label: Text(screen.$1),
                  onPressed: () => _open(context, screen.$2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Placement plans',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final key in scenarios.script.placements.keys)
            _placementTile(context, scenarios, key),
        ],
      );
    },
  );

  Widget _placementTile(
    BuildContext context,
    AdScenarioCoordinator scenarios,
    String key,
  ) {
    final plan = scenarios.resolve(key);
    return Card(
      child: ListTile(
        dense: true,
        title: Text(key),
        subtitle: Text(
          plan.resumeMode != null
              ? 'resume mode ${plan.resumeMode}'
              : plan.steps.isEmpty
              ? 'disabled / no ad step'
              : plan.steps
                    .map((step) {
                      final factory = step.placement.nativeFactoryId;
                      return factory == null
                          ? step.branch
                          : '${step.branch} ($factory)';
                    })
                    .join(', '),
        ),
        trailing: Text('${plan.enable}'),
        onTap: () => _open(context, _screenForKey(key)),
      ),
    );
  }

  List<(String, Widget)> _allScreens() => [
    ('Splash', SplashScreen(ads: ads)),
    ('Language', LanguageScreen(ads: ads)),
    ('Intro', IntroScreen(ads: ads)),
    ('Home', HomeScreen(ads: ads)),
    ('Get Start', GetStartScreen(ads: ads)),
    ('Theme', ThemeScreen(ads: ads)),
    ('Icon', IconScreen(ads: ads)),
    ('Collection', CollectionScreen(ads: ads)),
    ('Result', ResultScreen(ads: ads)),
    ('Wallpaper', WallpaperScreen(ads: ads)),
    ('Settings', SettingsScreen(ads: ads)),
    ('Back', BackScreen(ads: ads)),
    ('Native Catalog', NativeCatalogScreen(ads: ads)),
  ];

  Widget _screenForKey(String key) => switch (key) {
    DemoAdKeys.nativeSplash || DemoAdKeys.adsSplash => SplashScreen(ads: ads),
    DemoAdKeys.nativeLanguage ||
    DemoAdKeys.nativeLanguageSmall ||
    DemoAdKeys.interLanguage => LanguageScreen(ads: ads),
    DemoAdKeys.nativeIntro ||
    DemoAdKeys.nativeIntroFull ||
    DemoAdKeys.interIntro => IntroScreen(ads: ads),
    DemoAdKeys.nativeGetStart ||
    DemoAdKeys.interStart => GetStartScreen(ads: ads),
    DemoAdKeys.bannerHome ||
    DemoAdKeys.interHome ||
    DemoAdKeys.onResume ||
    DemoAdKeys.interWelcomeBack ||
    DemoAdKeys.nativeWelcomeBack => HomeScreen(ads: ads),
    DemoAdKeys.nativeThemeSetup ||
    DemoAdKeys.rewardThemeSetup => ThemeScreen(ads: ads),
    DemoAdKeys.interIcon ||
    DemoAdKeys.rewardIconSetup ||
    DemoAdKeys.nativeDialogIcon ||
    DemoAdKeys.nativeIconSetup ||
    DemoAdKeys.rewardWidget => IconScreen(ads: ads),
    DemoAdKeys.interCollection => CollectionScreen(ads: ads),
    DemoAdKeys.bannerResult ||
    DemoAdKeys.nativeResult => ResultScreen(ads: ads),
    DemoAdKeys.bannerWallpaper => WallpaperScreen(ads: ads),
    DemoAdKeys.bannerSetting => SettingsScreen(ads: ads),
    DemoAdKeys.interBack => BackScreen(ads: ads),
    _ => NativeCatalogScreen(ads: ads),
  };

  void _open(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (context) => screen));
}
