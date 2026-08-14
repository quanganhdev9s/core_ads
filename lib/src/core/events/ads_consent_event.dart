import '../results/ad_failure.dart';
import '../results/ad_result.dart';

/// Emitted when the consent request flow completes.
class AdsConsentEvent {
  /// Creates a consent completion event.
  const AdsConsentEvent({required this.result, required this.canRequestAds});

  /// Result returned by the consent flow.
  final AdResult<void> result;

  /// Whether ads can be requested after the consent flow completed.
  final bool canRequestAds;

  /// Failure details when [result] is a failure.
  AdFailure? get failure {
    final result = this.result;
    return switch (result) {
      AdFailed<void>(failure: final failure) => failure,
      AdSuccess<void>() => null,
    };
  }
}
