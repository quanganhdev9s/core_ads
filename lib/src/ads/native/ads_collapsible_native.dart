import 'package:flutter/material.dart';

import '../../ads/banner/ads_banner.dart';
import '../../ads/banner/banner_ad_config.dart';
import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_type.dart';
import '../../core/results/ad_failure.dart';
import '../../widgets/ads_loading_widget.dart';
import 'ads_native.dart';

/// Native ad widget that can collapse into a smaller banner placement.
class AdsCollapsibleNative extends StatefulWidget {
  /// Creates a collapsible native ad.
  const AdsCollapsibleNative({
    required this.nativePlacement,
    required this.bannerPlacement,
    super.key,
    this.nativeLoading,
    this.nativeError,
    this.nativeErrorBuilder,
    this.bannerLoading,
    this.bannerError,
    this.bannerErrorBuilder,
    this.bannerConfig = const BannerAdConfig.banner(),
    this.bannerBackgroundColor,
    this.width = double.infinity,
    this.nativeHeight = 120,
    this.collapsedAlignment = Alignment.bottomCenter,
    this.closeButton,
    this.expanded,
    this.nativeClearOnDispose = true,
    this.bannerClearOnDispose = true,
    this.showRetryButton = false,
    this.onNativeLoaded,
    this.onNativeFailed,
    this.onBannerLoaded,
    this.onBannerFailed,
    this.onCollapsed,
  });

  /// Native placement shown while expanded.
  final AdPlacement nativePlacement;

  /// Banner placement shown after the native ad is collapsed.
  final AdPlacement bannerPlacement;

  /// Widget shown while the native ad is loading.
  final Widget? nativeLoading;

  /// Widget shown when the native ad fails to load.
  final Widget? nativeError;

  /// Builder shown when the native ad fails to load.
  final Widget Function(BuildContext context, VoidCallback retry)?
  nativeErrorBuilder;

  /// Widget shown while the fallback banner is loading.
  final Widget? bannerLoading;

  /// Widget shown when the fallback banner fails to load.
  final Widget? bannerError;

  /// Builder shown when the fallback banner fails to load.
  final Widget Function(BuildContext context, VoidCallback retry)?
  bannerErrorBuilder;

  /// Banner configuration used while collapsed.
  final BannerAdConfig bannerConfig;

  ///
  final Color? bannerBackgroundColor;

  /// Expanded widget width.
  final double width;

  /// Expanded native ad height.
  final double nativeHeight;

  /// Alignment for the collapsed banner inside the original native ad bounds.
  final AlignmentGeometry collapsedAlignment;

  /// Custom close button shown at the top-right of the native ad.
  final Widget? closeButton;

  /// Whether the native ad is expanded.
  ///
  /// When this value changes, the widget syncs its internal expanded state.
  /// The close button can still collapse the ad locally.
  final bool? expanded;

  /// Whether the native ad is cleared when its widget is disposed.
  final bool nativeClearOnDispose;

  /// Whether the banner ad is cleared when its widget is disposed.
  final bool bannerClearOnDispose;

  /// Whether child ad widgets show their default retry button.
  final bool showRetryButton;

  /// Called when the native ad loads.
  final VoidCallback? onNativeLoaded;

  /// Called when the native ad fails to load.
  final void Function(AdFailure failure)? onNativeFailed;

  /// Called when the fallback banner loads.
  final VoidCallback? onBannerLoaded;

  /// Called when the fallback banner fails to load.
  final void Function(AdFailure failure)? onBannerFailed;

  /// Called when the user collapses the native ad.
  final VoidCallback? onCollapsed;

  @override
  State<AdsCollapsibleNative> createState() => _AdsCollapsibleNativeState();
}

class _AdsCollapsibleNativeState extends State<AdsCollapsibleNative> {
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    assert(
      widget.nativePlacement.type == AdType.native,
      'nativePlacement must use AdType.native',
    );
    assert(
      widget.bannerPlacement.type == AdType.banner,
      'bannerPlacement must use AdType.banner',
    );
    _expanded = widget.expanded ?? true;
  }

  @override
  void didUpdateWidget(covariant AdsCollapsibleNative oldWidget) {
    super.didUpdateWidget(oldWidget);

    final expanded = widget.expanded;
    if (expanded != null && expanded != oldWidget.expanded) {
      _expanded = expanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: _expanded
          ? widget.nativeHeight
          : widget.bannerConfig.resolvedHeight,
      child: _expanded ? _buildExpanded() : _buildCollapsed(),
    );
  }

  Widget _buildExpanded() {
    return Stack(
      fit: StackFit.expand,
      children: [
        AdsNative(
          placement: widget.nativePlacement,
          loading:
              widget.nativeLoading ??
              AdsLoadingWidget(
                width: widget.width,
                height: widget.nativeHeight,
              ),
          error: widget.nativeError,
          errorBuilder: widget.nativeErrorBuilder,
          width: widget.width,
          height: widget.nativeHeight,
          showRetryButton: widget.showRetryButton,
          onLoaded: widget.onNativeLoaded,
          onFailed: widget.onNativeFailed,
          clearOnDispose: widget.nativeClearOnDispose,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _collapse,
            child: widget.closeButton ?? _DefaultCloseButton(),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsed() {
    return Container(
      color: widget.bannerBackgroundColor,
      alignment: widget.collapsedAlignment,
      child: AdsBanner(
        placement: widget.bannerPlacement,
        loading: widget.bannerLoading,
        error: widget.bannerError,
        errorBuilder: widget.bannerErrorBuilder,
        config: widget.bannerConfig,
        showRetryButton: widget.showRetryButton,
        onLoaded: widget.onBannerLoaded,
        onFailed: widget.onBannerFailed,
        clearOnDispose: widget.bannerClearOnDispose,
      ),
    );
  }

  void _collapse() {
    if (!_expanded) {
      return;
    }

    setState(() {
      _expanded = false;
    });
    widget.onCollapsed?.call();
  }
}

class _DefaultCloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(
        dimension: 28,
        child: Icon(Icons.expand_more_rounded),
      ),
    );
  }
}
