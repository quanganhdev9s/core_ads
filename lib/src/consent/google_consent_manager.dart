import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/ads_config.dart';
import '../core/config/ads_consent_config.dart';
import '../core/logging/ads_logger.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import 'app_tracking_transparency_manager.dart';
import 'consent_manager.dart';

/// Google UMP implementation of [ConsentManager].
///
/// The messages themselves live in the AdMob UI (Privacy & messaging). When a
/// GDPR message and an ATT message are both published for the app, the UMP SDK
/// presents the GDPR message first and the ATT alert second — the order Google
/// recommends — during [ConsentForm.loadAndShowConsentFormIfRequired]. The app
/// must not request ATT before that call, or the ATT message is skipped.
class GoogleConsentManager extends ConsentManager {
  /// Creates a Google consent manager.
  GoogleConsentManager({
    AppTrackingTransparencyManager? trackingTransparencyManager,
  }) : trackingTransparencyManager =
           trackingTransparencyManager ??
           const AppTrackingTransparencyManager();

  /// Handles iOS App Tracking Transparency requests.
  ///
  /// Only used by [AdsTrackingAuthorizationMode.umpWithFallback]; the default
  /// mode leaves ATT to the UMP SDK.
  final AppTrackingTransparencyManager trackingTransparencyManager;

  AdsLogger _logger = const AdsLogger(enabled: false);

  @override
  Future<AdResult<void>> requestConsent(AdsConfig config) async {
    _logger = AdsLogger(enabled: config.enableDebugLogs);
    _logger.log('Consent request started');

    if (!config.consent.enabled) {
      updateCanRequestAds(true);
      _logger.log('Consent request skipped: disabled');
      _logger.log('Consent final canRequestAds=true, result=success');
      return const AdResult.success(null);
    }

    try {
      if (config.consent.resetOnInitialize) {
        await ConsentInformation.instance.reset();
        _logger.log('Consent state reset');
      }

      final umpResult = await _requestConsentInfoUpdate(config.consent);
      if (umpResult.isFailure) {
        updateCanRequestAds(false);
        _logConsentResult(umpResult, canRequestAds: false);
        return umpResult;
      }

      await _logConsentState();

      final formError = await _loadAndShowConsentFormIfRequired();
      if (formError != null) {
        _logger.log(
          'Consent form failed: ${formError.errorCode} ${formError.message}',
        );
        final canRequest = await ConsentInformation.instance.canRequestAds();
        updateCanRequestAds(canRequest);

        if (canRequest) {
          _logger.log('Consent form error, but ads can still be requested');
          final trackingResult = await _requestTrackingIfNeeded(config.consent);
          _logConsentResult(trackingResult, canRequestAds: canRequest);
          return trackingResult;
        }
        final result = AdResult<void>.failure(
          AdFailure(
            code: 'consent_form_error',
            message: formError.message,
            cause: formError,
          ),
        );
        _logConsentResult(result, canRequestAds: canRequest);
        return result;
      }

      _logger.log('Consent form flow completed');
      await _logConsentState();

      final canRequest = await ConsentInformation.instance.canRequestAds();
      updateCanRequestAds(canRequest);

      if (!canRequest) {
        _logger.log('Consent final canRequestAds=false, result=success');
        return const AdResult.success(null);
      }

      final trackingResult = await _requestTrackingIfNeeded(config.consent);
      _logConsentResult(trackingResult, canRequestAds: canRequest);
      return trackingResult;
    } catch (error) {
      updateCanRequestAds(false);
      final result = AdResult<void>.failure(
        AdFailure.unknown('Failed to request consent', error),
      );
      _logConsentResult(result, canRequestAds: false);
      return result;
    }
  }

