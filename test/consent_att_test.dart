import 'package:core_ads/core_ads.dart';
import 'package:core_ads/src/consent/app_tracking_transparency_manager.dart';
import 'package:core_ads/src/core/logging/ads_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const manager = AppTrackingTransparencyManager();
  const logger = AdsLogger(enabled: false);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('ump mode leaves ATT to the UMP SDK', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final result = await manager.requestIfNeeded(
      config: const AdsConsentConfig(),
      logger: logger,
    );

    expect(result.isSuccess, isTrue);
  });

  test('disabled mode never requests ATT', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final result = await manager.requestIfNeeded(
      config: const AdsConsentConfig(
        trackingAuthorizationMode: AdsTrackingAuthorizationMode.disabled,
      ),
      logger: logger,
    );

    expect(result.isSuccess, isTrue);
  });

  test('fallback mode is skipped off iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final result = await manager.requestIfNeeded(
      config: const AdsConsentConfig(
        trackingAuthorizationMode:
            AdsTrackingAuthorizationMode.umpWithFallback,
      ),
      logger: logger,
    );

    expect(result.isSuccess, isTrue);
  });

  test('default config carries no UMP debug override', () {
    const config = AdsConsentConfig();

    expect(config.trackingAuthorizationMode, AdsTrackingAuthorizationMode.ump);
    expect(config.debugGeography, AdsConsentDebugGeography.disabled);
    expect(config.resetOnInitialize, isFalse);
    expect(config.resolvedTestDeviceIds, isEmpty);
  });

  test('resolvedTestDeviceIds keeps explicitly configured ids', () {
    const config = AdsConsentConfig(testDeviceIds: ['ABC123']);

    expect(config.resolvedTestDeviceIds, ['ABC123']);
  });
}
