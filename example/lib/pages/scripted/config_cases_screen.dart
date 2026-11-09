import 'package:flutter/material.dart';

import '../../ads/demo_ad_keys.dart';
import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';

/// Các placement bổ sung để kiểm tra từng type/format sau khi đọc JSON v2.
class ConfigCasesScreen extends StatefulWidget {
  const ConfigCasesScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  State<ConfigCasesScreen> createState() => _ConfigCasesScreenState();
}

class _ConfigCasesScreenState extends State<ConfigCasesScreen> {
  static const _inlineKeys = [
    DemoAdKeys.bannerTestCollapsible,
    DemoAdKeys.bannerTestNativeBanner,
    DemoAdKeys.bannerTestNativeBannerCollapsible,
    DemoAdKeys.bannerTestNative,
    DemoAdKeys.nativeTestCollap,
    DemoAdKeys.nativeTestDisabled,
  ];

  String selectedInlineKey = _inlineKeys.first;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: widget.ads,
    title: 'Config v2 cases',
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bật Marketing user ở Overview để xem các case FULL. '
          'Không bật để xem BASIC. Settings có native_setting dùng template '
          'custom từ ad_templates.',
        ),
        const SizedBox(height: 12),
        Text('Fullscreen', style: Theme.of(context).textTheme.titleLarge),
        DemoScenarioAction(ads: widget.ads, keyName: DemoAdKeys.adsTestAoa),
        DemoScenarioAction(ads: widget.ads, keyName: DemoAdKeys.adsTestInter),
        DemoScenarioAction(
          ads: widget.ads,
          keyName: DemoAdKeys.interTestNativeFull,
        ),
        const SizedBox(height: 12),
        Text('Reward', style: Theme.of(context).textTheme.titleLarge),
        DemoRewardAction(ads: widget.ads, keyName: DemoAdKeys.rewardTest),
        DemoRewardAction(ads: widget.ads, keyName: DemoAdKeys.rewardInterTest),
        const SizedBox(height: 12),
        Text('Inline', style: Theme.of(context).textTheme.titleLarge),
        DropdownButton<String>(
          isExpanded: true,
          value: selectedInlineKey,
          onChanged: (value) {
            if (value != null) setState(() => selectedInlineKey = value);
          },
          items: [
            for (final key in _inlineKeys)
              DropdownMenuItem(value: key, child: Text(key)),
          ],
        ),
        DemoInlineAdCard(
          key: ValueKey(selectedInlineKey),
          ads: widget.ads,
          placementKey: selectedInlineKey,
        ),
      ],
    ),
  );
}
