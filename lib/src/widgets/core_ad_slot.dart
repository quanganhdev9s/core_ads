import 'package:flutter/material.dart';

import '../ads/banner/ads_banner.dart';
import '../ads/banner/banner_ad_config.dart';
import '../ads/native/ads_collapsible_native.dart';
import '../ads/native/ads_native.dart';
import '../ads/native/native_ad_template.dart';
import '../core/enums/ad_type.dart';
import '../script/ad_scenario_controller.dart';
import '../script/ad_scenario_coordinator.dart';
import '../script/ad_script_diagnostics.dart';

/// Renders one inline ad location according to the active Remote Config script.
///
/// The app places this widget only where an ad belongs. The package chooses
/// the format and returns an empty widget when that placement is disabled.
class CoreAdSlot extends StatefulWidget {
  const CoreAdSlot({
    required this.controller,
    required this.placementKey,
    super.key,
    this.nativeHeight,
    this.collapsedNativeHeight,
    this.bannerConfig = const BannerAdConfig.banner(),
    this.expanded,
    this.closeButton,
    this.onCollapsed,
  });

  final AdScenarioController controller;
  final String placementKey;

  /// Overrides the height suggested by the selected native factory.
  final double? nativeHeight;

  /// Overrides the height suggested by the collapsed native factory.
  final double? collapsedNativeHeight;
  final BannerAdConfig bannerConfig;
  final bool? expanded;
  final Widget? closeButton;
  final VoidCallback? onCollapsed;

  @override
  State<CoreAdSlot> createState() => _CoreAdSlotState();
}

class _CoreAdSlotState extends State<CoreAdSlot> {
  final Set<String> _reportedInvalidPlans = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScenarioChanged);
  }

  @override
  void didUpdateWidget(covariant CoreAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onScenarioChanged);
      widget.controller.addListener(_onScenarioChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScenarioChanged);
    super.dispose();
  }

  void _onScenarioChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isInitialized) return const SizedBox.shrink();
    final plan = widget.controller.resolve(widget.placementKey);
    if (!plan.isEnabled) return const SizedBox.shrink();
    if (!_canRenderInline(plan)) {
      return _hideInvalidPlan(plan);
    }
    final screenSize = MediaQuery.sizeOf(context);

    final Widget ad = switch (plan.inlineMode) {
      AdInlineMode.banner => AdsBanner(
        placement: plan.banner!.placement,
        config: widget.bannerConfig,
        refreshRate: plan.banner!.refreshRate,
      ),
      AdInlineMode.adMobCollapsibleBanner => AdsBanner(
        placement: plan.banner!.placement,
        config: widget.bannerConfig.withCollapsible(true),
        refreshRate: plan.banner!.refreshRate,
      ),
      AdInlineMode.native => AdsNative(
        placement: plan.native!.placement,
        height: _nativeHeight(plan.native!, screenSize),
        refreshRate: plan.native!.refreshRate,
      ),
      AdInlineMode.collapsibleNative => AdsCollapsibleNative(
        nativePlacement: plan.native!.placement,
        collapsedFactoryId: widget.controller.collapsedNativeFactoryId,
        nativeHeight: _nativeHeight(plan.native!, screenSize),
        nativeRefreshRate: plan.native!.refreshRate,
        collapsedNativeHeight: widget.collapsedNativeHeight,
        collapseClickCounts: plan.native!.collapseClickCounts,
        expanded: widget.expanded,
        closeButton: widget.closeButton,
        onCollapsed: widget.onCollapsed,
        nativeClearOnDispose: false,
        bannerClearOnDispose: false,
      ),
      null => _singleFormatAd(plan, screenSize),
    };
    return KeyedSubtree(key: ValueKey(widget.controller.revision), child: ad);
  }

  Widget _singleFormatAd(AdScenarioPlan plan, Size screenSize) {
    final step = plan.steps.single;
    return switch (step.placement.type) {
      AdType.banner => AdsBanner(
        placement: step.placement,
        config: widget.bannerConfig,
      ),
      AdType.native => AdsNative(
        placement: step.placement,
        height: _nativeHeight(step, screenSize),
        refreshRate: step.refreshRate,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  bool _canRenderInline(AdScenarioPlan plan) => switch (plan.inlineMode) {
    AdInlineMode.banner ||
    AdInlineMode.adMobCollapsibleBanner => plan.banner != null,
    AdInlineMode.native || AdInlineMode.collapsibleNative =>
      plan.native != null && _isInlineNative(plan.native!),
    null =>
      plan.steps.length == 1 &&
          (plan.steps.single.placement.type == AdType.native &&
                  _isInlineNative(plan.steps.single) ||
              plan.steps.single.placement.type == AdType.banner) &&
          plan.steps.single.branch != 'native_inter',
  };

  bool _isInlineNative(AdScenarioStep step) =>
      NativeAdTemplate.forFactory(
        step.placement.nativeFactoryId,
      ).skeletonKind !=
      NativeAdSkeletonKind.full;

  Widget _hideInvalidPlan(AdScenarioPlan plan) {
    final reportKey = '${widget.controller.revision}:${plan.key}';
    if (_reportedInvalidPlans.add(reportKey)) {
      logAdScriptError(
        plan.key,
        'CoreAdSlot cannot render this plan inline; use showFullscreenAds for '
        'fullscreen ads or check this placement config',
        action: 'inline ad hidden',
      );
    }
    return const SizedBox.shrink();
  }

  double _nativeHeight(AdScenarioStep step, Size screenSize) =>
      widget.nativeHeight ??
      NativeAdTemplate.forFactory(
        step.placement.nativeFactoryId,
      ).heightForScreen(screenSize.height, screenWidth: screenSize.width) ??
      360;
}
