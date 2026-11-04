/// Lightweight internal logger for ads diagnostics.
class AdsLogger {
  /// Creates a logger.
  const AdsLogger({required this.enabled});

  /// Whether logs should be printed.
  final bool enabled;

  /// Logs [message] only when logging is enabled.
  void log(String message) {
    if (!enabled) {
      return;
    }

    // ignore: avoid_print
    print('[App Ads] $message');
  }
}
