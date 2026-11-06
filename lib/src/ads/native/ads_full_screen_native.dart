import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_ads.dart';
import '../../core/enums/ad_type.dart';
import '../../core/results/ad_failure.dart';
import '../../script/ad_scenario_coordinator.dart';
import 'ads_native.dart';
import 'native_ad_corner_control.dart';
import 'native_ad_template.dart';

/// Hiển thị native ad toàn màn hình của một bước trong kịch bản ads.
///
/// [AdsNative] tải ad; khi ad thật sự xuất hiện, `waitTime` bắt đầu đếm để
/// hiện nút đóng. Mỗi lần ad mới xuất hiện, `refreshRate` bắt đầu đếm để tải
/// lại trong lúc màn hình còn mở. Native phủ vùng Safe Area, nút đóng nằm đè
/// lên ad và nền màn hình cùng màu với template Full đang dùng. App quyết định
/// điều hướng qua [onClose].
class AdsFullScreenNative extends StatefulWidget {
  const AdsFullScreenNative({
    required this.step,
    required this.onClose,
    super.key,
    this.loading,
    this.error,
    this.closeButton,
    this.onVisible,
    this.onFailed,
  });

  final AdScenarioStep step;
  final VoidCallback onClose;
  final Widget? loading;
  final Widget? error;
  final Widget? closeButton;
  final VoidCallback? onVisible;
  final void Function(AdFailure failure)? onFailed;

  @override
  State<AdsFullScreenNative> createState() => _AdsFullScreenNativeState();
}

class _AdsFullScreenNativeState extends State<AdsFullScreenNative>
    with WidgetsBindingObserver {
  Timer? _closeTimer;
  Timer? _refreshTimer;
  bool _firstAdAppeared = false;
  bool _showClose = false;
  bool _appResumed = true;
  DateTime? _firstVisibleAt;
  DateTime? _lastVisibleAt;

  @override
  void initState() {
    super.initState();
    assert(widget.step.placement.type == AdType.native);
    WidgetsBinding.instance.addObserver(this);
    _appResumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(covariant AdsFullScreenNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.placement != widget.step.placement) {
      _closeTimer?.cancel();
      _refreshTimer?.cancel();
      _firstAdAppeared = false;
      _showClose = false;
      _firstVisibleAt = null;
      _lastVisibleAt = null;
    } else if (oldWidget.step.waitTime != widget.step.waitTime ||
        oldWidget.step.refreshRate != widget.step.refreshRate) {
      _closeTimer?.cancel();
      if (_firstAdAppeared && !_showClose) _startCloseTimer();
      if (_firstAdAppeared) _startRefreshTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (!_appResumed) {
      _refreshTimer?.cancel();
    } else if (_firstAdAppeared) {
      _lastVisibleAt = DateTime.now();
      _startRefreshTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = NativeAdTemplate.forFactory(
      widget.step.placement.nativeFactoryId,
    ).dark;
    final backgroundColor = dark
        ? const Color(0xFF1B1B1B)
        : const Color(0xFFFFFFFF);
    final overlayStyle =
        (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: backgroundColor,
              systemNavigationBarColor: backgroundColor,
              systemNavigationBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
            );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: ColoredBox(
        color: backgroundColor,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                AdsNative(
                  placement: widget.step.placement,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  loading: widget.loading,
                  error: widget.error,
                  clearOnDispose: true,
                  onVisible: _onNativeVisible,
                  onFailed: _onNativeFailed,
                ),
                if (_showClose)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: NativeAdCornerControl(
                      onPressed: widget.onClose,
                      collapse: false,
                      dark: dark,
                      child: widget.closeButton,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onNativeVisible() {
    if (!mounted) return;
    widget.onVisible?.call();
    final now = DateTime.now();
    _lastVisibleAt = now;
    if (!_firstAdAppeared) {
      _firstAdAppeared = true;
      _firstVisibleAt = now;
      _startCloseTimer();
    }
    _startRefreshTimer();
  }

  void _onNativeFailed(AdFailure failure) {
    _refreshTimer?.cancel();
    if (!_firstAdAppeared && !_showClose) {
      setState(() => _showClose = true);
    }
    widget.onFailed?.call(failure);
  }

  void _startCloseTimer() {
    final delay = widget.step.waitTime;
    final elapsed = DateTime.now().difference(_firstVisibleAt!);
    final remaining = delay == null ? Duration.zero : delay - elapsed;
    if (remaining <= Duration.zero) {
      setState(() => _showClose = true);
      return;
    }
    _closeTimer = Timer(remaining, () {
      if (mounted) setState(() => _showClose = true);
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    final delay = widget.step.refreshRate;
    if (!_appResumed || delay == null || delay <= Duration.zero) return;
    final elapsed = DateTime.now().difference(_lastVisibleAt!);
    final remaining = delay - elapsed;
    _refreshTimer = Timer(
      remaining > Duration.zero ? remaining : Duration.zero,
      () async {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent == false) {
          _lastVisibleAt = DateTime.now();
          _startRefreshTimer();
          return;
        }
        await CoreAds.clear(widget.step.placement);
      },
    );
  }
}
