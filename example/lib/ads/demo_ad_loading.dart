import 'package:flutter/material.dart';

/// UI chờ tải quảng cáo do app cung cấp cho kịch bản fullscreen.
class DemoAdLoading extends StatelessWidget {
  const DemoAdLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Đang tải quảng cáo...'),
      ],
    ),
  );
}
