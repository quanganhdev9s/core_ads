import 'ad_placement.dart';

/// Ad unit ID configuration for a placement.
class AdUnitId {
  /// Creates a single ad unit ID.
  const AdUnitId.single(this.id) : waterfallIds = null;

  /// Creates a waterfall of ad unit IDs.
  const AdUnitId.waterfall(this.waterfallIds) : id = null;

  /// Single ad unit ID.
  final String? id;

  /// Ordered fallback ad unit IDs.
  final List<String>? waterfallIds;

  /// Ordered IDs used when loading an ad.
  List<String> get ids {
    final id = this.id;
    if (id != null) {
      return [id];
    }

    return List.unmodifiable(waterfallIds ?? const <String>[]);
  }
}

/// Stores ad unit IDs by typed placement.
class AdUnitIds {
  /// Creates ad unit IDs grouped by app-defined placement.
  AdUnitIds(Map<AdPlacement, String> values)
    : values = Map.unmodifiable(values),
      typedValues = values.map(
        (placement, id) => MapEntry(placement, AdUnitId.single(id)),
      );

  /// Creates ad unit IDs grouped by placement with waterfall support.
  AdUnitIds.typed(Map<AdPlacement, AdUnitId> values)
    : typedValues = Map.unmodifiable(values),
      values = Map.unmodifiable(
        Map.fromEntries(
          values.entries
              .where((entry) => entry.value.ids.isNotEmpty)
              .map((entry) => MapEntry(entry.key, entry.value.ids.first)),
        ),
      );

  /// Placement-to-ad-unit-id values.
  ///
  /// For waterfall placements, this contains the first ID in the waterfall.
  final Map<AdPlacement, String> values;

  /// Placement-to-ad-unit-id values with waterfall support.
  final Map<AdPlacement, AdUnitId> typedValues;

  /// Returns the ad unit ID for [placement], or null when it is not configured.
  String? idFor(AdPlacement placement) {
    final ids = idsFor(placement);
    if (ids.isEmpty) {
      return null;
    }

    return ids.first;
  }

  /// Returns the ordered ad unit IDs for [placement].
  List<String> idsFor(AdPlacement placement) {
    return typedValues[placement]?.ids ?? const <String>[];
  }
}
