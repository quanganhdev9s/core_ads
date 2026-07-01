import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Default loading placeholder used while an ad placement is loading.
class AdsLoadingWidget extends StatelessWidget {
  /// Creates an ads loading widget.
  const AdsLoadingWidget({super.key, this.width = double.infinity, this.height = 50});

  /// Placeholder width.
  final double width;

  /// Placeholder height.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      gradient: const LinearGradient(
        colors: [Colors.grey, Colors.white, Colors.grey],
      ),
      child: Container(width: width, height: height, color: Colors.grey),
    );
  }
}
