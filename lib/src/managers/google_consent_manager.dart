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

    if (!config.consent.enabled) {
      updateCanRequestAds(true);
      _logger.log('Consent flow disabled');
      return const AdResult.success(null);
    }

    try {
      if (config.consent.resetOnInitialize) {
        await ConsentInformation.instance.reset();
        _logger.log('Consent state reset');
      }

      await _requestConsentInfoUpdate(config.consent);

      final formError = await _loadAndShowConsentFormIfRequired();
      if (formError != null) {
        updateCanRequestAds(await ConsentInformation.instance.canRequestAds());
        return AdResult.failure(
          AdFailure(
            code: 'consent_form_error',
            message: formError.message,
            cause: formError,
          ),
        );
      }

      final canRequest = await ConsentInformation.instance.canRequestAds();
      updateCanRequestAds(canRequest);
      _logger.log('Consent canRequestAds=$canRequest');

      if (!canRequest) {
        return const AdResult.success(null);
      }

      final trackingResult = await trackingTransparencyManager.requestIfNeeded(
        config: config.consent,
        logger: _logger,
      );
      if (trackingResult.isFailure) {
        return trackingResult;
      }

      return const AdResult.success(null);
    } catch (error) {
      updateCanRequestAds(false);
      return AdResult.failure(
        AdFailure.unknown('Failed to request consent', error),
      );
    }
  }

  Future<void> _requestConsentInfoUpdate(AdsConsentConfig config) {
    final completer = Completer<void>();
    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: config.tagForUnderAgeOfConsent,
      consentDebugSettings: _debugSettings(config),
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
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
