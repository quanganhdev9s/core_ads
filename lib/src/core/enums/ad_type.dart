/// The ad formats supported by the package.
enum AdType {
  /// A banner ad that is usually embedded inside the UI.
  banner,

  /// A full-screen interstitial ad.
  interstitial,

  /// A full-screen rewarded ad.
  rewarded,

  /// A full-screen rewarded interstitial ad.
  rewardedInterstitial,

  /// A native ad rendered by an app-defined layout.
  native,

  /// An app open ad shown when the app returns to the foreground.
  appOpen,
}
