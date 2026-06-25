import 'package:flutter/widgets.dart';

/// Route observer used by ads widgets that react to navigation events.
class AdsRouteObserver {
  AdsRouteObserver._();

  /// Add this to `MaterialApp.navigatorObservers`.
  static final RouteObserver<PageRoute<dynamic>> instance =
      RouteObserver<PageRoute<dynamic>>();
}
