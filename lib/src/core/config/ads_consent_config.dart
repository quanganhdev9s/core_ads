/// Consent configuration used before ads are requested.
class AdsConsentConfig {
  /// Creates consent configuration.
  const AdsConsentConfig({
    this.enabled = true,
    this.tagForUnderAgeOfConsent,
    this.debugGeography = AdsConsentDebugGeography.disabled,
    this.testDeviceIds = const <String>[],
    this.resetOnInitialize = false,
    this.requestTrackingAuthorizationOnIos = true,
    this.trackingAuthorizationDelay = const Duration(milliseconds: 1000),
  });

  /// Whether consent flow should run during initialization.
  final bool enabled;

  /// Whether the user should be tagged as under the age of consent.
  final bool? tagForUnderAgeOfConsent;

  /// Debug geography used for consent testing.
  final AdsConsentDebugGeography debugGeography;

  /// Device IDs allowed to use consent debug settings.
  final List<String> testDeviceIds;

  /// Whether to reset cached consent state during initialization.
  ///
  /// This should only be used for testing.
  final bool resetOnInitialize;

  /// Whether ATT should be requested on iOS after consent allows ads.
  final bool requestTrackingAuthorizationOnIos;

  /// Delay before requesting ATT after the consent form is dismissed.
  ///
  /// This helps avoid presenting two native dialogs too close together.
  final Duration trackingAuthorizationDelay;
}

/// Debug geography options for consent testing.
enum AdsConsentDebugGeography {
  /// Do not override geography.
  disabled,

  /// Treat debug devices as in the EEA.
  eea,

  /// Treat debug devices as in a regulated US state.
  regulatedUsState,

  /// Treat debug devices as outside regulated regions.
  other,
}
