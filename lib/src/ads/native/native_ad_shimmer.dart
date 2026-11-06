import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'native_ad_template.dart';

/// A loading layout shaped like the selected native factory.
class NativeAdShimmer extends StatelessWidget {
  const NativeAdShimmer({
    required this.factoryId,
    required this.height,
    super.key,
    this.width = double.infinity,
  });

  final String? factoryId;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final template = NativeAdTemplate.forFactory(factoryId);
    final dark = template.dark;
    final fullScreen = template.skeletonKind == NativeAdSkeletonKind.full;
    final base = dark ? const Color(0xFF343434) : const Color(0xFFE7E9EC);
    final highlight = dark ? const Color(0xFF505050) : const Color(0xFFF8F9FA);
    final background = dark ? const Color(0xFF1B1B1B) : Colors.white;
    final outline = dark ? Colors.transparent : const Color(0xFFEBEBEB);
    final compactHeight = height < 100;
    final layout = height < 56
        ? null
        : compactHeight
        ? NativeAdSkeletonKind.tiny
        : template.skeletonKind;

    return Semantics(
      label: 'Loading native ad',
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: fullScreen ? null : BorderRadius.circular(12),
            border: fullScreen ? null : Border.all(color: outline),
          ),
          child: ClipRRect(
            borderRadius: fullScreen
                ? BorderRadius.zero
                : BorderRadius.circular(12),
            child: Shimmer(
              gradient: LinearGradient(
                colors: [base, highlight, base],
                stops: const [0.15, 0.5, 0.85],
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  template.skeletonKind == NativeAdSkeletonKind.full
                      ? 0
                      : compactHeight
                      ? 8
                      : 12,
                ),
                child: layout == null
                    ? _block(base, radius: 8)
                    : _layout(layout, base),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _layout(NativeAdSkeletonKind kind, Color color) => switch (kind) {
    NativeAdSkeletonKind.tiny => _tiny(color, circularButton: false),
    NativeAdSkeletonKind.tinyCircle => _tiny(color, circularButton: true),
    NativeAdSkeletonKind.small => _small(color),
    NativeAdSkeletonKind.smallIcon => _smallIcon(color),
    NativeAdSkeletonKind.big => _big(color),
    NativeAdSkeletonKind.bigButtonFirst => _big(color, buttonFirst: true),
    NativeAdSkeletonKind.full => _full(color),
    NativeAdSkeletonKind.collapsible => _collapsible(color),
    NativeAdSkeletonKind.card => _big(color, compact: true),
  };

  Widget _tiny(Color color, {required bool circularButton}) => Row(
    children: [
      _block(color, width: 40, height: 40, radius: 8),
      const SizedBox(width: 8),
      Expanded(child: _text(color, compact: true)),
      const SizedBox(width: 8),
      _block(color, width: circularButton ? 40 : 76, height: 40, radius: 20),
    ],
  );

  Widget _small(Color color) => Column(
    children: [
      Expanded(child: _info(color)),
      const SizedBox(height: 8),
      _block(color, height: 48, radius: 24),
    ],
  );

  Widget _smallIcon(Color color) => Row(
    children: [
      _block(color, width: 96, height: 96, radius: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          children: [
            Expanded(child: _text(color)),
            const SizedBox(height: 8),
            _block(color, height: 48, radius: 24),
          ],
        ),
      ),
    ],
  );

  Widget _big(Color color, {bool buttonFirst = false, bool compact = false}) =>
      Column(
        children: [
          if (buttonFirst) ...[
            _block(color, height: 48, radius: 24),
            const SizedBox(height: 8),
          ],
          Expanded(child: _block(color, radius: 8)),
          const SizedBox(height: 8),
          compact ? _text(color, compact: true) : _info(color),
          if (!buttonFirst) ...[
            const SizedBox(height: 8),
            _block(color, height: 48, radius: 24),
          ],
        ],
      );

  Widget _full(Color color) => Column(
    children: [
      Expanded(child: _block(color, radius: 0)),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _info(color),
            const SizedBox(height: 12),
            _block(color, height: 48, radius: 24),
          ],
        ),
      ),
    ],
  );

  Widget _collapsible(Color color) => Column(
    children: [
      Align(
        alignment: Alignment.topRight,
        child: _block(color, width: 24, height: 24, radius: 12),
      ),
      const SizedBox(height: 8),
      Expanded(child: _block(color, radius: 8)),
      const SizedBox(height: 8),
      _info(color),
      const SizedBox(height: 8),
      _block(color, height: 48, radius: 24),
    ],
  );

  Widget _info(Color color) => SizedBox(
    height: 48,
    child: Row(
      children: [
        _block(color, width: 48, height: 48, radius: 8),
        const SizedBox(width: 8),
        Expanded(child: _text(color)),
      ],
    ),
  );

  Widget _text(Color color, {bool compact = false}) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FractionallySizedBox(
        widthFactor: 0.82,
        alignment: Alignment.centerLeft,
        child: _block(color, height: compact ? 10 : 12, radius: 4),
      ),
      const SizedBox(height: 6),
      FractionallySizedBox(
        widthFactor: 0.58,
        alignment: Alignment.centerLeft,
        child: _block(color, height: compact ? 8 : 10, radius: 4),
      ),
    ],
  );

  Widget _block(
    Color color, {
    double? width,
    double? height,
    required double radius,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
