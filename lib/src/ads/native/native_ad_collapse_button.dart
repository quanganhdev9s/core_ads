import 'package:flutter/material.dart';

/// Nút thu gọn native ad với vùng chạm 40 px và biểu tượng 22 px.
class NativeAdCollapseButton extends StatelessWidget {
  const NativeAdCollapseButton({
    required this.onPressed,
    this.child,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 40,
    child: Semantics(
      button: true,
      label: 'Collapse ad',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Center(
          child:
              child ??
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 22,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
        ),
      ),
    ),
  );
}
