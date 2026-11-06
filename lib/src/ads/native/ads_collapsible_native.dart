import 'package:flutter/material.dart';

import '../../ads/banner/ads_banner.dart';
import '../../ads/banner/banner_ad_config.dart';
import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_type.dart';
import '../../core/results/ad_failure.dart';
import 'ads_native.dart';
import 'native_ad_corner_control.dart';
import 'native_ad_shimmer.dart';

/// Hiển thị native ad và cho phép thu gọn thành banner hoặc native nhỏ.
///
/// Ad ở trạng thái mở rộng được tải qua [AdsNative]. Khi thu gọn, widget chuyển
/// sang [bannerPlacement] hoặc [collapsedNativePlacement] và tải ad tương ứng.
/// [nativeRefreshRate] chỉ áp dụng cho native đang mở rộng.
///
/// `collap_config` từ kịch bản ads được truyền vào [collapseClickCounts].
/// `_collapseTapCount` bắt đầu bằng 0. Mỗi lần người dùng bấm rồi nhả trên nút
/// collapse khi native đang mở rộng, bộ đếm tăng 1, kể cả lần bấm bị bỏ qua.
/// Lượt bấm thứ n được xét bằng `_collapseTapCount + 1` trước khi xử lý:
/// nếu n thuộc [collapseClickCounts], nút bỏ qua pointer, ad native bên dưới
/// nhận lượt bấm và widget vẫn mở rộng; nếu không, widget thu gọn và gọi
/// [onCollapsed]. Ví dụ `collap_config = 2`: lần 1 thu gọn; sau khi mở rộng lại
/// chính widget đó, lần 2 bị bỏ qua; lần 3 thu gọn. Chỉ bấm nút collapse mới
/// được tính. Bộ đếm giữ suốt vòng đời widget, đặt lại khi đổi native placement
/// hoặc tạo widget mới.
class AdsCollapsibleNative extends StatefulWidget {
  /// Creates a collapsible native ad.
  const AdsCollapsibleNative({
    required this.nativePlacement,
    super.key,
    this.bannerPlacement,
    this.collapsedNativePlacement,
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
    this.nativeRefreshRate,
    this.collapsedNativeHeight = 60,
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
    this.collapseClickCounts = const <int>{},
  });

  /// Native placement shown while expanded.
  final AdPlacement nativePlacement;

  /// Banner placement shown after collapse for `enable=2`.
  final AdPlacement? bannerPlacement;

  /// Small native placement shown after collapse for `enable=4`.
  final AdPlacement? collapsedNativePlacement;

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

  /// Reload interval for the expanded native, counted from its render.
  final Duration? nativeRefreshRate;

  /// Height of the small native shown after collapse.
  final double collapsedNativeHeight;

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

  /// Các lượt bấm nút collapse (đếm từ 1) được chuyển tới native bên dưới.
  /// Cả lượt bấm bị bỏ qua lẫn lượt thu gọn đều làm tăng bộ đếm của widget.
  final Set<int> collapseClickCounts;

  @override
  State<AdsCollapsibleNative> createState() => _AdsCollapsibleNativeState();
}

class _AdsCollapsibleNativeState extends State<AdsCollapsibleNative> {
  bool _expanded = true;
  bool _showCollapseButton = false;
  int _collapseTapCount = 0;
  final GlobalKey _closeButtonKey = GlobalKey();
  final Set<int> _ignoredPointers = <int>{};

  bool get _ignoreNextCollapseTap =>
      widget.collapseClickCounts.contains(_collapseTapCount + 1);

  @override
  void initState() {
    super.initState();
    assert(
      widget.nativePlacement.type == AdType.native,
      'nativePlacement must use AdType.native',
    );
    assert(
      (widget.bannerPlacement == null) !=
          (widget.collapsedNativePlacement == null),
      'Provide exactly one collapsed placement',
    );
    assert(
      widget.bannerPlacement == null ||
          widget.bannerPlacement!.type == AdType.banner,
    );
    assert(
      widget.collapsedNativePlacement == null ||
          widget.collapsedNativePlacement!.type == AdType.native,
    );
    _expanded = widget.expanded ?? true;
  }

