import 'ad_frequency_config.dart';

/// Controls how often ads are allowed to show.
class AdFrequencyController {
  /// Creates a frequency controller.
  AdFrequencyController({required this.config, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The active frequency configuration.
  final AdFrequencyConfig config;

  final DateTime Function() _now;

  int _actionCount = 0;
  DateTime? _lastShownAt;

  /// Number of tracked actions since the last reset.
  int get actionCount => _actionCount;

  /// Records one user action and returns whether an ad can be shown now.
  bool recordActionAndCheck() {
    _actionCount += 1;
    return canShow;
  }

  /// Whether the frequency rules currently allow showing an ad.
  bool get canShow {
    if (_actionCount < config.showEveryActions) {
      return false;
    }

    final lastShownAt = _lastShownAt;
    if (lastShownAt == null || config.cooldown == Duration.zero) {
      return true;
    }

    return !_now().difference(lastShownAt).isNegative &&
        _now().difference(lastShownAt) >= config.cooldown;
  }

  /// Marks an ad as shown and resets the action counter.
  void markShown() {
    _lastShownAt = _now();
    _actionCount = 0;
  }

  /// Resets the tracked action count without changing cooldown state.
  void resetActions() {
    _actionCount = 0;
  }
}
