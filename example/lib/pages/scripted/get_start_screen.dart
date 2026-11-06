import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';

class GetStartScreen extends StatefulWidget {
  const GetStartScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  State<GetStartScreen> createState() => _GetStartScreenState();
}

class _GetStartScreenState extends State<GetStartScreen> {
  bool hasSelectedLanguage = false;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: widget.ads,
    title: 'Get Start',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Get Start: native_get_start.enable = '
          '${widget.ads.scenarios.resolve(DemoAdKeys.nativeGetStart).enable}',
        ),
        SwitchListTile(
          title: const Text('Language selected'),
          value: hasSelectedLanguage,
          onChanged: (selected) =>
              setState(() => hasSelectedLanguage = selected),
        ),
        AdsLanguageStartNative(
          controller: widget.ads.ads,
          placementKey: DemoAdKeys.nativeGetStart,
          hasSelectedLanguage: hasSelectedLanguage,
        ),
        DemoScenarioAction(ads: widget.ads, keyName: DemoAdKeys.interStart),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
      ],
    ),
  );
}
