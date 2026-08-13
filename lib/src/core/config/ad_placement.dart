import '../enums/ad_type.dart';

/// Typed identifier for an ad placement inside an app.
///
/// [AdType] describes the ad format, while [AdPlacement] describes where or why
/// that format is used.
final class AdPlacement {
  /// Creates an ad placement.
  const AdPlacement({
    required this.key,
    required this.type,
    this.preloadAfterShow = true,
    this.nativeFactoryId,
  });

  /// Stable placement key, such as `home_top` or `level_complete`.
  final String key;

  /// Ad format used by this placement.
  final AdType type;

  /// Whether this placement should preload again after a successful fullscreen
  /// show.
  final bool preloadAfterShow;

  /// Platform native ad factory ID used when [type] is [AdType.native].
  final String? nativeFactoryId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdPlacement && other.key == key && other.type == type;
  }

  @override
  int get hashCode => Object.hash(key, type);

  @override
  String toString() => 'AdPlacement(key: $key, type: ${type.name})';
}
