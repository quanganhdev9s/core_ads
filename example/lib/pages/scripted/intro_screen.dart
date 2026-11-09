import 'dart:async';

import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';
import 'home_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  int page = 1;
  bool _nextReady = true;
  Timer? _nextTimer;

  @override
  void initState() {
    super.initState();
    widget.ads.ads.resetNativeFullOnboarding();
    _scheduleNext();
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    super.dispose();
  }

  void _scheduleNext() {
    _nextTimer?.cancel();
    final delay = widget.ads.ads.script.settings.onboardingNextDelay;
    _nextReady = delay == Duration.zero;
    if (!_nextReady) {
      _nextTimer = Timer(delay, () {
        if (mounted) setState(() => _nextReady = true);
      });
    }
  }

  Future<void> _advance(String fullKey, String interKey) async {
    if (widget.ads.isBusy || !_nextReady) return;
    if (page < 4) {
      await widget.ads.showFullscreenAds(context, fullKey);
      if (mounted) {
        setState(() {
          page++;
          _scheduleNext();
        });
      }
      return;
    }
    await widget.ads.showFullscreenAds(
      context,
      interKey,
      onComplete: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => HomeScreen(ads: widget.ads),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const nativeKey = DemoAdKeys.nativeOnboarding;
    const fullKey = DemoAdKeys.nativeFullOnboarding;
    const interKey = DemoAdKeys.interOnboarding;
    final settings = widget.ads.ads.script.settings;
    return DemoScreenScaffold(
      ads: widget.ads,
      title: 'Intro',
      body: (context) {
        final introNative = widget.ads.scenarios
            .resolve(nativeKey)
            .nativeForIntro(page);
        return GestureDetector(
          onHorizontalDragEnd: settings.onboardingSwipe
              ? (details) {
                  if ((details.primaryVelocity ?? 0) < 0) {
                    _advance(fullKey, interKey);
                  }
                }
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Intro $page / 4'),
              if (settings.onboardingShowDots)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 1; index <= 4; index++)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          index == page ? Icons.circle : Icons.circle_outlined,
                          size: 10,
                        ),
                      ),
                  ],
                ),
              if (introNative == null)
                const Text('No native selected for this intro page')
              else
                DemoNativeStepCard(ads: widget.ads, step: introNative),
              Align(
                alignment: settings.onboardingNextPosition == 'right'
                    ? Alignment.centerRight
                    : Alignment.center,
                child: settings.onboardingNextStyle == 'icon'
                    ? IconButton.filled(
                        onPressed: widget.ads.isBusy || !_nextReady
                            ? null
                            : () => _advance(fullKey, interKey),
                        icon: const Icon(Icons.arrow_forward),
                      )
                    : FilledButton(
                        onPressed: widget.ads.isBusy || !_nextReady
                            ? null
                            : () => _advance(fullKey, interKey),
                        child: Text(page < 4 ? 'Next intro' : 'Finish intro'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
