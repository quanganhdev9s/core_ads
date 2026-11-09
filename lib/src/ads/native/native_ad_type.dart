import 'package:flutter/foundation.dart';

/// Các native factory và quy tắc tính chiều cao mặc định trong Flutter.
///
/// Big, Collap dạng mở rộng và Card trên iOS lấy tỷ lệ chiều cao màn hình.
/// Các loại `Full*` dùng toàn bộ vùng hiển thị do màn hình chứa ad quyết định.
enum NativeAdType {
  tiny1('Tiny1', 80),
  tiny2('Tiny2', 74),
  small1('Small1', 136, iosHeight: 138),
  small2('Small2', 138, iosHeight: 146, iosPadHeight: 166),
  small3('Small3', 136, iosHeight: 146, iosPadHeight: 166),
  small4('Small4', 130, iosHeight: 130),
  small5('Small5', 136, iosHeight: 146, iosPadHeight: 166),
  big1('Big1', null, screenHeightFraction: 0.36, iosScreenHeightFraction: 0.42),
  big2('Big2', null, screenHeightFraction: 0.36, iosScreenHeightFraction: 0.42),
  big3('Big3', null, screenHeightFraction: 0.36, iosScreenHeightFraction: 0.39),
  big4('Big4', null, screenHeightFraction: 0.36, iosScreenHeightFraction: 0.39),
  big5('Big5', null, screenHeightFraction: 0.36, iosScreenHeightFraction: 0.36),
  big6('Big6', null, screenHeightFraction: 0.36, iosScreenHeightFraction: 0.42),
  big7('Big7', null, screenHeightFraction: 0.33, iosScreenHeightFraction: 0.39),
  big8('Big8', null, screenHeightFraction: 0.33, iosScreenHeightFraction: 0.39),
  big9('Big9', null, screenHeightFraction: 0.30, iosScreenHeightFraction: 0.36),
  languageStart1('LanguageStart1', null, screenHeightFraction: 0.36),
  languageStart2('LanguageStart2', null, screenHeightFraction: 0.36),
  full1('Full1', null),
  full2('Full2', null),
  full3('Full3', null),
  full4('Full4', null),
  full5('Full5', null),
  collap1Expanded(
    'Collap1Expanded',
    null,
    screenHeightFraction: 0.36,
    iosScreenHeightFraction: 0.42,
  ),
  collap1Collapsed('Collap1Collapsed', 80),
  collap2Expanded(
    'Collap2Expanded',
    null,
    screenHeightFraction: 0.40,
    iosScreenHeightFraction: 0.40,
  ),
  collap2Collapsed('Collap2Collapsed', 74, iosHeight: 80),
  collap3Expanded(
    'Collap3Expanded',
    null,
    screenHeightFraction: 0.33,
    iosScreenHeightFraction: 0.40,
  ),
  collap3Collapsed('Collap3Collapsed', 80),
  card1('Card1', 240, iosScreenHeightFraction: 0.27),
  // Height metadata only; the Card2 native factory is not registered yet.
  card2('Card2', null, iosScreenHeightFraction: 0.27);

  const NativeAdType(
    this.factoryId,
    this.height, {
    this.screenHeightFraction,
    this.iosHeight,
    this.iosPadHeight,
    this.iosScreenHeightFraction,
  });

  /// ID đăng ký native factory trên Android/iOS.
  final String factoryId;

  /// Chiều cao cố định tính bằng logical pixel; `null` nếu dùng tỷ lệ hoặc Full.
  final double? height;

  /// Tỷ lệ chiều cao màn hình cho Big và Collap dạng mở rộng.
  final double? screenHeightFraction;

  /// Chiều cao cố định riêng trên iOS cho các layout Small.
  final double? iosHeight;

  /// Chiều cao cố định trên iPad khi layout có kích thước khác iPhone.
  final double? iosPadHeight;

  /// Tỷ lệ riêng trên iOS; nếu không khai báo sẽ dùng chiều cao Android.
  final double? iosScreenHeightFraction;

  /// Chiều cao mặc định theo chiều cao màn hình; Full trả về `null`.
  double? resolveHeight(
    double screenHeight, {
    TargetPlatform? platform,
    double? screenWidth,
  }) {
    if ((platform ?? defaultTargetPlatform) == TargetPlatform.iOS) {
      if (screenWidth != null && screenWidth >= 600 && iosPadHeight != null) {
        return iosPadHeight;
      }
      if (iosHeight != null) return iosHeight;
      if (iosScreenHeightFraction != null) {
        return screenHeight * iosScreenHeightFraction!;
      }
    }
    return height ??
        (screenHeightFraction == null
            ? null
            : screenHeight * screenHeightFraction!);
  }

  /// Factory nhỏ tương ứng khi native dạng Collap được thu gọn.
  NativeAdType? get collapsedType => switch (this) {
    NativeAdType.collap1Expanded => NativeAdType.collap1Collapsed,
    NativeAdType.collap2Expanded => NativeAdType.collap2Collapsed,
    NativeAdType.collap3Expanded => NativeAdType.collap3Collapsed,
    _ => null,
  };

  /// Tìm loại native theo factory ID lấy từ Remote Config hoặc placement.
  static NativeAdType? fromFactoryId(String? factoryId) {
    for (final type in values) {
      if (type.factoryId == factoryId) return type;
    }
    return null;
  }
}

/// Factory dự phòng theo vị trí hiển thị khi config không khai báo template.
abstract final class NativeAdFactoryDefaults {
  /// Native placement thông thường.
  static const native = NativeAdType.big1;

  /// Nhánh native của banner khi không dùng layout thu gọn.
  static const bannerNative = NativeAdType.small1;

  /// Nhánh native có thể thu gọn của banner.
  static const expandedCollapse = NativeAdType.collap1Expanded;

  /// Chỉ dùng khi factory lớn không có cặp layout nhỏ.
  static const collapsedCollapse = NativeAdType.small1;

  static const fullScreen = NativeAdType.full1;
  static const languageSmall = NativeAdType.tiny1;
}
