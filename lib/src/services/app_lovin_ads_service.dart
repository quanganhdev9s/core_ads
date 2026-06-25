import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/widgets.dart';

import '../ads/banner/banner_ad_config.dart';
import '../core/config/ad_placement.dart';
import '../core/config/ads_config.dart';
import '../core/enums/ad_network.dart';
import '../core/enums/ad_type.dart';
import '../core/events/ads_event.dart';
import '../core/events/ads_failure_event.dart';
import '../core/events/ads_paid_event.dart';
import '../core/events/ads_reward_event.dart';
import '../core/logging/ads_logger.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import 'ads_service.dart';

/// AppLovin MAX implementation of [AdsService].
class AppLovinAdsService implements AdsService {
  AdsConfig? _config;
  AdsLogger _logger = const AdsLogger(enabled: false);

  final Map<AdPlacement, Completer<AdResult<void>>> _loadCompleters = {};
  final Map<AdPlacement, Completer<AdResult<void>>> _showCompleters = {};
  final Map<String, AdPlacement> _interstitialPlacements = {};
  final Map<String, AdPlacement> _rewardedPlacements = {};
  final Map<String, AdPlacement> _appOpenPlacements = {};
  final Map<AdPlacement, void Function()> _rewardCallbacks = {};

  @override
  Future<AdResult<void>> initialize(AdsConfig config) async {
    _config = config;
    _logger = AdsLogger(enabled: config.enableDebugLogs);

    final appLovinConfig = config.appLovin;
    if (appLovinConfig == null || appLovinConfig.sdkKey.isEmpty) {
      return const AdResult.failure(
        AdFailure(
          code: 'missing_app_lovin_config',
          message: 'Missing AppLovin SDK key.',
        ),
      );
    }

    try {
      AppLovinMAX.setVerboseLogging(appLovinConfig.enableVerboseLogging);
      _setListeners();

      final sdkConfig = await AppLovinMAX.initialize(appLovinConfig.sdkKey);
      if (sdkConfig == null) {
        return const AdResult.failure(
          AdFailure(
            code: 'app_lovin_initialize_failed',
            message: 'Failed to initialize AppLovin MAX SDK.',
          ),
        );
      }

      _logger.log('AppLovin MAX initialized');
      return const AdResult.success(null);
    } catch (error) {
      return AdResult.failure(
        AdFailure.unknown('Failed to initialize AppLovin MAX', error),
      );
    }
  }

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) {
    final adUnitId = _adUnitIdFor(placement);
    if (adUnitId == null) {
      return Future.value(_missingAdUnitId(placement));
    }

    try {
      switch (placement.type) {
        case AdType.interstitial:
          final completer = Completer<AdResult<void>>();
          _loadCompleters[placement] = completer;
          _interstitialPlacements[adUnitId] = placement;
          AppLovinMAX.loadInterstitial(adUnitId);
          return completer.future;
        case AdType.rewarded:
          final completer = Completer<AdResult<void>>();
          _loadCompleters[placement] = completer;
          _rewardedPlacements[adUnitId] = placement;
          AppLovinMAX.loadRewardedAd(adUnitId);
          return completer.future;
        case AdType.appOpen:
          final completer = Completer<AdResult<void>>();
          _loadCompleters[placement] = completer;
          _appOpenPlacements[adUnitId] = placement;
          AppLovinMAX.loadAppOpenAd(adUnitId);
          return completer.future;
        case AdType.banner:
        case AdType.native:
        case AdType.rewardedInterstitial:
          return Future.value(_unsupported(placement));
      }
    } catch (error) {
      _loadCompleters.remove(placement);
      return Future.value(
        AdResult.failure(
          AdFailure.unknown('Failed to load AppLovin ad', error),
        ),
      );
    }
  }

  @override
  Future<AdResult<void>> show(AdPlacement placement) async {
    final adUnitId = _adUnitIdFor(placement);
    if (adUnitId == null) {
      return _missingAdUnitId(placement);
    }

    final completer = Completer<AdResult<void>>();
    _showCompleters[placement] = completer;

    try {
      switch (placement.type) {
        case AdType.interstitial:
          if (await AppLovinMAX.isInterstitialReady(adUnitId) != true) {
            _showCompleters.remove(placement);
            return const AdResult.failure(AdFailure.notReady());
          }
          AppLovinMAX.showInterstitial(adUnitId, placement: placement.key);
        case AdType.appOpen:
          if (await AppLovinMAX.isAppOpenAdReady(adUnitId) != true) {
            _showCompleters.remove(placement);
            return const AdResult.failure(AdFailure.notReady());
          }
          AppLovinMAX.showAppOpenAd(adUnitId, placement: placement.key);
        case AdType.banner:
        case AdType.native:
        case AdType.rewarded:
        case AdType.rewardedInterstitial:
          _showCompleters.remove(placement);
          return _unsupported(placement);
      }
    } catch (error) {
      _showCompleters.remove(placement);
      return AdResult.failure(
        AdFailure.unknown('Failed to show AppLovin ad', error),
      );
    }

    return completer.future;
  }

  @override
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) async {
    final adUnitId = _adUnitIdFor(placement);
    if (adUnitId == null) {
      return _missingAdUnitId(placement);
    }

    if (await AppLovinMAX.isRewardedAdReady(adUnitId) != true) {
      return const AdResult.failure(AdFailure.notReady());
    }

    final completer = Completer<AdResult<void>>();
    _showCompleters[placement] = completer;
    _rewardCallbacks[placement] = onRewardEarned;

    try {
      AppLovinMAX.showRewardedAd(adUnitId, placement: placement.key);
    } catch (error) {
      _showCompleters.remove(placement);
      _rewardCallbacks.remove(placement);
      return AdResult.failure(
        AdFailure.unknown('Failed to show AppLovin rewarded ad', error),
      );
    }

    return completer.future;
  }

  @override
  Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) {
    return Future.value(_unsupported(placement));
  }

  @override
  Widget banner(AdPlacement placement) => const SizedBox.shrink();

  @override
  Widget nativeAd(AdPlacement placement) => const SizedBox.shrink();

  @override
  Future<void> clear(AdPlacement placement) async {
    _loadCompleters.remove(placement);
    _showCompleters.remove(placement);
    _rewardCallbacks.remove(placement);
  }

  @override
  Future<void> clearType(AdType type) async {
    _loadCompleters.removeWhere((placement, _) => placement.type == type);
    _showCompleters.removeWhere((placement, _) => placement.type == type);
    _rewardCallbacks.removeWhere((placement, _) => placement.type == type);
  }

  @override
  Future<void> dispose() async {
    _loadCompleters.clear();
    _showCompleters.clear();
    _rewardCallbacks.clear();
    _interstitialPlacements.clear();
    _rewardedPlacements.clear();
    _appOpenPlacements.clear();
    AppLovinMAX.setInterstitialListener(null);
    AppLovinMAX.setRewardedAdListener(null);
    AppLovinMAX.setAppOpenAdListener(null);
  }

  void _setListeners() {
    AppLovinMAX.setInterstitialListener(
      InterstitialListener(
        onAdLoadedCallback: _onLoaded,
        onAdLoadFailedCallback: _onLoadFailed,
        onAdDisplayedCallback: _onDisplayed,
        onAdDisplayFailedCallback: _onDisplayFailed,
        onAdClickedCallback: _onClicked,
        onAdHiddenCallback: _onHidden,
        onAdRevenuePaidCallback: _onRevenuePaid,
      ),
    );

    AppLovinMAX.setRewardedAdListener(
      RewardedAdListener(
        onAdLoadedCallback: _onLoaded,
        onAdLoadFailedCallback: _onLoadFailed,
        onAdDisplayedCallback: _onDisplayed,
        onAdDisplayFailedCallback: _onDisplayFailed,
        onAdClickedCallback: _onClicked,
        onAdHiddenCallback: _onHidden,
        onAdRevenuePaidCallback: _onRevenuePaid,
        onAdReceivedRewardCallback: _onReward,
      ),
    );

    AppLovinMAX.setAppOpenAdListener(
      AppOpenAdListener(
        onAdLoadedCallback: _onLoaded,
        onAdLoadFailedCallback: _onLoadFailed,
        onAdDisplayedCallback: _onDisplayed,
        onAdDisplayFailedCallback: _onDisplayFailed,
        onAdClickedCallback: _onClicked,
        onAdHiddenCallback: _onHidden,
        onAdRevenuePaidCallback: _onRevenuePaid,
      ),
    );
  }

  void _onLoaded(MaxAd ad) {
    final placement = _placementFor(ad);
    if (placement == null) {
      return;
    }

    _logger.log('${placement.key} AppLovin loaded');
    _emitLoaded(placement);
    _complete(_loadCompleters.remove(placement), const AdResult.success(null));
  }

  void _onLoadFailed(String adUnitId, MaxError error) {
    final placement = _placementForAdUnitId(adUnitId);
    if (placement == null) {
      return;
    }

    _complete(
      _loadCompleters.remove(placement),
      AdResult.failure(_mapError(error)),
    );
  }

  void _onDisplayed(MaxAd ad) {
    final placement = _placementFor(ad);
    if (placement != null) {
      _emitShown(placement);
      _emitImpression(placement);
    }
  }

  void _onDisplayFailed(MaxAd ad, MaxError error) {
    final placement = _placementFor(ad);
    if (placement == null) {
      return;
    }

    final failure = _mapError(error);
    _emitFailed(placement, failure);
    _complete(_showCompleters.remove(placement), AdResult.failure(failure));
  }

  void _onClicked(MaxAd ad) {
    final placement = _placementFor(ad);
    if (placement != null) {
      _emitClicked(placement);
    }
  }

  void _onHidden(MaxAd ad) {
    final placement = _placementFor(ad);
    if (placement != null) {
      _emitDismissed(placement);
      _complete(
        _showCompleters.remove(placement),
        const AdResult.success(null),
      );
    }
  }

  void _onReward(MaxAd ad, MaxReward reward) {
    final placement = _placementFor(ad);
    if (placement == null) {
      return;
    }

    _emitReward(placement, reward);
    _rewardCallbacks.remove(placement)?.call();
  }

  void _onRevenuePaid(MaxAd ad) {
    final placement = _placementFor(ad);
    if (placement == null) {
      return;
    }

    _config?.callbacks.onPaid?.call(
      AdsPaidEvent(
        placement: placement,
        network: AdNetwork.appLovin,
        valueMicros: ad.revenue * 1000000,
        currencyCode: 'USD',
        precision: ad.revenuePrecision,
      ),
    );
  }

  AdPlacement? _placementFor(MaxAd ad) => _placementForAdUnitId(ad.adUnitId);

  AdPlacement? _placementForAdUnitId(String adUnitId) {
    return _interstitialPlacements[adUnitId] ??
        _rewardedPlacements[adUnitId] ??
        _appOpenPlacements[adUnitId];
  }

  String? _adUnitIdFor(AdPlacement placement) {
    return _config?.adUnitIds.idFor(placement);
  }

  AdResult<void> _missingAdUnitId(AdPlacement placement) {
    return AdResult.failure(
      AdFailure(
        code: 'missing_ad_unit_id',
        message: 'Missing ad unit ID for placement ${placement.key}.',
      ),
    );
  }

  AdResult<void> _unsupported(AdPlacement placement) {
    return AdResult.failure(
      AdFailure(
        code: 'unsupported_ad_type',
        message:
            '${placement.type.name} is not supported by AppLovinAdsService yet.',
      ),
    );
  }

  AdFailure _mapError(MaxError error) {
    final code = error.code.value.toString();
    final message = error.message;

    if (code == '204') {
      return AdFailure(code: 'no_fill', message: message, cause: error);
    }

    return AdFailure(code: code, message: message, cause: error);
  }

  void _complete(Completer<AdResult<void>>? completer, AdResult<void> result) {
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void _emitLoaded(AdPlacement placement) {
    _config?.callbacks.onLoaded?.call(_event(placement));
  }

  void _emitFailed(AdPlacement placement, AdFailure failure) {
    _config?.callbacks.onFailed?.call(
      AdsFailureEvent(
        placement: placement,
        network: AdNetwork.appLovin,
        failure: failure,
      ),
    );
  }

  void _emitShown(AdPlacement placement) {
    _config?.callbacks.onShown?.call(_event(placement));
  }

  void _emitDismissed(AdPlacement placement) {
    _config?.callbacks.onDismissed?.call(_event(placement));
  }

  void _emitClicked(AdPlacement placement) {
    _config?.callbacks.onClicked?.call(_event(placement));
  }

  void _emitImpression(AdPlacement placement) {
    _config?.callbacks.onImpression?.call(_event(placement));
  }

  void _emitReward(AdPlacement placement, MaxReward reward) {
    _config?.callbacks.onRewardEarned?.call(
      AdsRewardEvent(
        placement: placement,
        network: AdNetwork.appLovin,
        amount: reward.amount,
        rewardType: reward.label,
      ),
    );
  }

  AdsEvent _event(AdPlacement placement) {
    return AdsEvent(placement: placement, network: AdNetwork.appLovin);
  }
}
