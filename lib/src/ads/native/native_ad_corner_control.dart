import 'package:flutter/material.dart';

/// A 40px touch target with the compact control shown in native ad designs.
class NativeAdCornerControl extends StatelessWidget {
  const NativeAdCornerControl({
    required this.onPressed,
    required this.collapse,
    this.dark = false,
    this.child,
    super.key,
  });

  final VoidCallback onPressed;
  final bool collapse;
  final bool dark;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 40,
    child: Semantics(
      button: true,
      label: collapse ? 'Collapse ad' : 'Close ad',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Center(
          child:
              child ??
              DecoratedBox(
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF071B4D)
                      : const Color(0xFF999999),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 22,
                  child: Icon(
                    collapse ? Icons.keyboard_arrow_down_rounded : Icons.close,
                    size: collapse ? 16 : 12,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
}
