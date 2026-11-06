import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';
import 'language_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: ads,
    title: 'Splash',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Splash: native_splash + ads_splash'),
        DemoInlineAdCard(ads: ads, placementKey: DemoAdKeys.nativeSplash),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: ads.isBusy
              ? null
              : () => ads.showScenario(
                  context,
                  DemoAdKeys.adsSplash,
                  onComplete: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => LanguageScreen(ads: ads),
                    ),
                  ),
                ),
          child: const Text('Continue to Language'),
        ),
      ],
    ),
  );
}
