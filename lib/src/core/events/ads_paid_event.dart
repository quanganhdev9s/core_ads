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
  });

  /// Paid value in micros.
  final double valueMicros;

  /// Currency code, such as USD.
  final String currencyCode;

  /// Network-specific precision label.
  final String precision;
}
