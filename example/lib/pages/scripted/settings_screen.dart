import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: ads,
    title: 'Settings',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoInlineAdCard(ads: ads, placementKey: DemoAdKeys.bannerSetting),
        DemoInlineAdCard(ads: ads, placementKey: DemoAdKeys.nativeSetting),
      ],
    ),
  );
}
