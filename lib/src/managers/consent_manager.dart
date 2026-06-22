import '../core/results/ad_result.dart';

/// Manages user consent before ads are requested.
class ConsentManager {
  /// Creates a consent manager.
  ConsentManager({this.canRequestAds = true});

  /// Whether ads can currently be requested.
  bool canRequestAds;

  /// Requests or refreshes consent state.
  ///
  /// The current skeleton allows ads by default. Google UMP integration will
  /// replace this behavior in a later milestone.
  Future<AdResult<void>> requestConsent() async {
    canRequestAds = true;
    return const AdResult.success(null);
  }

  /// Overrides whether ads can be requested.
  void updateCanRequestAds(bool value) {
    canRequestAds = value;
  }
}
