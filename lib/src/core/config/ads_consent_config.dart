/// Consent configuration used before ads are requested.
class AdsConsentConfig {
  /// Creates consent configuration.
  const AdsConsentConfig({
    this.enabled = true,
    this.tagForUnderAgeOfConsent,
    this.debugGeography = AdsConsentDebugEnvironment.debugGeography,
    this.testDeviceIds = const <String>[],
    this.resetOnInitialize = AdsConsentDebugEnvironment.resetOnInitialize,
    this.trackingAuthorizationMode = AdsTrackingAuthorizationMode.ump,
    this.trackingAuthorizationDelay = const Duration(milliseconds: 1000),
  });

  /// Whether consent flow should run during initialization.
  ///
  /// Disabling this skips the whole UMP flow, which on iOS also skips the ATT
  /// message the UMP SDK would have presented.
  final bool enabled;

  /// Whether the user should be tagged as under the age of consent.
  final bool? tagForUnderAgeOfConsent;

  /// Debug geography used for consent testing.
  ///
  /// Defaults to `--dart-define=ADS_CONSENT_DEBUG_GEOGRAPHY=<value>`, so a
  /// build can force the EEA experience without a code change. Only applies to
  /// test devices; emulators and simulators are always test devices.
  final AdsConsentDebugGeography debugGeography;

  /// Device IDs allowed to use consent debug settings.
  ///
  /// Merged with `--dart-define=ADS_CONSENT_TEST_DEVICE_IDS=id1,id2`. Read
  /// [resolvedTestDeviceIds] instead of this field when building UMP settings.
  final List<String> testDeviceIds;

  /// Whether to reset cached consent state during initialization.
  ///
  /// This should only be used for testing. Defaults to
  /// `--dart-define=ADS_CONSENT_RESET=true`.
  final bool resetOnInitialize;

  /// How App Tracking Transparency is requested on iOS.
  ///
  /// Defaults to [AdsTrackingAuthorizationMode.ump]: the UMP SDK presents the
  /// GDPR message first and the ATT message second, as recommended by Google,
  /// as long as both messages are published in the AdMob UI.
  final AdsTrackingAuthorizationMode trackingAuthorizationMode;

  /// Delay before requesting ATT directly.
  ///
  /// Only used by [AdsTrackingAuthorizationMode.umpWithFallback]. This helps
  /// avoid presenting two native dialogs too close together.
  final Duration trackingAuthorizationDelay;

  /// Test device IDs from this config plus the ones passed by dart-define.
  List<String> get resolvedTestDeviceIds => <String>[
    ...testDeviceIds,
    ...AdsConsentDebugEnvironment.testDeviceIds,
  ];
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

/// How the package obtains iOS App Tracking Transparency authorization.
enum AdsTrackingAuthorizationMode {
  /// The UMP SDK presents the ATT message.
  ///
  /// Configure both the GDPR message and the ATT message in the AdMob UI
  /// (Privacy & messaging). The SDK then shows the GDPR message first and the
  /// ATT alert second, and the app never calls ATT itself. This is Google's
  /// recommended setup.
  ump,

  /// Like [ump], but the app requests ATT itself when the UMP flow left the
  /// tracking status undetermined.
  ///
  /// Useful while an ATT message is not published in the AdMob UI yet. The
  /// fallback is skipped whenever UMP already resolved the status, so it never
  /// double-prompts.
  umpWithFallback,

  /// Never request ATT from this package.
  disabled,
}

/// Consent debug switches read from `--dart-define` at compile time.
///
/// These exist so consent can be exercised on a debug build without editing
/// the host app's ads configuration.
abstract final class AdsConsentDebugEnvironment {
  /// Raw `ADS_CONSENT_DEBUG_GEOGRAPHY` value.
  ///
  /// Accepts `eea`, `regulated_us_state`, `other`, or `disabled`.
  static const String debugGeographyName = String.fromEnvironment(
    'ADS_CONSENT_DEBUG_GEOGRAPHY',
  );

  /// Geography override applied to test devices.
  static const AdsConsentDebugGeography debugGeography =
      debugGeographyName == 'eea'
      ? AdsConsentDebugGeography.eea
      : debugGeographyName == 'regulated_us_state'
      ? AdsConsentDebugGeography.regulatedUsState
      : debugGeographyName == 'other'
      ? AdsConsentDebugGeography.other
      : AdsConsentDebugGeography.disabled;

  /// Whether cached consent is cleared on every initialization.
  static const bool resetOnInitialize = bool.fromEnvironment(
    'ADS_CONSENT_RESET',
  );

  /// Raw comma-separated `ADS_CONSENT_TEST_DEVICE_IDS` value.
  static const String testDeviceIdsValue = String.fromEnvironment(
    'ADS_CONSENT_TEST_DEVICE_IDS',
  );

  /// Test device IDs passed by dart-define.
  static List<String> get testDeviceIds => testDeviceIdsValue
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}
