import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

import '../core/config/ads_consent_config.dart';
import '../core/logging/ads_logger.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';

/// Requests App Tracking Transparency authorization on iOS.
class AppTrackingTransparencyManager {
  /// Creates an ATT manager.
  const AppTrackingTransparencyManager();

  /// Requests ATT when enabled, running on iOS, and status is not determined.
  Future<AdResult<void>> requestIfNeeded({
    required AdsConsentConfig config,
    required AdsLogger logger,
  }) async {
    if (!config.requestTrackingAuthorizationOnIos) {
      logger.log('ATT request skipped: disabled');
      return const AdResult.success(null);
    }

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      logger.log('ATT request skipped: platform=${defaultTargetPlatform.name}');
      return const AdResult.success(null);
    }

    try {
      logger.log('ATT request started');
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      logger.log('ATT currentStatus=$status');

      if (status != TrackingStatus.notDetermined) {
        logger.log('ATT request completed: status=$status');
        return const AdResult.success(null);
      }

      if (config.trackingAuthorizationDelay > Duration.zero) {
        await Future<void>.delayed(config.trackingAuthorizationDelay);
      }

      final updatedStatus =
          await AppTrackingTransparency.requestTrackingAuthorization();
      logger.log('ATT request completed: status=$updatedStatus');

      return const AdResult.success(null);
    } catch (error) {
      logger.log('ATT request completed: failed');
      return AdResult.failure(
        AdFailure.unknown('Failed to request ATT authorization', error),
      );
    }
  }
}
