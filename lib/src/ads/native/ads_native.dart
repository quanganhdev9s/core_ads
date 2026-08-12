import 'package:flutter/widgets.dart';

import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_type.dart';
import '../../core/reload/ads_reload_notifier.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../app_ads.dart';
import '../../widgets/ads_loading_widget.dart';

/// Widget that loads and renders a native ad for an app-defined placement.
class AdsNative extends StatefulWidget {
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
    this.onFailed,
    this.clearOnDispose = true,
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

  /// Called when this native widget fails to load.
  final void Function(AdFailure failure)? onFailed;

  /// Whether to clear the cached native ad when this widget is disposed.
  final bool clearOnDispose;

  @override
  State<AdsNative> createState() => _AdsNativeState();
}

class _AdsNativeState extends State<AdsNative> {
  Future<AdResult<void>>? _loadFuture;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    AdsReloadNotifier.instance.addPlacementListener(_handlePlacementReload);
    AdsReloadNotifier.instance.addTypeListener(_handleTypeReload);
    _loadFuture = _load();
  }

  @override
  void dispose() {
    AdsReloadNotifier.instance.removePlacementListener(_handlePlacementReload);
    AdsReloadNotifier.instance.removeTypeListener(_handleTypeReload);
    if (widget.clearOnDispose) {
      AppAds.clear(widget.placement);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdsNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      if (oldWidget.clearOnDispose) {
        AppAds.clear(oldWidget.placement);
      }
      _loadFuture = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdResult<void>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loading ??
              AdsLoadingWidget(width: widget.width, height: widget.height);
        }

        if (snapshot.hasError) {
          return _buildError(context);
        }

        final result = snapshot.data;
        if (result == null || result.isFailure) {
          return _buildError(context);
        }

        return AppAds.nativeAd(widget.placement);
      },
    );
  }

  Future<AdResult<void>> _load() {
    final token = ++_loadToken;
    return AppAds.load(widget.placement).then((result) {
      if (!mounted || token != _loadToken) {
        return result;
      }

      switch (result) {
        case AdSuccess<void>():
          widget.onLoaded?.call();
        case AdFailed<void>(failure: final failure):
          widget.onFailed?.call(failure);
      }

      return result;
    });
  }

  void _retry() {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadFuture = _load();
    });
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
