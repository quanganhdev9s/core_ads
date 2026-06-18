import '../enums/ad_network.dart';
import 'ad_unit_ids.dart';
import 'ads_environment.dart';

/// Runtime configuration for the ads package.
class AdsConfig {
  /// Creates a configuration used to initialize the ads package.
  const AdsConfig({
    required this.environment,
    required this.adUnitIds,
    this.network = AdNetwork.google,
    this.enableDebugLogs = false,
  });

  /// The active environment.
  final AdsEnvironment environment;

  /// The ad unit IDs used by the selected environment.
  final AdUnitIds adUnitIds;

  /// The ad network implementation to use internally.
  final AdNetwork network;

  /// Whether internal debug logging is enabled.
  final bool enableDebugLogs;

  /// Whether this config is using test behavior.
  bool get isTest => environment == AdsEnvironment.test;
}
