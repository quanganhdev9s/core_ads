import 'package:flutter/material.dart';
import 'package:core_ads/core_ads.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';
import 'intro_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool hasSelectedLanguage = false;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: widget.ads,
    title: 'Language',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Language: native_language.enable='
          '${widget.ads.scenarios.resolve(DemoAdKeys.nativeLanguage).enable}',
        ),
        ChoiceChip(
          label: const Text('English'),
          selected: hasSelectedLanguage,
          onSelected: (selected) =>
              setState(() => hasSelectedLanguage = selected),
        ),
        AdsLanguageStartNative(
          controller: widget.ads.ads,
          placementKey: DemoAdKeys.nativeLanguage,
          hasSelectedLanguage: hasSelectedLanguage,
        ),
        DemoInlineAdCard(
          ads: widget.ads,
          placementKey: DemoAdKeys.nativeLanguageSmall,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.ads.isBusy
              ? null
              : () => widget.ads.showScenario(
                  context,
                  DemoAdKeys.interLanguage,
                  onComplete: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => IntroScreen(ads: widget.ads),
                    ),
                  ),
                ),
          child: const Text('Continue to Intro'),
        ),
      ],
    ),
  );
}
