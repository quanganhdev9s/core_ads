import '../config/ad_placement.dart';
import '../enums/ad_type.dart';

/// Internal reload signal emitted when cached ads are cleared.
class AdsReloadNotifier {
  AdsReloadNotifier._();

  /// Shared internal notifier.
  static final AdsReloadNotifier instance = AdsReloadNotifier._();

  final List<void Function(AdPlacement placement)> _placementListeners = [];
  final List<void Function(AdType type)> _typeListeners = [];

  /// Adds a placement clear listener.
  void addPlacementListener(void Function(AdPlacement placement) listener) {
    _placementListeners.add(listener);
  }

  /// Removes a placement clear listener.
  void removePlacementListener(void Function(AdPlacement placement) listener) {
    _placementListeners.remove(listener);
  }

  /// Adds a type clear listener.
  void addTypeListener(void Function(AdType type) listener) {
    _typeListeners.add(listener);
  }

  /// Removes a type clear listener.
  void removeTypeListener(void Function(AdType type) listener) {
    _typeListeners.remove(listener);
  }

  /// Notifies listeners that [placement] should reload if visible.
  void notifyPlacement(AdPlacement placement) {
    for (final listener in List.of(_placementListeners)) {
      listener(placement);
    }
  }

  /// Notifies listeners that placements of [type] should reload if visible.
  void notifyType(AdType type) {
    for (final listener in List.of(_typeListeners)) {
      listener(type);
    }
  }
}
