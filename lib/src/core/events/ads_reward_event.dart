import 'ads_event.dart';

/// Event emitted when the user earns a reward.
class AdsRewardEvent extends AdsEvent {
  /// Creates an ads reward event.
  const AdsRewardEvent({
    required super.placement,
    required super.network,
    required this.amount,
    required this.rewardType,
  });

  /// Reward amount.
  final num amount;

  /// Reward type reported by the ad network.
  final String rewardType;
}
