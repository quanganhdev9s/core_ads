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

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: widget.ads,
    title: 'Intro',
    body: (context) {
      final introNative = widget.ads.scenarios
          .resolve(DemoAdKeys.nativeIntro)
          .nativeForIntro(page);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Intro $page / 4'),
          if (introNative == null)
            const Text('No native selected for this intro page')
          else
            DemoNativeStepCard(ads: widget.ads, step: introNative),
          OutlinedButton(
            onPressed: widget.ads.isBusy
                ? null
                : () => widget.ads.showScenario(
                    context,
                    DemoAdKeys.nativeIntroFull,
                  ),
            child: const Text('Test NATIVE_INTRO_FULL'),
          ),
          FilledButton(
            onPressed: widget.ads.isBusy
                ? null
                : () {
                    if (page < 4) {
                      setState(() => page++);
                    } else {
                      widget.ads.showScenario(
                        context,
                        DemoAdKeys.interIntro,
                        onComplete: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => HomeScreen(ads: widget.ads),
                          ),
                        ),
                      );
                    }
                  },
            child: Text(page < 4 ? 'Next intro' : 'Finish intro'),
          ),
        ],
      );
    },
  );
}
