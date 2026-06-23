import '../config/ad_placement.dart';
import '../enums/ad_network.dart';
import '../enums/ad_type.dart';

/// Base event emitted by the ads package.
class AdsEvent {
  /// Creates an ads event.
  const AdsEvent({required this.placement, required this.network});

  /// Placement associated with the event.
  final AdPlacement placement;

  /// Ad network that emitted the event.
  final AdNetwork network;

  /// Ad format associated with the placement.
  AdType get type => placement.type;
}
