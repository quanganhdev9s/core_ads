import 'ad_placement.dart';

/// Stores ad unit IDs by typed placement.
class AdUnitIds {
  /// Creates ad unit IDs grouped by app-defined placement.
  const AdUnitIds(this.values);

  /// Placement-to-ad-unit-id values.
  final Map<AdPlacement, String> values;

  /// Returns the ad unit ID for [placement], or null when it is not configured.
  String? idFor(AdPlacement placement) => values[placement];
}
