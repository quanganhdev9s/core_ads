import 'package:flutter/widgets.dart';

import '../../core/config/ad_placement.dart';
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
    this.width = double.infinity,
    this.height = 120,
  });

  /// Native ad placement to render.
  final AdPlacement placement;

  /// Widget shown while the native ad is loading.
  final Widget? loading;

  /// Widget shown when the native ad fails to load.
  final Widget? error;

  /// Loading placeholder width.
  final double width;

  /// Loading placeholder height.
  final double height;

  @override
  State<AdsNative> createState() => _AdsNativeState();
}

class _AdsNativeState extends State<AdsNative> {
  Future<AdResult<void>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = AppAds.load(widget.placement);
  }

  @override
  void didUpdateWidget(covariant AdsNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _loadFuture = AppAds.load(widget.placement);
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
          return widget.error ?? const SizedBox.shrink();
        }

        final result = snapshot.data;
        if (result == null || result.isFailure) {
          return widget.error ?? const SizedBox.shrink();
        }

        return AppAds.nativeAd(widget.placement);
      },
    );
  }
}
