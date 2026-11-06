import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../ads/demo_ads_controller.dart';
import 'scripted/overview_screen.dart';

/// Composition root for the scripted example. Product screens are routes in
/// `scripted/`; this widget owns the app-side ads controller for their lifetime.
class ScriptedAdsFlowPage extends StatefulWidget {
  const ScriptedAdsFlowPage({super.key});

  @override
  State<ScriptedAdsFlowPage> createState() => _ScriptedAdsFlowPageState();
}

class _ScriptedAdsFlowPageState extends State<ScriptedAdsFlowPage> {
  late final DemoAdsController ads;

  @override
  void initState() {
    super.initState();
    AdsNative.debugShowPlacementLabel = true;
    ads = DemoAdsController();
    ads.initialize();
  }

  @override
  void dispose() {
    AdsNative.debugShowPlacementLabel = false;
    ads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ads,
    builder: (context, _) {
      if (ads.isReady) return OverviewScreen(ads: ads);
      return Scaffold(
        appBar: AppBar(title: const Text('core_ads example')),
        body: Center(
          child: ads.error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ads.error!),
                    FilledButton(
                      onPressed: () => ads.initialize(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}
