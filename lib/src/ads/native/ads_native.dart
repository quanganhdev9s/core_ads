import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_type.dart';
import '../../core/reload/ads_reload_notifier.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../app_ads.dart';
import 'native_ad_shimmer.dart';

/// Tải và hiển thị native ad của một [AdPlacement].
///
/// - Khi widget được tạo, [CoreAds.load] tải ad hoặc lấy ad đã có trong cache.
///   [onLoaded] chỉ báo tải thành công, chưa có nghĩa ad đã xuất hiện.
/// - Khi ad được vẽ trong route và vùng nhìn thấy, [onVisible] được gọi.
///   Nếu có [refreshRate], thời gian tải lại bắt đầu từ thời điểm này; timer
///   dừng khi ad khuất màn hình hoặc app không còn ở foreground.
/// - Hết [refreshRate], widget xóa ad hiện tại qua [CoreAds.clear]. Thông báo
///   reload từ CoreAds khiến widget tải ad mới và bắt đầu chu kỳ tiếp theo
///   sau khi ad mới xuất hiện. Lỗi tải hiển thị [error] hoặc [errorBuilder].
/// - `open_ad_on_clicks` không thuộc widget này. [AdsCollapsibleNative] nhận các
///   lần bấm cần bỏ qua qua `collapseClickCounts` và quản lý nút thu gọn.
class AdsNative extends StatefulWidget {
  /// Temporary visual aid for the example app. Disabled by default.
  static bool debugShowPlacementLabel = false;

  /// Creates a native ad widget.
  const AdsNative({
    required this.placement,
    super.key,
    this.loading,
    this.error,
    this.errorBuilder,
    this.width = double.infinity,
    this.height = 120,
    this.showRetryButton = false,
    this.onLoaded,
    this.onLoading,
    this.onVisible,
    this.onFailed,
    this.clearOnDispose = false,
    this.refreshRate,
  });

  /// Native ad placement to render.
  final AdPlacement placement;

  /// Widget shown while the native ad is loading.
  final Widget? loading;

  /// Widget shown when the native ad fails to load.
  final Widget? error;

  /// Builder shown when the native ad fails to load.
  ///
  /// Use [retry] to request the native ad again.
  final Widget Function(BuildContext context, VoidCallback retry)? errorBuilder;

  /// Loading placeholder width.
  final double width;

  /// Loading placeholder height.
  final double height;

  /// Whether to show a small default retry button when loading fails.
  final bool showRetryButton;

  /// Called when this native widget finishes loading successfully.
  final VoidCallback? onLoaded;

  /// Called whenever an initial load, retry, or refresh starts.
  final VoidCallback? onLoading;

  /// Called when the loaded native ad enters the visible viewport.
  final VoidCallback? onVisible;

  /// Called when this native widget fails to load.
  final void Function(AdFailure failure)? onFailed;

  /// Whether to clear the cached native ad when this widget is disposed.
  final bool clearOnDispose;

  /// Reloads while visible, measured from each successful render.
  final Duration? refreshRate;

  @override
  State<AdsNative> createState() => _AdsNativeState();
}

