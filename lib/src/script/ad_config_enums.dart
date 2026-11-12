import '../ads/native/native_ad_type.dart';

/// Nút đóng native toàn màn hình trong luồng onboarding.
enum OnboardingFullCloseButtonStyle {
  x('x', false),
  next('next', true);

  const OnboardingFullCloseButtonStyle(this.key, this.textButton);

  final String key;
  final bool textButton;

  static OnboardingFullCloseButtonStyle fromJson(Object? value) =>
      value == x.key ? x : next;
}

/// Các key dùng để tìm và chuẩn hóa template từ ad config v2.
abstract final class AdConfigTemplateKeys {
  static const templates = 'ad_templates';
  static const placementTemplate = 'template';
  static const base = 'base';
  static const resolvedTemplate = 'native_template';
}

/// Nhóm placement nội bộ, suy ra từ tiền tố key trong config v2.
enum AdConfigType {
  splash('splash'),
  inter('inter'),
  banner('banner'),
  resume('resume'),
  native('native'),
  reward('reward'),
  rewardInter('reward_inter');

  const AdConfigType(this.key);
  final String key;

  /// Suy ra nhóm từ key; trả về null khi key không đúng quy ước đặt tên.
  static AdConfigType? fromPlacementKey(String key) {
    if (key == 'on_resume') return resume;
    if (key.startsWith('reward_inter_')) return rewardInter;
    if (key.startsWith('reward_')) return reward;
    if (key.startsWith('ads_')) return splash;
    if (key.startsWith('inter_')) return inter;
    if (key.startsWith('banner_')) return banner;
    if (key.startsWith('native_')) return native;
    return null;
  }

  bool get requiresFormat => switch (this) {
    native || reward || rewardInter => false,
    _ => true,
  };

  bool allows(AdConfigFormat format) => switch (this) {
    splash => switch (format) {
      AdConfigFormat.aoa ||
      AdConfigFormat.inter ||
      AdConfigFormat.interThenNativeFull => true,
      _ => false,
    },
    inter => switch (format) {
      AdConfigFormat.inter ||
      AdConfigFormat.nativeFull ||
      AdConfigFormat.interThenNativeFull => true,
      _ => false,
    },
    banner => switch (format) {
      AdConfigFormat.banner ||
      AdConfigFormat.bannerCollapsible ||
      AdConfigFormat.native ||
      AdConfigFormat.nativeCollapsible => true,
      _ => false,
    },
    resume =>
      format == AdConfigFormat.aoa || format == AdConfigFormat.welcomeBack,
    native || reward || rewardInter => false,
  };
}

/// Giá trị `format`; chỉ hợp lệ khi [AdConfigType.allows] trả về true.
enum AdConfigFormat {
  aoa('aoa'),
  inter('inter'),
  interThenNativeFull('inter_then_native_full'),
  nativeFull('native_full'),
  banner('banner'),
  bannerCollapsible('banner_collapsible'),
  native('native'),
  nativeCollapsible('native_collapsible'),
  welcomeBack('welcome_back');

  const AdConfigFormat(this.key);
  final String key;

  static AdConfigFormat parse(String value) => values.firstWhere(
    (format) => format.key == value,
    orElse: () => throw FormatException('Unknown ad format: $value'),
  );
}

/// Các template có sẵn trong tab `templates`.
///
/// Tên template tự tạo trong `ad_templates` là key động; các key trùng enum
/// có thể ghi đè style của factory mặc định.
enum AdConfigTemplate {
  big1('Big1'),
  big2('Big2'),
  big3('Big3'),
  big4('Big4'),
  big5('Big5'),
  big6('Big6'),
  big7('Big7'),
  big8('Big8'),
  big9('Big9'),
  small1('Small1'),
  small2('Small2'),
  small3('Small3'),
  small4('Small4'),
  small5('Small5'),
  tiny1('Tiny1'),
  tiny2('Tiny2'),
  collap1('Collap1'),
  collap2('Collap2'),
  collap3('Collap3'),
  full1('Full1'),
  full2('Full2'),
  full3('Full3'),
  full4('Full4'),
  full5('Full5'),
  card1('Card1'),
  languageStart1('LanguageStart1'),
  languageStart2('LanguageStart2');

  const AdConfigTemplate(this.key);
  final String key;

  String get factoryId => switch (this) {
    collap1 => NativeAdType.collap1Expanded.factoryId,
    collap2 => NativeAdType.collap2Expanded.factoryId,
    collap3 => NativeAdType.collap3Expanded.factoryId,
    _ => key,
  };

  static AdConfigTemplate? fromKey(String value) {
    for (final template in values) {
      if (template.key == value || template.factoryId == value) {
        return template;
      }
    }
    return null;
  }
}
