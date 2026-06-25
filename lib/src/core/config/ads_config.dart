import '../enums/ad_network.dart';
import '../events/ads_callbacks.dart';
import '../fullscreen/fullscreen_ad_cooldown_config.dart';
import 'ads_consent_config.dart';
import 'ads_request_config.dart';
import 'ad_unit_ids.dart';
import 'ads_environment.dart';
import 'app_lovin_ads_config.dart';
import '../../ads/banner/banner_ad_config.dart';
import '../../ads/native/native_ad_config.dart';

/// Runtime configuration for the ads package.
class AdsConfig {
  /// Creates a configuration used to initialize the ads package.
  const AdsConfig({
    required this.environment,
    required this.adUnitIds,
    this.network = AdNetwork.google,
    this.consent = const AdsConsentConfig(),
    this.request = const AdsRequestConfig(),
    this.bannerAdConfigs = const BannerAdConfigs({}),
    this.nativeAdConfigs = const NativeAdConfigs({}),
    this.appLovin,
    this.fullscreenCooldown = const FullscreenAdCooldownConfig(),
    this.callbacks = const AdsCallbacks(),
    this.enableDebugLogs = false,
  });

  /// The active environment.
  final AdsEnvironment environment;

  /// The ad unit IDs used by the selected environment.
  final AdUnitIds adUnitIds;

  /// The ad network implementation to use internally.
  final AdNetwork network;

  /// Consent flow configuration.
  final AdsConsentConfig consent;

  /// Global ad request configuration.
  final AdsRequestConfig request;

  /// Banner ad size configuration by placement.
  final BannerAdConfigs bannerAdConfigs;

  /// Native ad rendering configuration by placement.
  final NativeAdConfigs nativeAdConfigs;

  /// AppLovin MAX specific configuration.
  final AppLovinAdsConfig? appLovin;

  /// Cooldown rules for fullscreen ads.
  final FullscreenAdCooldownConfig fullscreenCooldown;

  /// Lifecycle and analytics callbacks.
  final AdsCallbacks callbacks;

  /// Whether internal debug logging is enabled.
  final bool enableDebugLogs;

  /// Whether this config is using test behavior.
  bool get isTest => environment == AdsEnvironment.test;
}
