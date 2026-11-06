import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: ads,
    title: 'Collection',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoScenarioAction(ads: ads, keyName: DemoAdKeys.interCollection),
      ],
    ),
  );
}
