import 'dart:async';

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
  bool _showNext = false;
  Timer? _nextTimer;

  @override
  void initState() {
    super.initState();
    final delay = widget.ads.ads.script.settings.languageNextDelay;
    if (delay == Duration.zero) {
      _showNext = true;
    } else {
      _nextTimer = Timer(delay, () {
        if (mounted) setState(() => _showNext = true);
      });
    }
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    super.dispose();
  }

  void _continue() => widget.ads.showFullscreenAds(
    context,
    DemoAdKeys.interLanguage,
    onComplete: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => IntroScreen(ads: widget.ads),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: widget.ads,
    title: 'Language',
    body: (context) {
      final settings = widget.ads.ads.script.settings;
      final activePlacement = hasSelectedLanguage
          ? DemoAdKeys.nativeLanguage2
          : DemoAdKeys.nativeLanguage;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Language: $activePlacement.enable='
            '${widget.ads.scenarios.resolve(activePlacement).enable}',
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
            selectedPlacementKey: DemoAdKeys.nativeLanguage2,
            hasSelectedLanguage: hasSelectedLanguage,
          ),
          DemoInlineAdCard(
            ads: widget.ads,
            placementKey: DemoAdKeys.nativeLanguageSmall,
          ),
          const SizedBox(height: 12),
          if (!_showNext && settings.languageShowLoading)
            const Center(child: CircularProgressIndicator())
          else if (_showNext && settings.languageNextStyle == 'icon')
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filled(
                onPressed: widget.ads.isBusy ? null : _continue,
                icon: const Icon(Icons.check),
                tooltip: 'Continue to Intro',
              ),
            )
          else if (_showNext)
            FilledButton(
              onPressed: widget.ads.isBusy ? null : _continue,
              child: const Text('Continue to Intro'),
            ),
        ],
      );
    },
  );
}
