import '../../core/config/ad_placement.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Supported fixed banner sizes.
enum BannerAdSize {
  /// Standard 320x50 banner.
  banner,

  /// Large 320x100 banner.
  largeBanner,

  /// Medium rectangle 300x250 banner.
  mediumRectangle,

  /// Full banner 468x60.
  fullBanner,

  /// Leaderboard 728x90.
  leaderboard,

  /// Anchored adaptive banner with app-provided width.
  anchoredAdaptive,
}

/// Banner ad rendering configuration for one placement.
class BannerAdConfig {
  /// Creates banner ad configuration.
  const BannerAdConfig({
    this.size = BannerAdSize.banner,
    this.width,
    this.height,
  });

  /// Creates a standard 320x50 banner config.
  const BannerAdConfig.banner() : this(size: BannerAdSize.banner);

  /// Creates a large 320x100 banner config.
  const BannerAdConfig.largeBanner() : this(size: BannerAdSize.largeBanner);

  /// Creates a medium rectangle 300x250 banner config.
  const BannerAdConfig.mediumRectangle()
    : this(size: BannerAdSize.mediumRectangle);

  /// Creates a full 468x60 banner config.
  const BannerAdConfig.fullBanner() : this(size: BannerAdSize.fullBanner);

  /// Creates a leaderboard 728x90 banner config.
  const BannerAdConfig.leaderboard() : this(size: BannerAdSize.leaderboard);

  /// Creates an anchored adaptive banner config.
  const BannerAdConfig.anchoredAdaptive({double? width, double? height})
    : this(size: BannerAdSize.anchoredAdaptive, width: width, height: height);

  /// Whether this config needs the widget to resolve its runtime width.
  bool get needsResolvedWidth =>
      size == BannerAdSize.anchoredAdaptive && width == null;

  /// Returns this config with [width] when an adaptive width is not set yet.
  BannerAdConfig resolveWidth(double width) {
    if (!needsResolvedWidth) {
      return this;
    }

    return BannerAdConfig.anchoredAdaptive(width: width, height: height);
  }

  /// Fixed banner size used by the ad network.
  final BannerAdSize size;

  /// Optional widget width override used by loading/error placeholders.
  final double? width;

  /// Optional widget height override used by loading/error placeholders.
  final double? height;

  /// Default logical width for the configured fixed size.
  double get defaultWidth {
    return switch (size) {
      BannerAdSize.banner => 320,
      BannerAdSize.largeBanner => 320,
      BannerAdSize.mediumRectangle => 300,
      BannerAdSize.fullBanner => 468,
      BannerAdSize.leaderboard => 728,
      BannerAdSize.anchoredAdaptive => width ?? 320,
    };
  }

  /// Default logical height for the configured fixed size.
  double get defaultHeight {
    return switch (size) {
      BannerAdSize.banner => 50,
      BannerAdSize.largeBanner => 100,
      BannerAdSize.mediumRectangle => 250,
      BannerAdSize.fullBanner => 60,
      BannerAdSize.leaderboard => 90,
      BannerAdSize.anchoredAdaptive => height ?? 50,
    };
  }

  /// Widget width used by default placeholders.
  double get resolvedWidth => width ?? defaultWidth;

  /// Widget height used by default placeholders.
  double get resolvedHeight => height ?? defaultHeight;

  /// Resolves the exact Google anchored adaptive banner height for [width].
  ///
  /// This calls the Google Mobile Ads SDK. It is intended for
  /// [BannerAdSize.anchoredAdaptive]; other banner sizes return
  /// [heightForWidth].
  Future<double?> googleAnchoredAdaptiveHeightForWidth(double width) async {
    if (height != null) {
      return height!;
    }

    if (!width.isFinite || width <= 0) {
      return null;
    }

    final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      width.round(),
    );
    return adSize?.height.toDouble();
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BannerAdConfig &&
            other.size == size &&
            other.width == width &&
            other.height == height;
  }

  @override
  int get hashCode => Object.hash(size, width, height);
}

/// Banner ad configuration grouped by placement.
class BannerAdConfigs {
  /// Creates banner ad configurations.
  const BannerAdConfigs(this.values);

  /// Placement-to-banner-config values.
  final Map<AdPlacement, BannerAdConfig> values;

  /// Returns banner config for [placement].
  BannerAdConfig configFor(AdPlacement placement) {
    return values[placement] ?? const BannerAdConfig.banner();
  }
}
