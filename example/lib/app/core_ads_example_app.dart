import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../pages/ads_example_page.dart';

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
      navigatorObservers: [AdsRouteObserver.instance],
      home: const AdsExamplePage(),
    );
  }
}
