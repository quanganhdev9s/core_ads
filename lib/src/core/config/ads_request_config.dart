/// Global ad request configuration.
class AdsRequestConfig {
  /// Creates ad request configuration.
  const AdsRequestConfig({
    this.testDeviceIds = const <String>[],
    this.maxAdContentRating,
    this.tagForChildDirectedTreatment,
    this.tagForUnderAgeOfConsent,
  });

  /// Device IDs that should receive test ads.
  final List<String> testDeviceIds;

  /// Maximum content rating allowed for ads.
  final AdsMaxAdContentRating? maxAdContentRating;

  /// Whether requests should be treated as child-directed.
  final bool? tagForChildDirectedTreatment;

  /// Whether requests should be treated as under age of consent.
  final bool? tagForUnderAgeOfConsent;
}

/// Maximum ad content rating.
enum AdsMaxAdContentRating {
  /// General audiences.
  g,

  /// Parental guidance.
  pg,

  /// Teen.
  t,

  /// Mature audiences.
  ma,
}
