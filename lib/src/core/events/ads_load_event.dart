import '../config/ad_placement.dart';
import '../enums/ad_load_status.dart';
import '../results/ad_failure.dart';

/// Emitted for progress/results of an explicit placement load operation.
class AdsLoadEvent {
  /// Creates an ads load event.
  const AdsLoadEvent({
    required this.placement,
    required this.status,
    this.failure,
  });

  /// Placement being loaded.
  final AdPlacement placement;

  /// Status reported by this load operation.
  ///
  /// This is an event payload, not a guaranteed snapshot of the placement cache
  /// after other flows such as show, clear, or internal preload.
  final AdLoadStatus status;

  /// Failure details when [status] is [AdLoadStatus.failed].
  final AdFailure? failure;
}
