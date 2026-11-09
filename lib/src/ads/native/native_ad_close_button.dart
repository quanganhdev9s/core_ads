import 'package:flutter/material.dart';

/// Nút đóng native ad. [dimension] là vùng chạm, biểu tượng tròn rộng 28 px.
class NativeAdCloseButton extends StatelessWidget {
  const NativeAdCloseButton({
    required this.onPressed,
    this.child,
    this.textButton = false,
    this.dimension = 48,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget? child;
  final bool textButton;
  final double dimension;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Close ad',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: textButton ? 56 : dimension,
        height: dimension,
        child: Center(
          child:
              child ??
              (textButton
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF017FE6),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const SizedBox(
                        width: 56,
                        height: 40,
                        child: Center(
                          child: Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x66000000),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 28,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    )),
        ),
      ),
    ),
  );
}
