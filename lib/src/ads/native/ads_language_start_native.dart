import 'package:flutter/material.dart';

import '../../script/ad_scenario_controller.dart';
import 'ads_native.dart';
import 'native_ad_template.dart';

/// Hiển thị placement thứ nhất trước khi chọn ngôn ngữ, placement thứ hai sau đó.
/// Mỗi placement có ad unit và template riêng trong config v2.
class AdsLanguageStartNative extends StatelessWidget {
  const AdsLanguageStartNative({
    required this.controller,
    required this.placementKey,
    required this.selectedPlacementKey,
    required this.hasSelectedLanguage,
    super.key,
    this.height,
    this.width = double.infinity,
    this.showRetryButton = false,
  });

  final AdScenarioController controller;
  final String placementKey;
  final String selectedPlacementKey;
  final bool hasSelectedLanguage;
  final double? height;
  final double width;
  final bool showRetryButton;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (!controller.isInitialized) return const SizedBox.shrink();
      final key = hasSelectedLanguage ? selectedPlacementKey : placementKey;
      final step = controller.resolve(key).native;
      if (step == null) return const SizedBox.shrink();
      final screen = MediaQuery.sizeOf(context);
      return AdsNative(
        key: ValueKey('${controller.revision}-${step.placement.key}'),
        placement: step.placement,
        width: width,
        height:
            height ??
            NativeAdTemplate.forFactory(
              step.placement.nativeFactoryId,
            ).heightForScreen(screen.height, screenWidth: screen.width) ??
            360,
        refreshRate: step.refreshRate,
        showRetryButton: showRetryButton,
      );
    },
  );
}
