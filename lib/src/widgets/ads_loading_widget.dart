import 'package:flutter/material.dart';

/// Default loading placeholder used while an ad placement is loading.
class AdsLoadingWidget extends StatelessWidget {
  /// Creates an ads loading widget.
  const AdsLoadingWidget({super.key, this.width = 320, this.height = 50});

  /// Placeholder width.
  final double width;

  /// Placeholder height.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
