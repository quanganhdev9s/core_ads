/// Tên các thuộc tính style trong JSON và key truyền qua native factory.
abstract final class NativeAdStyleKeys {
  static const ctaBackground = 'cta_bg';
  static const ctaText = 'cta_text';
  static const ctaCornerDp = 'cta_corner_dp';
  static const cardBackground = 'card_bg';
  static const cardCornerDp = 'card_corner_dp';
  static const cardStroke = 'card_stroke';
  static const cardStrokeDp = 'card_stroke_dp';
  static const titleColor = 'title_color';
  static const bodyColor = 'body_color';
  static const ctaHeightDp = 'cta_height_dp';
  static const ctaTextSp = 'cta_text_sp';
  static const titleTextSp = 'title_text_sp';
  static const bodyTextSp = 'body_text_sp';
  static const mediaHeightDp = 'media_height_dp';
  static const iconSizeDp = 'icon_size_dp';
  static const cardPaddingDp = 'card_padding_dp';

  static const normalizedStyle = 'native_style';
  static const factoryOption = 'nativeStyle';
}

/// Các giá trị ghi đè từ tab `templates` cho một native placement.
final class NativeAdStyle {
  NativeAdStyle._(this.values);

  final Map<String, Object> values;

  static const _colors = {
    NativeAdStyleKeys.ctaBackground,
    NativeAdStyleKeys.ctaText,
    NativeAdStyleKeys.cardBackground,
    NativeAdStyleKeys.cardStroke,
    NativeAdStyleKeys.titleColor,
    NativeAdStyleKeys.bodyColor,
  };
  static const _numbers = <String, (num, num)>{
    NativeAdStyleKeys.ctaCornerDp: (0, 100),
    NativeAdStyleKeys.cardCornerDp: (0, 100),
    NativeAdStyleKeys.cardStrokeDp: (0, 16),
    NativeAdStyleKeys.ctaHeightDp: (28, 80),
    NativeAdStyleKeys.ctaTextSp: (10, 24),
    NativeAdStyleKeys.titleTextSp: (10, 28),
    NativeAdStyleKeys.bodyTextSp: (9, 22),
    NativeAdStyleKeys.mediaHeightDp: (120, 400),
    NativeAdStyleKeys.iconSizeDp: (24, 96),
    NativeAdStyleKeys.cardPaddingDp: (0, 32),
  };

  /// Giá trị số vượt giới hạn được kéo về biên gần nhất. Giá trị sai kiểu
  /// hoặc sai định dạng màu bị bỏ qua để template con kế thừa từ base.
  static NativeAdStyle? fromJson(Map<String, Object?> raw) {
    final parsed = <String, Object>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (_colors.contains(key) &&
          value is String &&
          RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value)) {
        parsed[key] = value;
      } else if (_numbers[key] case final range?) {
        if (value is num && value.isFinite) {
          parsed[key] = value.clamp(range.$1, range.$2);
        }
      }
    }
    if (parsed.isEmpty) return null;
    return NativeAdStyle._(Map.unmodifiable(parsed));
  }
}
