import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../script/ad_scenario_controller.dart';
import 'ads_native.dart';
import 'native_ad_template.dart';

/// Native ad riêng cho `native_language` và `native_get_start`.
///
/// `enable=1` giữ CTA phía dưới và thu nhỏ sau khi chọn language. `enable=2`
/// giữ CTA phía trên, đổi từ tím sang xanh sau khi chọn. Các giá trị `enable`
/// khác `0`, `1`, `2` được coi như `0` và không hiển thị ad.
class AdsLanguageStartNative extends StatefulWidget {
  const AdsLanguageStartNative({
    required this.controller,
    required this.placementKey,
    required this.hasSelectedLanguage,
    super.key,
    this.height,
    this.width = double.infinity,
    this.showRetryButton = false,
  }) : assert(
         placementKey == 'native_language' ||
             placementKey == 'native_get_start',
       );

  final AdScenarioController controller;
  final String placementKey;
  final bool hasSelectedLanguage;
  final double? height;
  final double width;
  final bool showRetryButton;

  @override
  State<AdsLanguageStartNative> createState() => _AdsLanguageStartNativeState();
}

class _AdsLanguageStartNativeState extends State<AdsLanguageStartNative> {
  static const _channel = MethodChannel('core_ads/language_start_native');
  String? _activePlacementKey;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScenarioChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSelection();
    });
  }

  @override
  void didUpdateWidget(covariant AdsLanguageStartNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onScenarioChanged);
      widget.controller.addListener(_onScenarioChanged);
    }
    if (!identical(oldWidget.controller, widget.controller) ||
        oldWidget.placementKey != widget.placementKey ||
        oldWidget.hasSelectedLanguage != widget.hasSelectedLanguage) {
      _syncSelection();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScenarioChanged);
    if (_activePlacementKey case final key?) {
      _invoke('clear', <String, Object>{'placementKey': key});
    }
    super.dispose();
  }

  void _onScenarioChanged() {
    _syncSelection();
    setState(() {});
  }

  void _syncSelection() {
    final current = widget.controller.isInitialized
        ? widget.controller.resolve(widget.placementKey).native?.placement.key
        : null;
    if (_activePlacementKey != null && _activePlacementKey != current) {
      _invoke('clear', <String, Object>{'placementKey': _activePlacementKey!});
    }
    if (current != null) {
      _invoke('setSelected', <String, Object>{
        'placementKey': current,
        'selected': widget.hasSelectedLanguage,
      });
    }
    _activePlacementKey = current;
  }

  void _invoke(String method, Map<String, Object> arguments) {
    unawaited(
      _channel.invokeMethod<void>(method, arguments).catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isInitialized) return const SizedBox.shrink();
    final plan = widget.controller.resolve(widget.placementKey);
    final step = plan.native;
    if (step == null) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context);
    return KeyedSubtree(
      key: ValueKey(widget.controller.revision),
      child: AdsNative(
        key: ValueKey(step.placement.key),
        placement: step.placement,
        width: widget.width,
        height:
            widget.height ??
            NativeAdTemplate.forFactory(
              step.placement.nativeFactoryId,
            ).heightForScreen(screen.height, screenWidth: screen.width) ??
            360,
        refreshRate: step.refreshRate,
        showRetryButton: widget.showRetryButton,
      ),
    );
  }
}
