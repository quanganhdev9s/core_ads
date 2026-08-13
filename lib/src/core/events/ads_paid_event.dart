import 'ads_event.dart';

/// Event emitted when the ad network reports paid value.
class AdsPaidEvent extends AdsEvent {
  /// Creates an ads paid event.
  const AdsPaidEvent({
    required super.placement,
    required super.network,
    required this.valueMicros,
    required this.currencyCode,
    required this.precision,
    this.adUnitId = '',
    this.responseId,
    this.mediationAdapterClassName,
    this.adSourceName,
    this.adSourceId,
    this.adSourceInstanceName,
    this.adSourceInstanceId,
  });

  /// Ad unit ID that produced this paid event.
  final String adUnitId;

  /// Paid value in micros.
  final double valueMicros;

  /// Paid value converted from micros to the currency unit.
  double get value => valueMicros / 1000000;

  /// Alias for [value], useful when forwarding to ad revenue SDKs.
  double get revenue => value;

  /// Currency code, such as USD.
  final String currencyCode;

  /// Network-specific precision label.
  final String precision;

  /// AdMob response ID, when available.
  final String? responseId;

  /// Mediation adapter class name that loaded the ad, when available.
  final String? mediationAdapterClassName;

  /// Ad source name from the loaded adapter response, when available.
  final String? adSourceName;

  /// Ad source ID from the loaded adapter response, when available.
  final String? adSourceId;

  /// Ad source instance name from the loaded adapter response, when available.
  final String? adSourceInstanceName;

  /// Ad source instance ID from the loaded adapter response, when available.
  final String? adSourceInstanceId;
}
