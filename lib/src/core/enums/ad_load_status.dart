/// Represents the current load/cache state of an ad placement.
enum AdLoadStatus {
  /// No load request has been started.
  idle,

  /// An ad is currently loading.
  loading,

  /// An ad is loaded and ready to show.
  ready,

  /// The last load request failed.
  failed,
}