class _AdsNativeState extends State<AdsNative> with WidgetsBindingObserver {
  final GlobalKey _adKey = GlobalKey();
  Future<AdResult<void>>? _loadFuture;
  Timer? _refreshTimer;
  ScrollPosition? _scrollPosition;
  DateTime? _lastVisibleAt;
  bool _appResumed = true;
  bool _visibilityCheckScheduled = false;
  int _loadToken = 0;
  int _loadedToken = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appResumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    AdsReloadNotifier.instance.addPlacementListener(_handlePlacementReload);
    AdsReloadNotifier.instance.addTypeListener(_handleTypeReload);
    _loadFuture = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    AdsReloadNotifier.instance.removePlacementListener(_handlePlacementReload);
    AdsReloadNotifier.instance.removeTypeListener(_handleTypeReload);
    if (widget.clearOnDispose) {
      CoreAds.clear(widget.placement);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route becoming current can make an already loaded ad visible.
    ModalRoute.of(context);
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_scheduleVisibilityCheck);
      _scrollPosition = position;
      position?.addListener(_scheduleVisibilityCheck);
    }
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant AdsNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _refreshTimer?.cancel();
      _lastVisibleAt = null;
      _loadedToken = -1;
      if (oldWidget.clearOnDispose) {
        CoreAds.clear(oldWidget.placement);
      }
      _loadFuture = _load();
    } else if (oldWidget.refreshRate != widget.refreshRate) {
      if (oldWidget.refreshRate == null && widget.refreshRate != null &&
          _lastVisibleAt != null) {
        // Resume the refresh interval from when this ad becomes active again.
        _lastVisibleAt = DateTime.now();
      }
      _startRefreshTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (!_appResumed) {
      _refreshTimer?.cancel();
      _lastVisibleAt = null;
    } else {
      _scheduleVisibilityCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = FutureBuilder<AdResult<void>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loading ??
              NativeAdShimmer(
                factoryId: widget.placement.nativeFactoryId,
                width: widget.width,
                height: widget.height,
              );
        }

        if (snapshot.hasError) {
          return _buildError(context);
        }

        final result = snapshot.data;
        if (result == null || result.isFailure) {
          return _buildError(context);
        }

        return _NativePaintObserver(
          onPaint: () {
            if (_lastVisibleAt == null) _scheduleVisibilityCheck();
          },
          child: SizedBox(
            key: _adKey,
            width: widget.width,
            height: widget.height,
            child: CoreAds.nativeAd(widget.placement),
          ),
        );
      },
    );
    if (!AdsNative.debugShowPlacementLabel) return ad;
    return ad;
  }

  Future<AdResult<void>> _load() {
    final token = ++_loadToken;
    widget.onLoading?.call();
    return CoreAds.load(widget.placement).then((result) {
      if (!mounted || token != _loadToken) {
        return result;
      }

      switch (result) {
        case AdSuccess<void>():
          _loadedToken = token;
          widget.onLoaded?.call();
        case AdFailed<void>(failure: final failure):
          _refreshTimer?.cancel();
          _lastVisibleAt = null;
          widget.onFailed?.call(failure);
      }

      return result;
    });
  }

  void _retry() {
    if (!mounted) {
      return;
    }

    _refreshTimer?.cancel();
    _lastVisibleAt = null;
    _loadedToken = -1;
    setState(() {
      _loadFuture = _load();
    });
  }

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled || !mounted) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted) return;
      if (_loadedToken != _loadToken || !_isAdVisible()) {
        _refreshTimer?.cancel();
        _lastVisibleAt = null;
        return;
      }
      if (_lastVisibleAt != null) return;
      _lastVisibleAt = DateTime.now();
      widget.onVisible?.call();
      if (mounted && _loadedToken == _loadToken) _startRefreshTimer();
    });
  }

  bool _isAdVisible() {
    final adContext = _adKey.currentContext;
    final renderObject = adContext?.findRenderObject();
    if (!_appResumed ||
        adContext == null ||
        renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        !TickerMode.valuesOf(adContext).enabled ||
        ModalRoute.of(adContext)?.isCurrent == false) {
      return false;
    }

    var offstage = false;
    adContext.visitAncestorElements((element) {
      if (element.widget case Offstage(offstage: true)) {
        offstage = true;
        return false;
      }
      return true;
    });
    if (offstage) return false;

    final adBounds =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (adBounds.isEmpty) return false;
    final screenSize = MediaQuery.maybeSizeOf(adContext);
    if (screenSize != null && !adBounds.overlaps(Offset.zero & screenSize)) {
      return false;
    }
    final viewport = _scrollPosition?.context.storageContext.findRenderObject();
    if (viewport is RenderBox && viewport.hasSize) {
      final viewportBounds =
          viewport.localToGlobal(Offset.zero) & viewport.size;
      if (!adBounds.overlaps(viewportBounds)) return false;
    }
    return true;
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    final delay = widget.refreshRate;
    final lastVisibleAt = _lastVisibleAt;
    if (!_appResumed ||
        delay == null ||
        delay <= Duration.zero ||
        lastVisibleAt == null) {
      return;
    }
    final remaining = delay - DateTime.now().difference(lastVisibleAt);
    _refreshTimer = Timer(
      remaining > Duration.zero ? remaining : Duration.zero,
      () async {
        if (!mounted) return;
        if (!_isAdVisible()) {
          _lastVisibleAt = null;
          return;
        }
        await CoreAds.clear(widget.placement);
      },
    );
  }

  void _handlePlacementReload(AdPlacement placement) {
    if (placement == widget.placement) {
      _retry();
    }
  }

  void _handleTypeReload(AdType type) {
    if (type == widget.placement.type) {
      _retry();
    }
  }

  Widget _buildError(BuildContext context) {
    final errorBuilder = widget.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(context, _retry);
    }

    final error = widget.error;
    if (error != null) {
      return error;
    }

    if (!widget.showRetryButton) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: GestureDetector(onTap: _retry, child: const Text('Retry ad')),
      ),
    );
  }
}

class _NativePaintObserver extends SingleChildRenderObjectWidget {
  const _NativePaintObserver({required this.onPaint, required super.child});

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNativePaintObserver(onPaint);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderNativePaintObserver renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class _RenderNativePaintObserver extends RenderProxyBox {
  _RenderNativePaintObserver(this.onPaint);

  VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}