  @override
  void didUpdateWidget(covariant AdsCollapsibleNative oldWidget) {
    super.didUpdateWidget(oldWidget);

    final expanded = widget.expanded;
    if (expanded != null && expanded != oldWidget.expanded) {
      _expanded = expanded;
      if (expanded) _showCollapseButton = false;
    }
    if (oldWidget.nativePlacement != widget.nativePlacement) {
      _collapseTapCount = 0;
      _ignoredPointers.clear();
      _showCollapseButton = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: _expanded
          ? widget.nativeHeight
          : widget.collapsedNativePlacement == null
          ? widget.bannerConfig.resolvedHeight
          : widget.collapsedNativeHeight,
      child: _expanded ? _buildExpanded() : _buildCollapsed(),
    );
  }

  Widget _buildExpanded() {
    return Listener(
      onPointerDown: _trackIgnoredPointerDown,
      onPointerUp: _trackIgnoredPointerUp,
      onPointerCancel: (event) => _ignoredPointers.remove(event.pointer),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AdsNative(
            placement: widget.nativePlacement,
            loading:
                widget.nativeLoading ??
                NativeAdShimmer(
                  factoryId: widget.nativePlacement.nativeFactoryId,
                  width: widget.width,
                  height: widget.nativeHeight,
                ),
            error: widget.nativeError,
            errorBuilder: widget.nativeErrorBuilder,
            width: widget.width,
            height: widget.nativeHeight,
            refreshRate: widget.nativeRefreshRate,
            showRetryButton: widget.showRetryButton,
            onLoading: _onExpandedLoading,
            onLoaded: _onExpandedLoaded,
            onFailed: _onExpandedFailed,
            clearOnDispose: widget.nativeClearOnDispose,
          ),
          if (_showCollapseButton)
            Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: _ignoreNextCollapseTap,
                child: NativeAdCornerControl(
                  key: _closeButtonKey,
                  onPressed: _collapse,
                  collapse: true,
                  child: widget.closeButton,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsed() {
    final collapsedNative = widget.collapsedNativePlacement;
    if (collapsedNative != null) {
      return Container(
        color: widget.bannerBackgroundColor,
        alignment: widget.collapsedAlignment,
        child: AdsNative(
          placement: collapsedNative,
          loading:
              widget.nativeLoading ??
              NativeAdShimmer(
                factoryId: collapsedNative.nativeFactoryId,
                width: widget.width,
                height: widget.collapsedNativeHeight,
              ),
          error: widget.nativeError,
          errorBuilder: widget.nativeErrorBuilder,
          width: widget.width,
          height: widget.collapsedNativeHeight,
          showRetryButton: widget.showRetryButton,
          onLoaded: widget.onNativeLoaded,
          onFailed: widget.onNativeFailed,
          clearOnDispose: widget.nativeClearOnDispose,
        ),
      );
    }
    return Container(
      color: widget.bannerBackgroundColor,
      alignment: widget.collapsedAlignment,
      child: AdsBanner(
        placement: widget.bannerPlacement!,
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

    _collapseTapCount++;

    setState(() {
      _expanded = false;
      _showCollapseButton = false;
    });
    widget.onCollapsed?.call();
  }

  void _onExpandedLoading() {
    if (mounted && _showCollapseButton) {
      setState(() => _showCollapseButton = false);
    }
  }

  void _onExpandedLoaded() {
    if (mounted && !_showCollapseButton) {
      setState(() => _showCollapseButton = true);
    }
    widget.onNativeLoaded?.call();
  }

  void _onExpandedFailed(AdFailure failure) {
    if (mounted && !_showCollapseButton) {
      setState(() => _showCollapseButton = true);
    }
    widget.onNativeFailed?.call(failure);
  }

  void _trackIgnoredPointerDown(PointerDownEvent event) {
    if (_ignoreNextCollapseTap && _isInsideCloseButton(event.position)) {
      _ignoredPointers.add(event.pointer);
    }
  }

  void _trackIgnoredPointerUp(PointerUpEvent event) {
    if (!_ignoredPointers.remove(event.pointer) ||
        !_isInsideCloseButton(event.position)) {
      return;
    }
    setState(() => _collapseTapCount++);
  }

  bool _isInsideCloseButton(Offset globalPosition) {
    final box = _closeButtonKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(globalPosition);
  }
}
