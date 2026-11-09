import 'package:core_ads/core_ads.dart';

/// Key logic trong config v2 của example. Các màn chỉ dùng hằng số ở đây
/// khi gọi CoreAdSlot hoặc showFullscreenAds, tránh gõ sai tên placement.
/// [onResume] là key cấu hình trong settings, không phải placement quảng cáo.
abstract final class DemoAdKeys {
  // Splash.
  static const nativeSplash = 'native_splash';
  static const adsSplash = 'ads_splash';

  // Language.
  static const nativeLanguage = 'native_language';
  static const nativeLanguage2 = 'native_language_2';
  static const nativeLanguageSmall = 'native_language_small';
  static const interLanguage = 'inter_language';
  static const interLanguageFallback = 'inter_language_fallback';

  // Intro.
  static const nativeOnboarding = 'native_onboarding';
  static const nativeFullOnboarding = AdScenarioKeys.nativeFullOnboarding;
  static const interOnboarding = 'inter_onboarding';
  static const nativeHomeFeed = 'native_home_feed';

  // Home và Get Start.
  static const nativeWelcomeBack = 'native_welcome_back';
  static const nativeGetStart = 'native_get_start';
  static const nativeGetStart2 = 'native_get_start_2';
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
  static const nativeSetting = 'native_setting';
  static const interBack = 'inter_back';

  // Các placement dành riêng cho màn kiểm thử cấu hình v2.
  static const adsTestAoa = 'ads_test_aoa';
  static const adsTestInter = 'ads_test_inter';
  static const interTestNativeFull = 'inter_test_native_full';
  static const bannerTestCollapsible = 'banner_test_collapsible';
  static const bannerTestNativeBanner = 'banner_test_native_banner';
  static const bannerTestNativeBannerCollapsible =
      'banner_test_native_banner_collapsible';
  static const bannerTestNative = 'banner_test_native';
  static const nativeTestCollap = 'native_test_collap';
  static const nativeTestDisabled = 'native_test_disabled';
  static const rewardTest = 'reward_test';
  static const rewardInterTest = 'reward_inter_test';
}
