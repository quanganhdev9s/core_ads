import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';

class BackScreen extends StatelessWidget {
  const BackScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: ads,
    title: 'Back',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [DemoScenarioAction(ads: ads, keyName: DemoAdKeys.interBack)],
    ),
  );
}
