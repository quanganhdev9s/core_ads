import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: ads,
    title: 'Theme setup',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoInlineAdCard(ads: ads, placementKey: DemoAdKeys.nativeThemeSetup),
        DemoRewardAction(ads: ads, keyName: DemoAdKeys.rewardThemeSetup),
      ],
    ),
  );
}
