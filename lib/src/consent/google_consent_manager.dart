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
class GoogleConsentManager extends ConsentManager {
  /// Creates a Google consent manager.
  GoogleConsentManager({
    AppTrackingTransparencyManager? trackingTransparencyManager,
  }) : trackingTransparencyManager =
           trackingTransparencyManager ??
           const AppTrackingTransparencyManager();

  /// Handles iOS App Tracking Transparency requests.
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

      final formError = await _loadAndShowConsentFormIfRequired();
      if (formError != null) {
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

  void _logConsentResult(AdResult<void> result, {required bool canRequestAds}) {
    switch (result) {
      case AdSuccess<void>():
        _logger.log(
          'Consent final canRequestAds=$canRequestAds, result=success',
        );
      case AdFailed<void>(failure: final failure):
        _logger.log(
          'Consent final canRequestAds=$canRequestAds, result=failed ${failure.code}',
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
          _logger.log('UMP request completed: failed ${error.errorCode}');
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
    if (config.debugGeography == AdsConsentDebugGeography.disabled &&
        config.testDeviceIds.isEmpty) {
      return null;
    }

    return ConsentDebugSettings(
      debugGeography: _debugGeography(config.debugGeography),
      testIdentifiers: config.testDeviceIds.isEmpty
          ? null
          : config.testDeviceIds,
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
