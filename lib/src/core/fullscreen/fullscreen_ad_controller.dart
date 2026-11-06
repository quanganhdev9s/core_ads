import '../config/ad_placement.dart';
import '../enums/ad_type.dart';
import '../results/ad_failure.dart';
import '../results/ad_result.dart';
import 'fullscreen_ad_cooldown_config.dart';

/// Coordinates fullscreen ads so only one can be shown at a time.
class FullscreenAdController {
  /// Creates a fullscreen ad controller.
  FullscreenAdController({
    this.cooldown = const FullscreenAdCooldownConfig(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Current fullscreen cooldown rules.
  FullscreenAdCooldownConfig cooldown;

  AdPlacement? _activePlacement;
  DateTime? _lastInterstitialShownAt;
  DateTime? _lastCountedInterstitialShownAt;
  DateTime? _lastAppOpenShownAt;

  /// Placement currently holding the fullscreen lock.
  AdPlacement? get activePlacement => _activePlacement;

  /// Whether a fullscreen ad is currently showing.
  bool get isShowing => _activePlacement != null;

  /// Updates cooldown rules used by future can-show checks.
  void updateCooldown(FullscreenAdCooldownConfig cooldown) {
    this.cooldown = cooldown;
  }

  /// Checks whether [placement] can show according to cooldown rules.
  AdResult<void> canShow(AdPlacement placement) {
    return switch (placement.type) {
      AdType.interstitial => _canShowInterstitial(placement),
      AdType.appOpen => _canShowAppOpen(),
      _ => const AdResult.success(null),
    };
  }

  /// Tries to acquire the fullscreen lock for [placement].
  AdResult<void> tryAcquire(AdPlacement placement) {
    final activePlacement = _activePlacement;
    if (activePlacement != null) {
      return AdResult.failure(
        AdFailure(
          code: 'fullscreen_ad_showing',
          message: 'Fullscreen ad ${activePlacement.key} is already showing.',
        ),
      );
    }

    _activePlacement = placement;
    return const AdResult.success(null);
  }

  /// Releases the fullscreen lock for [placement].
  void release(AdPlacement placement) {
    if (_activePlacement == placement) {
      _activePlacement = null;
    }
  }

  /// Records a successful fullscreen ad show.
  void markShown(AdPlacement placement) {
    switch (placement.type) {
      case AdType.interstitial:
        _lastInterstitialShownAt = _now();
        if (!cooldown.ignoredInterstitialPlacementKeys.contains(
          placement.key,
        )) {
          _lastCountedInterstitialShownAt = _lastInterstitialShownAt;
        }
      case AdType.appOpen:
        _lastAppOpenShownAt = _now();
      case AdType.banner:
      case AdType.rewarded:
      case AdType.rewardedInterstitial:
      case AdType.native:
        break;
    }
  }

  /// Clears the lock regardless of owner.
  void reset() {
    _activePlacement = null;
    _lastInterstitialShownAt = null;
    _lastCountedInterstitialShownAt = null;
    _lastAppOpenShownAt = null;
  }

  AdResult<void> _canShowInterstitial(AdPlacement placement) {
    if (!cooldown.ignoredInterstitialPlacementKeys.contains(placement.key)) {
      final interstitialResult = _checkCooldown(
        lastShownAt: _lastCountedInterstitialShownAt,
        interval: cooldown.interstitialInterval,
        code: 'interstitial_cooldown_active',
        message: 'Interstitial cooldown is still active.',
      );
      if (interstitialResult.isFailure) {
        return interstitialResult;
      }
    }

    return _checkCooldown(
      lastShownAt: _lastAppOpenShownAt,
      interval: cooldown.interstitialAppOpenInterval,
      code: 'interstitial_app_open_cooldown_active',
      message: 'Interstitial and app open cooldown is still active.',
    );
  }

  AdResult<void> _canShowAppOpen() {
    final appOpenResult = _checkCooldown(
      lastShownAt: _lastAppOpenShownAt,
      interval: cooldown.appOpenInterval,
      code: 'app_open_cooldown_active',
      message: 'App open cooldown is still active.',
    );
    if (appOpenResult.isFailure) {
      return appOpenResult;
    }

    return _checkCooldown(
      lastShownAt: _lastInterstitialShownAt,
      interval: cooldown.interstitialAppOpenInterval,
      code: 'interstitial_app_open_cooldown_active',
      message: 'Interstitial and app open cooldown is still active.',
    );
  }

  AdResult<void> _checkCooldown({
    required DateTime? lastShownAt,
    required Duration interval,
    required String code,
    required String message,
  }) {
    if (lastShownAt == null || interval == Duration.zero) {
      return const AdResult.success(null);
    }

    if (_now().difference(lastShownAt) >= interval) {
      return const AdResult.success(null);
    }

    return AdResult.failure(AdFailure(code: code, message: message));
  }
}
