import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

import '../core/config/ads_consent_config.dart';
import '../core/logging/ads_logger.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';

/// Requests App Tracking Transparency authorization on iOS.
///
/// This is only the fallback path. With
/// [AdsTrackingAuthorizationMode.ump] the UMP SDK presents the ATT message
/// itself, right after the GDPR message, and this manager does nothing.
class AppTrackingTransparencyManager {
  /// Creates an ATT manager.
  const AppTrackingTransparencyManager();

  /// Requests ATT when the configured mode asks the app to do it directly,
  /// the platform is iOS, and UMP left the status undetermined.
  Future<AdResult<void>> requestIfNeeded({
    required AdsConsentConfig config,
    required AdsLogger logger,
  }) async {
    switch (config.trackingAuthorizationMode) {
      case AdsTrackingAuthorizationMode.ump:
        await _logStatus(logger, 'ATT owned by UMP');
        return const AdResult.success(null);
      case AdsTrackingAuthorizationMode.disabled:
        logger.log('ATT request skipped: disabled');
        return const AdResult.success(null);
      case AdsTrackingAuthorizationMode.umpWithFallback:
        break;
    }

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      logger.log('ATT request skipped: platform=${defaultTargetPlatform.name}');
      return const AdResult.success(null);
    }

    try {
      logger.log('ATT fallback started');
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      logger.log('ATT currentStatus=$status');

      if (status != TrackingStatus.notDetermined) {
        logger.log('ATT fallback completed: resolved by UMP, status=$status');
        return const AdResult.success(null);
      }

      if (config.trackingAuthorizationDelay > Duration.zero) {
        await Future<void>.delayed(config.trackingAuthorizationDelay);
      }

      final updatedStatus =
          await AppTrackingTransparency.requestTrackingAuthorization();
      logger.log('ATT fallback completed: status=$updatedStatus');

      return const AdResult.success(null);
    } catch (error) {
      logger.log('ATT fallback completed: failed');
      return AdResult.failure(
        AdFailure.unknown('Failed to request ATT authorization', error),
      );
    }
  }

  /// Reports the tracking status without prompting.
  ///
  /// This is the only way to tell why the UMP SDK did not present the ATT
  /// alert: `notDetermined` means UMP had no ATT message to show (publish one
  /// in the AdMob UI), anything else means the status was already resolved and
  /// iOS will never prompt again until the app is reinstalled.
  Future<void> _logStatus(AdsLogger logger, String reason) async {
    if (!logger.enabled) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      logger.log('$reason: skipped, platform=${defaultTargetPlatform.name}');
      return;
    }

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      logger.log('$reason: status=$status');
    } catch (error) {
      logger.log('$reason: status unavailable');
    }
  }
}
