import 'dart:async';

import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import '../../ads/splash_timing_config.dart';
import 'demo_screen_widgets.dart';
import 'language_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _minimumTimer;
  Timer? _maximumTimer;
  bool _minimumReached = false;
  bool _preloadFinished = false;
  bool _adReady = false;
  bool _transitionStarted = false;

  @override
  void initState() {
    super.initState();
    final timing = SplashTimingConfig.fromSettings(
      widget.ads.ads.script.settings,
    );
    _minimumReached = timing.minimum == Duration.zero;
    if (!_minimumReached) {
      _minimumTimer = Timer(timing.minimum, () {
        _minimumReached = true;
        _finishWhenReady();
      });
    }
    _maximumTimer = Timer(timing.maximum, _skipAndAdvance);
    unawaited(_preloadSplashAd());
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _maximumTimer?.cancel();
    super.dispose();
  }

  Future<void> _preloadSplashAd() async {
    final plan = widget.ads.scenarios.resolve(DemoAdKeys.adsSplash);
    final primary =
        plan.interstitial ??
        _firstStepOfType(plan, AdType.appOpen) ??
        plan.native;
    if (primary != null) {
      try {
        final result = await CoreAds.load(primary.placement);
        _adReady =
            result.isSuccess &&
            CoreAds.getStatus(primary.placement) == AdLoadStatus.ready;
      } catch (error) {
        widget.ads.log('ads_splash preload: $error');
      }
    }
    _preloadFinished = true;
    _finishWhenReady();
  }

  AdScenarioStep? _firstStepOfType(AdScenarioPlan plan, AdType type) {
    for (final step in plan.steps) {
      if (step.placement.type == type) return step;
    }
    return null;
  }

  void _finishWhenReady() {
    if (!mounted ||
        _transitionStarted ||
        !_minimumReached ||
        !_preloadFinished) {
      return;
    }
    if (_adReady && !widget.ads.isBusy) {
      unawaited(_showAdThenAdvance());
    } else if (!_adReady) {
      _skipAndAdvance();
    }
  }

  Future<void> _showAdThenAdvance() async {
    if (!mounted || _transitionStarted) return;
    _transitionStarted = true;
    _maximumTimer?.cancel();
    await widget.ads.showFullscreenAds(context, DemoAdKeys.adsSplash);
    if (mounted) _advance();
  }

  void _skipAndAdvance() {
    if (!mounted || _transitionStarted) return;
    _transitionStarted = true;
    _minimumTimer?.cancel();
    _maximumTimer?.cancel();
    widget.ads.markSplashAdSkipped();
    _advance();
  }

  void _advance() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LanguageScreen(ads: widget.ads),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: widget.ads,
    title: 'Splash',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Splash: native_splash + ads_splash'),
        DemoInlineAdCard(
          ads: widget.ads,
          placementKey: DemoAdKeys.nativeSplash,
        ),
        const SizedBox(height: 12),
        const Center(child: CircularProgressIndicator()),
      ],
    ),
  );
}
