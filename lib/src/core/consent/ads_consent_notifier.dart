import '../events/ads_consent_event.dart';

/// Listener called when the consent request flow completes.
typedef AdsConsentListener = void Function(AdsConsentEvent event);

/// Notifies app UI when the consent request flow has completed.
class AdsConsentNotifier {
  AdsConsentNotifier._();

  /// Shared consent notifier.
  static final AdsConsentNotifier instance = AdsConsentNotifier._();

  final List<AdsConsentListener> _listeners = [];

  /// Adds a consent listener.
  void addListener(AdsConsentListener listener) {
    _listeners.add(listener);
  }

  /// Removes a consent listener.
  void removeListener(AdsConsentListener listener) {
    _listeners.remove(listener);
  }

  /// Notifies listeners that the consent request flow completed.
  void notify(AdsConsentEvent event) {
    for (final listener in List.of(_listeners)) {
      listener(event);
    }
  }
}
