import '../core/enums/ad_load_status.dart';
import '../core/results/ad_result.dart';

/// Base contract for ad lifecycle managers.
abstract interface class AdManager {
  /// Current lifecycle status managed by this manager.
  AdLoadStatus get status;

  /// Whether this manager currently has an ad that can be shown.
  bool get canShow;

  /// Loads or preloads the ad managed by this manager.
  Future<AdResult<void>> load();

  /// Releases resources owned by this manager.
  Future<void> dispose();
}
