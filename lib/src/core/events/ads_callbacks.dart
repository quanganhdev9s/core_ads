import 'ads_event.dart';
import 'ads_failure_event.dart';
import 'ads_paid_event.dart';
import 'ads_reward_event.dart';

/// Lifecycle and analytics callbacks emitted by the ads package.
class AdsCallbacks {
  /// Creates ads callbacks.
  const AdsCallbacks({
    this.onLoaded,
    this.onFailed,
    this.onShown,
    this.onDismissed,
    this.onClicked,
    this.onImpression,
    this.onPaid,
    this.onRewardEarned,
  });

  /// Called when an ad is loaded.
  final void Function(AdsEvent event)? onLoaded;

  /// Called when an ad fails to load or show.
  final void Function(AdsFailureEvent event)? onFailed;

  /// Called when a fullscreen ad is shown.
  final void Function(AdsEvent event)? onShown;

  /// Called when a fullscreen ad is dismissed.
  final void Function(AdsEvent event)? onDismissed;

  /// Called when an ad is clicked.
  final void Function(AdsEvent event)? onClicked;

  /// Called when an ad impression is recorded.
  final void Function(AdsEvent event)? onImpression;

  /// Called when paid value is reported.
  final void Function(AdsPaidEvent event)? onPaid;

  /// Called when the user earns a reward.
  final void Function(AdsRewardEvent event)? onRewardEarned;
}
