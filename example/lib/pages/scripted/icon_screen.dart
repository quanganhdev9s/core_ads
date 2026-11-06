import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';

class IconScreen extends StatelessWidget {
  const IconScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: ads,
    title: 'Icon setup',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoInlineAdCard(ads: ads, placementKey: DemoAdKeys.nativeDialogIcon),
        DemoInlineAdCard(ads: ads, placementKey: DemoAdKeys.nativeIconSetup),
        DemoScenarioAction(ads: ads, keyName: DemoAdKeys.interIcon),
        DemoRewardAction(ads: ads, keyName: DemoAdKeys.rewardIconSetup),
        DemoRewardAction(ads: ads, keyName: DemoAdKeys.rewardWidget),
      ],
    ),
  );
}
