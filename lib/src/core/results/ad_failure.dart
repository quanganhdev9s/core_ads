/// A typed failure returned by ads operations.
class AdFailure {
  /// Creates an ads failure.
  const AdFailure({required this.code, required this.message, this.cause});

  /// No ad is ready to be shown.
  const AdFailure.notReady([String message = 'Ad is not ready'])
    : this(code: 'not_ready', message: message);

  /// Consent does not allow requesting ads.
  const AdFailure.consentDenied([String message = 'Consent denied'])
    : this(code: 'consent_denied', message: message);

  /// The ad network returned no fill.
  const AdFailure.noFill([String message = 'No ad fill'])
    : this(code: 'no_fill', message: message);

  /// A network error prevented the operation.
  const AdFailure.network([String message = 'Network error'])
    : this(code: 'network_error', message: message);

  /// An unknown error occurred.
  const AdFailure.unknown([String message = 'Unknown ads error', Object? cause])
    : this(code: 'unknown', message: message, cause: cause);

  /// Stable failure code for branching and analytics.
  final String code;

  /// Human-readable debug message.
  final String message;

  /// Optional original error object.
  final Object? cause;
}
