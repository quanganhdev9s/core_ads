import 'ad_failure.dart';

/// Result wrapper for ads operations.
sealed class AdResult<T> {
  const AdResult();

  /// Creates a successful result.
  const factory AdResult.success(T value) = AdSuccess<T>;

  /// Creates a failed result.
  const factory AdResult.failure(AdFailure failure) = AdFailed<T>;

  /// Whether this result represents success.
  bool get isSuccess => this is AdSuccess<T>;

  /// Whether this result represents failure.
  bool get isFailure => this is AdFailed<T>;
}

/// A successful ads operation.
final class AdSuccess<T> extends AdResult<T> {
  /// Creates a successful ads operation.
  const AdSuccess(this.value);

  /// The operation value.
  final T value;
}

/// A failed ads operation.
final class AdFailed<T> extends AdResult<T> {
  /// Creates a failed ads operation.
  const AdFailed(this.failure);

  /// The failure details.
  final AdFailure failure;
}
