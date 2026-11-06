import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../../ads/demo_ads_controller.dart';
import 'demo_screen_widgets.dart';

class NativeCatalogScreen extends StatefulWidget {
  const NativeCatalogScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  State<NativeCatalogScreen> createState() => _NativeCatalogScreenState();
}

class _NativeCatalogScreenState extends State<NativeCatalogScreen> {
  String? selectedKey;

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: widget.ads,
    title: 'Native Catalog',
    body: (context) {
      final steps = <AdScenarioStep>[
        for (final key in widget.ads.ads.script.placements.keys)
          for (final step in widget.ads.ads.resolve(key).steps)
            if (step.placement.type == AdType.native) step,
      ];
      if (steps.isEmpty) return const Text('No native steps selected');
      final currentKey = steps.any((step) => step.placement.key == selectedKey)
          ? selectedKey!
          : steps.first.placement.key;
      final selected = steps.firstWhere(
        (step) => step.placement.key == currentKey,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selected native steps: ${steps.length}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Choose one step to load its test ad. Full templates can '
            'also open in a full-screen route.',
          ),
          DropdownButton<String>(
            isExpanded: true,
            value: currentKey,
            onChanged: (value) => setState(() => selectedKey = value),
            items: [
              for (final step in steps)
                DropdownMenuItem(
                  value: step.placement.key,
                  child: Text(
                    '${step.placement.key} · '
                    '${step.placement.nativeFactoryId}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (selected.placement.nativeFactoryId?.startsWith('Full') != true)
            DemoNativeStepCard(ads: widget.ads, step: selected),
          if (selected.placement.nativeFactoryId?.startsWith('Full') == true)
            OutlinedButton(
              onPressed: widget.ads.isBusy
                  ? null
                  : () => widget.ads.openNativeStep(context, selected),
              child: const Text('Open full-screen native'),
            ),
        ],
      );
    },
  );
}
