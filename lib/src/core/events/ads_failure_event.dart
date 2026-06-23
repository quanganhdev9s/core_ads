import '../results/ad_failure.dart';
import 'ads_event.dart';

/// Event emitted when an ad operation fails.
class AdsFailureEvent extends AdsEvent {
  /// Creates an ads failure event.
  const AdsFailureEvent({
    required super.placement,
    required super.network,
    required this.failure,
  });

  /// Failure details.
  final AdFailure failure;
}
