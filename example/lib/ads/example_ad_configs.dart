import 'package:core_ads/core_ads.dart';

class ExampleAdConfigs {
  const ExampleAdConfigs._();

  static const banner = BannerAdConfig.anchoredAdaptive();

  static const collapsedBanner = BannerAdConfig.banner();

  static const native = NativeAdConfig(
    factoryId: 'example_native_factory',
    height: 260,
  );
}
