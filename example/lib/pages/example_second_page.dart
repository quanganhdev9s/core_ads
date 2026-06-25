import 'package:flutter/material.dart';

class ExampleSecondPage extends StatelessWidget {
  const ExampleSecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second page')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to ads page'),
        ),
      ),
    );
  }
}
