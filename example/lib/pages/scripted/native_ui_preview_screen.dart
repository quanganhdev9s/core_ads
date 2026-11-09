import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../../ads/demo_ads_controller.dart';
import '../../ads/native_ui_preview_catalog.dart';

/// Mỗi layout có route riêng; native Full chiếm toàn bộ vùng Safe Area.
class NativeUiPreviewScreen extends StatefulWidget {
  const NativeUiPreviewScreen({
    required this.ads,
    required this.type,
    super.key,
  });

  final DemoAdsController ads;
  final NativeAdType type;

  @override
  State<NativeUiPreviewScreen> createState() => _NativeUiPreviewScreenState();
}

class _NativeUiPreviewScreenState extends State<NativeUiPreviewScreen> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final step = NativeUiPreviewCatalog.stepFor(widget.type);
    final placement = step.placement;
    final isFull = widget.type.factoryId.startsWith('Full');
    if (isFull) {
      return Scaffold(
        body: AdsFullScreenNative(
          step: step,
          onClose: () => Navigator.of(context).pop(),
          onVisible: () => widget.ads.log('${placement.key}: visible'),
          onFailed: (failure) =>
              widget.ads.log('${placement.key}: ${failure.code}'),
        ),
      );
    }

    final screen = MediaQuery.sizeOf(context);
    final collapsedType = widget.type.collapsedType;
    final height =
        NativeAdTemplate.forFactory(
          widget.type.factoryId,
        ).heightForScreen(screen.height, screenWidth: screen.width) ??
        420;
    final native = AdsNative(
      placement: placement,
      width: widget.type == NativeAdType.card1 ? 280 : double.infinity,
      height: height,
      clearOnDispose: true,
      showRetryButton: true,
      onVisible: () => widget.ads.log('${placement.key}: visible'),
      onFailed: (failure) =>
          widget.ads.log('${placement.key}: ${failure.code}'),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.type.factoryId)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      placement.key,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    if (collapsedType != null) ...[
                      AdsCollapsibleNative(
                        nativePlacement: placement,
                        nativeHeight: height,
                        collapsedNativeHeight: collapsedType.resolveHeight(
                          screen.height,
                          screenWidth: screen.width,
                        ),
                        expanded: _expanded,
                        showRetryButton: true,
                        onNativeLoaded: () =>
                            widget.ads.log('${placement.key}: loaded'),
                        onNativeFailed: (failure) =>
                            widget.ads.log('${placement.key}: ${failure.code}'),
                        onCollapsed: () => setState(() => _expanded = false),
                      ),
                      const SizedBox(height: 12),
                      if (!_expanded)
                        OutlinedButton(
                          onPressed: () => setState(() => _expanded = true),
                          child: const Text('Mở rộng lại'),
                        ),
                    ] else if (widget.type == NativeAdType.card1)
                      Align(child: native)
                    else
                      native,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
