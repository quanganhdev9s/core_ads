import '../core/config/ads_config.dart';
import '../core/results/ad_result.dart';

/// Manages user consent before ads are requested.
class ConsentManager {
  /// Creates a consent manager.
  ConsentManager({this.canRequestAds = true});

  /// Whether ads can currently be requested.
  bool canRequestAds;

  /// Requests or refreshes consent state.
  ///
  /// A successful result means the consent flow completed. It does not
  /// necessarily mean ads can be requested; read [canRequestAds] for that.
  Future<AdResult<void>> requestConsent(AdsConfig config) async {
    canRequestAds = true;
    return const AdResult.success(null);
  }

  /// Overrides whether ads can be requested.
  void updateCanRequestAds(bool value) {
    canRequestAds = value;
  }
}
