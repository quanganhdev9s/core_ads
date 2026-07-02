import '../config/ad_placement.dart';
import '../enums/ad_load_status.dart';
import '../results/ad_failure.dart';

/// Emitted when a placement load state changes.
class AdsLoadEvent {
  /// Creates an ads load event.
  const AdsLoadEvent({
    required this.placement,
    required this.status,
    this.failure,
  });

  /// Placement whose load state changed.
  final AdPlacement placement;

  /// Current load status.
  final AdLoadStatus status;

  /// Failure details when [status] is [AdLoadStatus.failed].
  final AdFailure? failure;
}
