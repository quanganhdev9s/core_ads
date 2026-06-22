import 'package:flutter/widgets.dart';

import '../core/config/ad_placement.dart';
import '../flutter_ads.dart';

/// Observes app lifecycle and handles app open ads on resume.
class AdsAppLifecycleObserver with WidgetsBindingObserver {
  /// Creates an app lifecycle observer.
  AdsAppLifecycleObserver({
    required this.appOpenPlacement,
    WidgetsBinding? binding,
  }) : _binding = binding ?? WidgetsBinding.instance;

  /// App open placement to show when the app resumes.
  final AdPlacement appOpenPlacement;

  final WidgetsBinding _binding;
  bool _isAttached = false;

  /// Starts observing lifecycle events.
  void attach() {
    if (_isAttached) {
      return;
    }

    _binding.addObserver(this);
    _isAttached = true;
  }

  /// Stops observing lifecycle events.
  void detach() {
    if (!_isAttached) {
      return;
    }

    _binding.removeObserver(this);
    _isAttached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    FlutterAds.handleAppResume(appOpenPlacement);
  }
}
