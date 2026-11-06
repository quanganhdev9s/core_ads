import 'package:flutter/foundation.dart';

import 'native_ad_type.dart';

/// The layout shape shared by native factories and their loading placeholders.
enum NativeAdSkeletonKind {
  tiny,
  tinyCircle,
  small,
  smallIcon,
  big,
  bigButtonFirst,
  full,
  collapsible,
  card,
}

/// Flutter-side metadata for the factory IDs registered on Android and iOS.
///
/// Factory IDs, heights, and collapse pairs come from [NativeAdType].
final class NativeAdTemplate {
  const NativeAdTemplate._(this._type, this.skeletonKind, {this.dark = false})
    : _customFactoryId = null;

  const NativeAdTemplate._custom(this._customFactoryId)
    : _type = null,
      skeletonKind = NativeAdSkeletonKind.small,
      dark = false;

  final NativeAdType? _type;
  final String? _customFactoryId;

  /// ID của factory có sẵn hoặc ID riêng do app đăng ký.
  String get factoryId =>
      _type?.factoryId ?? _customFactoryId ?? NativeAdType.small1.factoryId;

  /// Fixed height in logical pixels; null for proportional and full-screen ads.
  double? get referenceHeight =>
      _type == null ? NativeAdType.small1.height : _type.height;

  /// Resolves the default height against the current screen height.
  double? heightForScreen(
    double screenHeight, {
    TargetPlatform? platform,
    double? screenWidth,
  }) => _type == null
      ? NativeAdType.small1.height
      : _type.resolveHeight(
          screenHeight,
          platform: platform,
          screenWidth: screenWidth,
        );

  final NativeAdSkeletonKind skeletonKind;
  final bool dark;

  String? get collapsedFactoryId => _type?.collapsedType?.factoryId;

  bool get isCollapsible => _type?.collapsedType != null;

  /// Chọn hình dạng shimmer theo type; ID tuỳ biến dùng dạng Small mặc định.
  static NativeAdTemplate forFactory(String? id) {
    final type = NativeAdType.fromFactoryId(id);
    if (type == null) return NativeAdTemplate._custom(id);

    final skeletonKind = switch (type) {
      NativeAdType.tiny1 ||
      NativeAdType.collap1Collapsed ||
      NativeAdType.collap3Collapsed => NativeAdSkeletonKind.tiny,
      NativeAdType.tiny2 ||
      NativeAdType.collap2Collapsed => NativeAdSkeletonKind.tinyCircle,
      NativeAdType.small1 ||
      NativeAdType.small2 ||
      NativeAdType.small4 => NativeAdSkeletonKind.small,
      NativeAdType.small3 ||
      NativeAdType.small5 => NativeAdSkeletonKind.smallIcon,
      NativeAdType.big5 ||
      NativeAdType.big6 ||
      NativeAdType.languageStart2 => NativeAdSkeletonKind.bigButtonFirst,
      NativeAdType.big1 ||
      NativeAdType.big2 ||
      NativeAdType.big3 ||
      NativeAdType.big4 ||
      NativeAdType.big7 ||
      NativeAdType.big8 ||
      NativeAdType.big9 => NativeAdSkeletonKind.big,
      NativeAdType.languageStart1 => NativeAdSkeletonKind.big,
      NativeAdType.full1 ||
      NativeAdType.full2 ||
      NativeAdType.full3 ||
      NativeAdType.full4 ||
      NativeAdType.full5 => NativeAdSkeletonKind.full,
      NativeAdType.collap1Expanded ||
      NativeAdType.collap2Expanded ||
      NativeAdType.collap3Expanded => NativeAdSkeletonKind.collapsible,
      NativeAdType.card1 || NativeAdType.card2 => NativeAdSkeletonKind.card,
    };
    return NativeAdTemplate._(
      type,
      skeletonKind,
      dark: type == NativeAdType.full2 || type == NativeAdType.full4,
    );
  }
}
