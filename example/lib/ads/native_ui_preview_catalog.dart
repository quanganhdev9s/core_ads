import 'package:core_ads/core_ads.dart';

import 'example_ad_unit_ids.dart';

/// Placement test cố định cho từng native factory, độc lập với Remote Config.
/// Card2 chỉ có metadata kích thước, chưa đăng ký factory Android/iOS.
abstract final class NativeUiPreviewCatalog {
  static final List<NativeAdType> types = List.unmodifiable(
    NativeAdType.values.where((type) => type != NativeAdType.card2),
  );

  static AdPlacement placementFor(NativeAdType type) => AdPlacement(
    key: 'native_preview.${type.factoryId}',
    type: AdType.native,
    nativeFactoryId: type.factoryId,
  );

  static AdScenarioStep stepFor(NativeAdType type) => AdScenarioStep(
    branch: 'native',
    placement: placementFor(type),
    ids: [ExampleAdUnitIds.native],
    collapseClickCounts: const <int>{},
  );

  static AdUnitIds withTestIds(AdUnitIds configuredIds) => AdUnitIds.typed({
    ...configuredIds.typedValues,
    for (final type in types)
      placementFor(type): AdUnitId.single(ExampleAdUnitIds.native),
  });
}
