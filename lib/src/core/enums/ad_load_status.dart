/// Represents the lifecycle state of an ad instance.
enum AdLoadStatus {
  /// No load request has been started.
  idle,

  /// An ad is currently loading.
  loading,

  /// An ad is loaded and ready to show.
  ready,

  /// The last load request failed.
  failed,

  /// The ad has been shown.
  shown,

  /// The ad has been disposed.
  disposed,
}
