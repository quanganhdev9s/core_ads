import 'package:flutter/widgets.dart';

import '../core/config/ad_placement.dart';
import '../core/results/ad_result.dart';
import '../flutter_ads.dart';
import 'ads_loading_widget.dart';

/// Widget that loads and renders a banner ad for an app-defined placement.
class AdsBanner extends StatefulWidget {
  /// Creates a banner widget.
  const AdsBanner({
    required this.placement,
    super.key,
    this.loading,
    this.error,
    this.width = 320,
    this.height = 50,
  });

  /// Banner placement to render.
  final AdPlacement placement;

  /// Widget shown while the banner is loading.
  final Widget? loading;

  /// Widget shown when the banner fails to load.
  final Widget? error;

  /// Loading placeholder width.
  final double width;

  /// Loading placeholder height.
  final double height;

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  Future<AdResult<void>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = FlutterAds.load(widget.placement);
  }

  @override
  void didUpdateWidget(covariant AdsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _loadFuture = FlutterAds.load(widget.placement);
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

        final result = snapshot.data;
        if (result == null || result.isFailure) {
          return widget.error ?? const SizedBox.shrink();
        }

        return FlutterAds.banner(widget.placement);
      },
    );
  }
}
