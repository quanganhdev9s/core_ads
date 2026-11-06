import 'package:flutter/material.dart';

import '../pages/ads_example_page.dart';
import '../pages/scripted_ads_flow_page.dart';

class CoreAdsExampleApp extends StatelessWidget {
  const CoreAdsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'core_ads example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const bool.fromEnvironment('LEGACY_ADS_DEMO')
          ? const AdsExamplePage()
          : const ScriptedAdsFlowPage(),
    );
  }
}
