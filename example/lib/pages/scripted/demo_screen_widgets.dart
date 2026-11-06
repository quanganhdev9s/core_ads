import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../../ads/demo_ads_controller.dart';

/// Shared frame for actual routes. Each screen owns only its placement keys.
class DemoScreenScaffold extends StatelessWidget {
  const DemoScreenScaffold({
    required this.ads,
    required this.title,
    required this.body,
    super.key,
    this.actions = const [],
  });

  final DemoAdsController ads;
  final String title;
  final Widget Function(BuildContext context) body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ads,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Config: ${ads.fixture.label}'),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: body(context),
            ),
          ),
          _DemoEventLog(ads: ads),
        ],
      ),
    ),
  );
}

class _DemoEventLog extends StatelessWidget {
  const _DemoEventLog({required this.ads});

  final DemoAdsController ads;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.receipt_long),
      title: Text(
        ads.events.isEmpty ? 'Ad events' : ads.events.first,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${ads.events.length} events · tap to view'),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: ListView.builder(
              itemCount: ads.events.length,
              itemBuilder: (context, index) =>
                  ListTile(dense: true, title: Text(ads.events[index])),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Places the package's CoreAdSlot at the same point as a product screen.
class DemoInlineAdCard extends StatefulWidget {
  const DemoInlineAdCard({
    required this.ads,
    required this.placementKey,
    super.key,
  });

  final DemoAdsController ads;
  final String placementKey;

  @override
  State<DemoInlineAdCard> createState() => _DemoInlineAdCardState();
}

class _DemoInlineAdCardState extends State<DemoInlineAdCard> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final plan = widget.ads.scenarios.resolve(widget.placementKey);
    final nativeSteps = plan.steps
        .where(
          (step) =>
              step.placement.type == AdType.native &&
              step.branch != 'native_small',
        )
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.placementKey} · enable=${plan.enable}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              plan.inlineMode?.name ??
                  '${plan.steps.map((step) => step.branch).join(', ')} - '
                      '${plan.native?.placement.nativeFactoryId}',
            ),
            const SizedBox(height: 8),
            if (!plan.isEnabled)
              const Text('Disabled by this JSON')
            else if (nativeSteps.length > 1)
              for (final step in nativeSteps)
                DemoNativeStepCard(ads: widget.ads, step: step)
            else
              CoreAdSlot(
                key: ValueKey(
                  '${widget.ads.fixture.name}-${widget.placementKey}',
                ),
                controller: widget.ads.ads,
                placementKey: widget.placementKey,
                expanded: expanded,
                onCollapsed: () => setState(() => expanded = false),
              ),
            if (plan.inlineMode == AdInlineMode.collapsibleBanner ||
                plan.inlineMode == AdInlineMode.collapsibleNative)
              OutlinedButton(
                onPressed: () => setState(() => expanded = true),
                child: const Text('Expand again'),
              ),
          ],
        ),
      ),
    );
  }
}

class DemoNativeStepCard extends StatelessWidget {
  const DemoNativeStepCard({required this.ads, required this.step, super.key});

  final DemoAdsController ads;
  final AdScenarioStep step;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${step.placement.key} · ${step.placement.nativeFactoryId}'),
          AdsNative(
            key: ValueKey('${ads.fixture.name}-${step.placement.key}'),
            placement: step.placement,
            height:
                NativeAdTemplate.forFactory(
                  step.placement.nativeFactoryId,
                ).heightForScreen(
                  screenSize.height,
                  screenWidth: screenSize.width,
                ) ??
                420,
            showRetryButton: true,
            refreshRate: step.refreshRate,
            onVisible: () => ads.log('${step.placement.key}: visible'),
            onFailed: (failure) =>
                ads.log('${step.placement.key}: ${failure.code}'),
          ),
        ],
      ),
    );
  }
}

class DemoScenarioAction extends StatelessWidget {
  const DemoScenarioAction({
    required this.ads,
    required this.keyName,
    super.key,
  });

  final DemoAdsController ads;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final plan = ads.scenarios.resolve(keyName);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$keyName · enable=${plan.enable}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              plan.steps.isEmpty
                  ? 'No ad step in this JSON'
                  : plan.steps
                        .map((step) {
                          final factory = step.placement.nativeFactoryId;
                          return factory == null
                              ? step.branch
                              : '${step.branch} ($factory)';
                        })
                        .join(' → '),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: ads.isBusy
                  ? null
                  : () => ads.showScenario(context, keyName),
              child: Text('Run $keyName'),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoRewardAction extends StatelessWidget {
  const DemoRewardAction({required this.ads, required this.keyName, super.key});

  final DemoAdsController ads;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final plan = ads.scenarios.resolve(keyName);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$keyName · enable=${plan.enable}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: ads.isBusy ? null : () => ads.showReward(keyName),
              child: Text('Show reward · earned ${ads.rewardCount}'),
            ),
          ],
        ),
      ),
    );
  }
}
