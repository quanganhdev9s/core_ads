import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';
import 'get_start_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: ads,
    title: 'Home',
    body: (context) {
      final scenarios = ads.scenarios;
      final plan = scenarios.resolve(DemoAdKeys.bannerHome);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Home: banner_home.enable = ${plan.enable} '
            '(${plan.inlineMode?.name ?? 'off'})',
          ),
          DemoInlineAdCard(ads: ads, placementKey: DemoAdKeys.bannerHome),
          DemoInlineAdCard(ads: ads, placementKey: DemoAdKeys.nativeHomeFeed),
          DemoInlineAdCard(
            ads: ads,
            placementKey: DemoAdKeys.nativeWelcomeBack,
          ),
          FilledButton(
            onPressed: ads.isBusy
                ? null
                : () => ads.showFullscreenAds(
                    context,
                    DemoAdKeys.interStart,
                    onComplete: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => GetStartScreen(ads: ads),
                      ),
                    ),
                  ),
            child: const Text('Get Start via INTER_START'),
          ),
          OutlinedButton(
            onPressed: ads.isBusy
                ? null
                : () => ads.showFullscreenAds(context, DemoAdKeys.interHome),
            child: const Text('Test INTER_HOME (step / refresh_ms)'),
          ),
          OutlinedButton(
            onPressed: ads.isBusy
                ? null
                : () => ads.showFullscreenAds(context, DemoAdKeys.onResume),
            child: const Text('Test ON_RESUME'),
          ),
          Text(
            'on_resume = ${scenarios.resolve(DemoAdKeys.onResume).resumeMode ?? 0} '
            '(manual test; the script does not own app lifecycle navigation)',
          ),
        ],
      );
    },
  );
}
