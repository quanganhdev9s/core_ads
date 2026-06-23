import 'package:flutter/widgets.dart';

import '../../core/config/ad_placement.dart';
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
    this.config = const BannerAdConfig.banner(),
  });

  /// Banner placement to render.
  final AdPlacement placement;

  /// Widget shown while the banner is loading.
  final Widget? loading;

  /// Widget shown when the banner fails to load.
  final Widget? error;

  /// Banner placeholder configuration.
  final BannerAdConfig config;

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  Future<AdResult<void>>? _loadFuture;
  BannerAdConfig? _resolvedConfig;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load(widget.config);
  }

  @override
  void didUpdateWidget(covariant AdsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement ||
        oldWidget.config != widget.config) {
      _resolvedConfig = null;
      _loadFuture = _load(widget.config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedConfig = _resolveConfig(constraints);
        if (_resolvedConfig != resolvedConfig) {
          _resolvedConfig = resolvedConfig;
          _loadFuture = _load(resolvedConfig);
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
              return widget.error ?? const SizedBox.shrink();
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
    return AppAds.load(widget.placement, bannerConfig: config);
  }
}