  /// Whether the app must expose a privacy options entry point.
  ///
  /// Required by the AdMob UI when a GDPR message is published, so the user can
  /// reopen the message and change their choice.
  static Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// Presents the privacy options form configured in the AdMob UI.
  static Future<AdResult<void>> showPrivacyOptionsForm() {
    final completer = Completer<AdResult<void>>();

    ConsentForm.showPrivacyOptionsForm((formError) {
      if (completer.isCompleted) return;
      if (formError == null) {
        completer.complete(const AdResult.success(null));
        return;
      }
      completer.complete(
        AdResult.failure(
          AdFailure(
            code: 'privacy_options_form_error',
            message: formError.message,
            cause: formError,
          ),
        ),
      );
    });

    return completer.future;
  }

  Future<void> _logConsentState() async {
    if (!_logger.enabled) return;

    final status = await ConsentInformation.instance.getConsentStatus();
    final formAvailable = await ConsentInformation.instance
        .isConsentFormAvailable();
    final privacyOptions = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    _logger.log(
      'Consent state status=$status formAvailable=$formAvailable '
      'privacyOptions=$privacyOptions',
    );
  }

  void _logConsentResult(AdResult<void> result, {required bool canRequestAds}) {
    switch (result) {
      case AdSuccess<void>():
        _logger.log(
          'Consent final canRequestAds=$canRequestAds, result=success',
        );
      case AdFailed<void>(failure: final failure):
        _logger.log(
          'Consent final canRequestAds=$canRequestAds, '
          'result=failed ${failure.code} ${failure.message}',
        );
    }
  }

  Future<AdResult<void>> _requestTrackingIfNeeded(
    AdsConsentConfig config,
  ) async {
    final trackingResult = await trackingTransparencyManager.requestIfNeeded(
      config: config,
      logger: _logger,
    );
    if (trackingResult.isFailure) {
      return trackingResult;
    }

    return const AdResult.success(null);
  }

  Future<AdResult<void>> _requestConsentInfoUpdate(AdsConsentConfig config) {
    _logger.log('UMP request started');
    final completer = Completer<AdResult<void>>();
    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: config.tagForUnderAgeOfConsent,
      consentDebugSettings: _debugSettings(config),
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        if (!completer.isCompleted) {
          _logger.log('UMP request completed: success');
          completer.complete(const AdResult.success(null));
        }
      },
      (error) {
        if (!completer.isCompleted) {
          _logger.log(
            'UMP request completed: failed ${error.errorCode} ${error.message}',
          );
          completer.complete(
            AdResult.failure(
              AdFailure(
                code: 'ump_request_failed',
                message: error.message,
                cause: error,
              ),
            ),
          );
        }
      },
    );

    return completer.future;
  }

  /// Loads and shows every message the AdMob UI has for this user.
  ///
  /// On iOS this covers the ATT message too, so the SDK owns the GDPR-then-ATT
  /// order and the app never prompts for ATT itself.
  Future<FormError?> _loadAndShowConsentFormIfRequired() {
    final completer = Completer<FormError?>();

    ConsentForm.loadAndShowConsentFormIfRequired((formError) {
      if (!completer.isCompleted) {
        completer.complete(formError);
      }
    });

    return completer.future;
  }

  ConsentDebugSettings? _debugSettings(AdsConsentConfig config) {
    final testDeviceIds = config.resolvedTestDeviceIds;
    if (config.debugGeography == AdsConsentDebugGeography.disabled &&
        testDeviceIds.isEmpty) {
      return null;
    }

    _logger.log(
      'UMP debug settings geography=${config.debugGeography.name} '
      'testDeviceIds=${testDeviceIds.length}',
    );

    return ConsentDebugSettings(
      debugGeography: _debugGeography(config.debugGeography),
      testIdentifiers: testDeviceIds.isEmpty ? null : testDeviceIds,
    );
  }

  DebugGeography? _debugGeography(AdsConsentDebugGeography geography) {
    return switch (geography) {
      AdsConsentDebugGeography.disabled =>
        DebugGeography.debugGeographyDisabled,
      AdsConsentDebugGeography.eea => DebugGeography.debugGeographyEea,
      AdsConsentDebugGeography.regulatedUsState =>
        DebugGeography.debugGeographyRegulatedUsState,
      AdsConsentDebugGeography.other => DebugGeography.debugGeographyOther,
    };
  }
}
