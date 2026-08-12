import 'package:flutter/widgets.dart';

import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_type.dart';
import '../../core/reload/ads_reload_notifier.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../app_ads.dart';
import '../../widgets/ads_loading_widget.dart';
import 'banner_ad_config.dart';

/// Widget that loads and renders a banner ad for an app-defined placement.
class AdsBanner extends StatefulWidget {
  /// Creates a banner widget.
  const AdsBanner({
    required this.placement,
    super.key,
    this.loading,
    this.error,
    this.errorBuilder,
    this.config = const BannerAdConfig.banner(),
    this.showRetryButton = false,
    this.onLoaded,
    this.onFailed,
    this.clearOnDispose = true,
  });

  /// Banner placement to render.
  final AdPlacement placement;

  /// Widget shown while the banner is loading.
  final Widget? loading;

  /// Widget shown when the banner fails to load.
  final Widget? error;

  /// Builder shown when the banner fails to load.
  ///
  /// Use [retry] to request the banner again.
  final Widget Function(BuildContext context, VoidCallback retry)? errorBuilder;

  /// Banner placeholder configuration.
  final BannerAdConfig config;

  /// Whether to show a small default retry button when loading fails.
  final bool showRetryButton;

  /// Called when this banner widget finishes loading successfully.
  final VoidCallback? onLoaded;

  /// Called when this banner widget fails to load.
  final void Function(AdFailure failure)? onFailed;

  /// Whether to clear the cached banner ad when this widget is disposed.
  final bool clearOnDispose;

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  Future<AdResult<void>>? _loadFuture;
  BannerAdConfig? _resolvedConfig;
  BannerAdConfig? _scheduledLoadConfig;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    AdsReloadNotifier.instance.addPlacementListener(_handlePlacementReload);
    AdsReloadNotifier.instance.addTypeListener(_handleTypeReload);
    if (!widget.config.needsResolvedWidth) {
      _resolvedConfig = widget.config;
      _loadFuture = _load(widget.config);
    }
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
  void didUpdateWidget(covariant AdsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final placementChanged = oldWidget.placement != widget.placement;
    if (placementChanged && oldWidget.clearOnDispose) {
      AppAds.clear(oldWidget.placement);
    }

    if (placementChanged || oldWidget.config != widget.config) {
      _resolvedConfig = null;
      _scheduledLoadConfig = null;
      if (widget.config.needsResolvedWidth) {
        _loadFuture = null;
      } else {
        _resolvedConfig = widget.config;
        _loadFuture = _load(widget.config);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedConfig = _resolveConfig(constraints);
        if (_resolvedConfig != resolvedConfig) {
          _resolvedConfig = resolvedConfig;
          _loadFuture = null;
          _scheduleLoad(resolvedConfig);
        }

        return FutureBuilder<AdResult<void>>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return widget.loading ??
                  AdsLoadingWidget(
                    width: resolvedConfig.resolvedWidth,
                    height: resolvedConfig.resolvedHeight,
                  );
            }

            final result = snapshot.data;
            if (result == null || result.isFailure) {
              return _buildError(context, resolvedConfig);
            }

            return AppAds.banner(widget.placement);
          },
        );
      },
    );
  }

  BannerAdConfig _resolveConfig(BoxConstraints constraints) {
    if (!widget.config.needsResolvedWidth) {
      return widget.config;
    }

    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;

    return widget.config.resolveWidth(width);
  }

  Future<AdResult<void>> _load(BannerAdConfig config) {
    final token = ++_loadToken;
    return AppAds.load(widget.placement, bannerConfig: config).then((result) {
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

  void _scheduleLoad(BannerAdConfig config) {
    if (_scheduledLoadConfig == config) {
      return;
    }

    _scheduledLoadConfig = config;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _resolvedConfig != config) {
        return;
      }

      _scheduledLoadConfig = null;
      setState(() {
        _loadFuture = _load(config);
      });
    });
  }

  void _retry() {
    _reload();
  }

  void _handlePlacementReload(AdPlacement placement) {
    if (placement == widget.placement) {
      _reload();
    }
  }

  void _handleTypeReload(AdType type) {
    if (type == widget.placement.type) {
      _reload();
    }
  }

  void _reload() {
    final resolvedConfig = _resolvedConfig;
    if (resolvedConfig == null || !mounted) {
      return;
    }

    setState(() {
      _loadFuture = _load(resolvedConfig);
    });
  }

  Widget _buildError(BuildContext context, BannerAdConfig config) {
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
      width: config.resolvedWidth,
      height: config.resolvedHeight,
      child: Center(
        child: GestureDetector(onTap: _retry, child: const Text('Retry ad')),
      ),
    );
  }
}
