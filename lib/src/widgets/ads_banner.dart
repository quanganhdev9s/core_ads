import 'package:flutter/widgets.dart';

import '../core/config/ad_placement.dart';
import '../flutter_ads.dart';

/// Widget that renders a banner ad for an app-defined placement.
class AdsBanner extends StatelessWidget {
  /// Creates a banner widget.
  const AdsBanner({required this.placement, super.key});

  /// Banner placement to render.
  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    return FlutterAds.banner(placement);
  }
}
