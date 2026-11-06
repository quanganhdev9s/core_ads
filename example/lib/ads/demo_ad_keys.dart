import 'package:core_ads/core_ads.dart';

/// Key logic trong ba file JSON của example. Các màn chỉ dùng hằng số ở đây
/// khi gọi CoreAdSlot hoặc showScenario, tránh gõ sai tên placement.
/// [onResume] là key cấu hình trong settings, không phải placement quảng cáo.
abstract final class DemoAdKeys {
  // Splash.
  static const nativeSplash = 'native_splash';
  static const adsSplash = 'ads_splash';

  // Language.
  static const nativeLanguage = 'native_language';
  static const nativeLanguageSmall = 'native_language_small';
  static const interLanguage = 'inter_language';

  // Intro.
  static const nativeIntro = 'native_intro';
  static const nativeIntroFull = 'native_intro_full';
  static const nativeFullOnboarding = AdScenarioKeys.nativeFullOnboarding;
  static const interIntro = 'inter_intro';

  // Home và Get Start.
  static const interWelcomeBack = 'inter_welcome_back';
  static const nativeWelcomeBack = 'native_welcome_back';
  static const nativeGetStart = 'native_get_start';
  static const interStart = 'inter_start';
  static const bannerHome = 'banner_home';
  static const interHome = 'inter_home';
  static const onResume = 'on_resume';

  // Theme và Icon.
  static const nativeThemeSetup = 'native_theme_setup';
  static const rewardThemeSetup = 'reward_theme_setup';
  static const interIcon = 'inter_icon';
  static const rewardIconSetup = 'reward_icon_setup';
  static const nativeDialogIcon = 'native_dialog_icon';
  static const nativeIconSetup = 'native_icon_setup';
  static const rewardWidget = 'reward_widget';

  // Các màn còn lại.
  static const interCollection = 'inter_collection';
  static const bannerResult = 'banner_result';
  static const nativeResult = 'native_result';
  static const bannerWallpaper = 'banner_wallpaper';
  static const bannerSetting = 'banner_setting';
  static const interBack = 'inter_back';
}
