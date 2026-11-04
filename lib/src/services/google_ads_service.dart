import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/ad_placement.dart';
import '../core/config/ads_config.dart';
import '../core/config/ads_request_config.dart';
import '../core/enums/ad_type.dart';
import '../core/enums/ad_network.dart';
import '../core/events/ads_event.dart';
import '../core/events/ads_failure_event.dart';
import '../core/events/ads_paid_event.dart';
import '../core/events/ads_reward_event.dart';
import '../core/logging/ads_logger.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import '../ads/banner/banner_ad_config.dart';
import 'ads_service.dart';

/// Google Mobile Ads implementation of [AdsService].
class GoogleAdsService implements AdsService {
  /// Creates a Google Mobile Ads service.
  GoogleAdsService({this.adRequest});

  /// Optional request object used for every ad load.
  final AdRequest? adRequest;

  AdsConfig? _config;
  AdsLogger _logger = const AdsLogger(enabled: false);

  final Map<AdPlacement, BannerAd> _bannerAds = {};
  final Map<AdPlacement, InterstitialAd> _interstitialAds = {};
  final Map<AdPlacement, RewardedAd> _rewardedAds = {};
  final Map<AdPlacement, RewardedInterstitialAd> _rewardedInterstitialAds = {};
  final Map<AdPlacement, AppOpenAd> _appOpenAds = {};
  final Map<AdPlacement, NativeAd> _nativeAds = {};
  final Map<AdPlacement, Object> _nativeRequests = {};

  static const _nativeLoadCancelled = AdFailure(
    code: 'load_cancelled',
    message: 'Native ad load cancelled',
  );

  AdRequest get _request => adRequest ?? const AdRequest();

  @override
  Future<AdResult<void>> initialize(AdsConfig config) async {
    _config = config;
    _logger = AdsLogger(enabled: config.enableDebugLogs);

    final productionConfigFailure = _validateProductionAdUnitIds(config);
    if (productionConfigFailure != null) {
      return AdResult.failure(productionConfigFailure);
    }

    try {
      await _updateRequestConfiguration(config.request);
      await MobileAds.instance.initialize();
      _logger.log('Google Mobile Ads initialized');
      return const AdResult.success(null);
    } catch (error) {
      return AdResult.failure(
        AdFailure.unknown('Failed to initialize ads', error),
      );
    }
  }

  Future<void> _updateRequestConfiguration(AdsRequestConfig config) {
    return MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: config.testDeviceIds.isEmpty
            ? null
            : config.testDeviceIds,
        maxAdContentRating: _maxAdContentRating(config.maxAdContentRating),
        tagForChildDirectedTreatment: _childDirectedTag(
          config.tagForChildDirectedTreatment,
        ),
        tagForUnderAgeOfConsent: _underAgeTag(config.tagForUnderAgeOfConsent),
      ),
    );
  }

  String? _maxAdContentRating(AdsMaxAdContentRating? rating) {
    return switch (rating) {
      null => null,
      AdsMaxAdContentRating.g => MaxAdContentRating.g,
      AdsMaxAdContentRating.pg => MaxAdContentRating.pg,
      AdsMaxAdContentRating.t => MaxAdContentRating.t,
      AdsMaxAdContentRating.ma => MaxAdContentRating.ma,
    };
  }

  int? _childDirectedTag(bool? value) {
    return switch (value) {
      null => null,
      true => TagForChildDirectedTreatment.yes,
      false => TagForChildDirectedTreatment.no,
    };
  }

  int? _underAgeTag(bool? value) {
    return switch (value) {
      null => null,
      true => TagForUnderAgeOfConsent.yes,
      false => TagForUnderAgeOfConsent.no,
    };
  }

  @override
  Future<AdResult<void>> load(
    AdPlacement placement, {
    BannerAdConfig? bannerConfig,
  }) {
    return switch (placement.type) {
      AdType.banner => _loadBanner(placement, config: bannerConfig),
      AdType.interstitial => _loadInterstitial(placement),
      AdType.rewarded => _loadRewarded(placement),
      AdType.rewardedInterstitial => _loadRewardedInterstitial(placement),
      AdType.native => _loadNative(placement),
      AdType.appOpen => _loadAppOpen(placement),
    };
  }

  @override
  Future<AdResult<void>> show(AdPlacement placement) {
    return switch (placement.type) {
      AdType.interstitial => _showInterstitial(placement),
      AdType.appOpen => _showAppOpen(placement),
      AdType.banner => Future.value(
        const AdResult.failure(AdFailure.notReady()),
      ),
      AdType.rewarded => Future.value(
        const AdResult.failure(AdFailure.notReady()),
      ),
      AdType.rewardedInterstitial => _unsupported(placement),
      AdType.native => _unsupported(placement),
    };
  }

  @override
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) async {
    final ad = _rewardedAds[placement];
    if (ad == null) {
      return const AdResult.failure(AdFailure.notReady());
    }

    final completer = Completer<AdResult<void>>();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAds.remove(placement);
        _emitDismissed(placement);
        if (!completer.isCompleted) {
          completer.complete(const AdResult.success(null));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAds.remove(placement);
        _emitFailed(placement, _mapAdError(error));
        if (!completer.isCompleted) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        }
      },
      onAdShowedFullScreenContent: (_) => _emitShown(placement),
      onAdImpression: (_) => _emitImpression(placement),
      onAdClicked: (_) => _emitClicked(placement),
    );

    try {
      ad.show(
        onUserEarnedReward: (_, reward) {
          _logger.log('Reward earned: ${reward.amount} ${reward.type}');
          _emitReward(placement, reward);
          onRewardEarned();
        },
      );
    } catch (error) {
      ad.dispose();
      _rewardedAds.remove(placement);
      final failure = AdFailure.unknown('Failed to show rewarded ad', error);
      _emitFailed(placement, failure);
      if (!completer.isCompleted) {
        completer.complete(AdResult.failure(failure));
      }
    }

    return completer.future;
  }

  @override
  Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) async {
    final ad = _rewardedInterstitialAds[placement];
    if (ad == null) {
      return const AdResult.failure(AdFailure.notReady());
    }

    final completer = Completer<AdResult<void>>();
    ad.fullScreenContentCallback =
        FullScreenContentCallback<RewardedInterstitialAd>(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _rewardedInterstitialAds.remove(placement);
            _emitDismissed(placement);
            if (!completer.isCompleted) {
              completer.complete(const AdResult.success(null));
            }
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _rewardedInterstitialAds.remove(placement);
            _emitFailed(placement, _mapAdError(error));
            if (!completer.isCompleted) {
              completer.complete(AdResult.failure(_mapAdError(error)));
            }
          },
          onAdShowedFullScreenContent: (_) => _emitShown(placement),
          onAdImpression: (_) => _emitImpression(placement),
          onAdClicked: (_) => _emitClicked(placement),
        );

    try {
      await ad.show(
        onUserEarnedReward: (_, reward) {
          _logger.log(
            'Rewarded interstitial reward earned: ${reward.amount} '
            '${reward.type}',
          );
          _emitReward(placement, reward);
          onRewardEarned();
        },
      );
    } catch (error) {
      ad.dispose();
      _rewardedInterstitialAds.remove(placement);
      final failure = AdFailure.unknown(
        'Failed to show rewarded interstitial ad',
        error,
      );
      _emitFailed(placement, failure);
      if (!completer.isCompleted) {
        completer.complete(AdResult.failure(failure));
      }
    }

    return completer.future;
  }

  @override
  Widget banner(AdPlacement placement) {
    final ad = _bannerAds[placement];
    if (ad == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }

  @override
  Widget nativeAd(AdPlacement placement) {
    final ad = _nativeAds[placement];
    if (ad == null) {
      return const SizedBox.shrink();
    }

    return AdWidget(ad: ad);
  }

  @override
  Future<void> clear(AdPlacement placement) async {
    switch (placement.type) {
      case AdType.banner:
        _bannerAds.remove(placement)?.dispose();
      case AdType.interstitial:
        _interstitialAds.remove(placement)?.dispose();
      case AdType.rewarded:
        _rewardedAds.remove(placement)?.dispose();
      case AdType.rewardedInterstitial:
        _rewardedInterstitialAds.remove(placement)?.dispose();
      case AdType.native:
        _nativeRequests.remove(placement);
        _nativeAds.remove(placement)?.dispose();
      case AdType.appOpen:
        _appOpenAds.remove(placement)?.dispose();
    }
  }

  @override
  Future<void> clearType(AdType type) async {
    switch (type) {
      case AdType.banner:
        _disposeAll(_bannerAds);
      case AdType.interstitial:
        _disposeAll(_interstitialAds);
      case AdType.rewarded:
        _disposeAll(_rewardedAds);
      case AdType.rewardedInterstitial:
        _disposeAll(_rewardedInterstitialAds);
      case AdType.native:
        _nativeRequests.clear();
        _disposeAll(_nativeAds);
      case AdType.appOpen:
        _disposeAll(_appOpenAds);
    }
  }

  Future<AdResult<void>> _loadBanner(
    AdPlacement placement, {
    BannerAdConfig? config,
  }) async {
    final adUnitIds = _adUnitIdsFor(placement);
    if (adUnitIds.isEmpty) {
      return _missingAdUnitId(placement);
    }

    final bannerConfig = config ?? const BannerAdConfig.banner();
    final adSize = await _bannerAdSize(bannerConfig);
    if (adSize == null) {
      return AdResult.failure(
        AdFailure(
          code: 'invalid_banner_size',
          message: 'Could not resolve banner size for ${placement.key}.',
        ),
      );
    }

    _bannerAds.remove(placement)?.dispose();
    return _loadWaterfall(
      placement: placement,
      adUnitIds: adUnitIds,
      load: (adUnitId) => _loadBannerWithAdUnitId(
        placement,
        adUnitId: adUnitId,
        adSize: adSize,
      ),
    );
  }

  Future<AdResult<void>> _loadBannerWithAdUnitId(
    AdPlacement placement, {
    required String adUnitId,
    required AdSize adSize,
  }) async {
    final completer = Completer<AdResult<void>>();

    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: _request,
      size: adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAds[placement] = ad as BannerAd;
          _logger.log('${placement.key} banner loaded');
          _emitLoaded(placement);
          _completeLoad(completer, const AdResult.success(null));
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAds.remove(placement);
          final failure = _mapAdError(error);
          _completeLoad(completer, AdResult.failure(failure));
        },
        onAdImpression: (_) => _emitImpression(placement),
        onAdClicked: (_) => _emitClicked(placement),
        onPaidEvent: (ad, valueMicros, precision, currencyCode) =>
            _emitPaid(placement, ad, valueMicros, precision, currencyCode),
      ),
    );

    try {
      await bannerAd.load();
    } catch (error) {
      bannerAd.dispose();
      _bannerAds.remove(placement);
      return AdResult.failure(_mapLoadException('banner', error));
    }

    return completer.future;
  }

  Future<AdSize?> _bannerAdSize(BannerAdConfig config) async {
    return switch (config.size) {
      BannerAdSize.banner => AdSize.banner,
      BannerAdSize.largeBanner => AdSize.largeBanner,
      BannerAdSize.mediumRectangle => AdSize.mediumRectangle,
      BannerAdSize.fullBanner => AdSize.fullBanner,
      BannerAdSize.leaderboard => AdSize.leaderboard,
      BannerAdSize.anchoredAdaptive =>
        AdSize.getLargeAnchoredAdaptiveBannerAdSize(
          config.resolvedWidth.round(),
        ),
    };
  }

  Future<AdResult<void>> _loadNative(AdPlacement placement) async {
    final adUnitIds = _adUnitIdsFor(placement);
    if (adUnitIds.isEmpty) {
      return _missingAdUnitId(placement);
    }

    final factoryId = placement.nativeFactoryId;
    if (factoryId == null || factoryId.isEmpty) {
      return AdResult.failure(
        AdFailure(
          code: 'missing_native_factory_id',
          message: 'Missing native factory ID for placement ${placement.key}.',
        ),
      );
    }

    final request = Object();
    _nativeRequests[placement] = request;
    _nativeAds.remove(placement)?.dispose();
    return _loadWaterfall(
      placement: placement,
      adUnitIds: adUnitIds,
      load: (adUnitId) => identical(_nativeRequests[placement], request)
          ? _loadNativeWithAdUnitId(
              placement,
              adUnitId: adUnitId,
              factoryId: factoryId,
              request: request,
            )
          : Future.value(const AdResult.failure(_nativeLoadCancelled)),
    );
  }

  Future<AdResult<void>> _loadNativeWithAdUnitId(
    AdPlacement placement, {
    required String adUnitId,
    required String factoryId,
    required Object request,
  }) async {
    final completer = Completer<AdResult<void>>();

    final nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: factoryId,
      request: _request,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!identical(_nativeRequests[placement], request)) {
            ad.dispose();
            _completeLoad(
              completer,
              const AdResult.failure(_nativeLoadCancelled),
            );
            return;
          }
          _nativeAds[placement] = ad as NativeAd;
          _logger.log('${placement.key} native loaded');
          _emitLoaded(placement);
          _completeLoad(completer, const AdResult.success(null));
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!identical(_nativeRequests[placement], request)) {
            _completeLoad(
              completer,
              const AdResult.failure(_nativeLoadCancelled),
            );
            return;
          }
          _nativeAds.remove(placement);
          final failure = _mapAdError(error);
          _completeLoad(completer, AdResult.failure(failure));
        },
        onAdImpression: (_) => _emitImpression(placement),
        onAdClicked: (_) => _emitClicked(placement),
        onPaidEvent: (ad, valueMicros, precision, currencyCode) =>
            _emitPaid(placement, ad, valueMicros, precision, currencyCode),
      ),
    );

    try {
      await nativeAd.load();
      return await completer.future;
    } catch (error) {
      nativeAd.dispose();
      if (!identical(_nativeRequests[placement], request)) {
        return const AdResult.failure(_nativeLoadCancelled);
      }
      _nativeAds.remove(placement);
      return AdResult.failure(_mapNativeLoadException(error));
    }
  }

  Future<AdResult<void>> _loadInterstitial(AdPlacement placement) {
    final adUnitIds = _adUnitIdsFor(placement);
    if (adUnitIds.isEmpty) {
      return Future.value(_missingAdUnitId(placement));
    }

    _interstitialAds.remove(placement)?.dispose();
    return _loadWaterfall(
      placement: placement,
      adUnitIds: adUnitIds,
      load: (adUnitId) =>
          _loadInterstitialWithAdUnitId(placement, adUnitId: adUnitId),
    );
  }

  Future<AdResult<void>> _loadInterstitialWithAdUnitId(
    AdPlacement placement, {
    required String adUnitId,
  }) {
    final completer = Completer<AdResult<void>>();

    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: _request,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) =>
                _emitPaid(placement, ad, valueMicros, precision, currencyCode);
            _interstitialAds[placement] = ad;
            _logger.log('${placement.key} interstitial loaded');
            _emitLoaded(placement);
            _completeLoad(completer, const AdResult.success(null));
          },
          onAdFailedToLoad: (error) {
            final failure = _mapAdError(error);
            _completeLoad(completer, AdResult.failure(failure));
          },
        ),
      );
    } catch (error) {
      return Future.value(
        AdResult.failure(_mapLoadException('interstitial', error)),
      );
    }

    return completer.future;
  }

  Future<AdResult<void>> _loadRewarded(AdPlacement placement) {
    final adUnitIds = _adUnitIdsFor(placement);
    if (adUnitIds.isEmpty) {
      return Future.value(_missingAdUnitId(placement));
    }

    _rewardedAds.remove(placement)?.dispose();
    return _loadWaterfall(
      placement: placement,
      adUnitIds: adUnitIds,
      load: (adUnitId) =>
          _loadRewardedWithAdUnitId(placement, adUnitId: adUnitId),
    );
  }

  Future<AdResult<void>> _loadRewardedWithAdUnitId(
    AdPlacement placement, {
    required String adUnitId,
  }) {
    final completer = Completer<AdResult<void>>();

    try {
      RewardedAd.load(
        adUnitId: adUnitId,
        request: _request,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) =>
                _emitPaid(placement, ad, valueMicros, precision, currencyCode);
            _rewardedAds[placement] = ad;
            _logger.log('${placement.key} rewarded loaded');
            _emitLoaded(placement);
            _completeLoad(completer, const AdResult.success(null));
          },
          onAdFailedToLoad: (error) {
            final failure = _mapAdError(error);
            _completeLoad(completer, AdResult.failure(failure));
          },
        ),
      );
    } catch (error) {
      return Future.value(
        AdResult.failure(_mapLoadException('rewarded', error)),
      );
    }

    return completer.future;
  }

  Future<AdResult<void>> _loadRewardedInterstitial(AdPlacement placement) {
    final adUnitIds = _adUnitIdsFor(placement);
    if (adUnitIds.isEmpty) {
      return Future.value(_missingAdUnitId(placement));
    }

    _rewardedInterstitialAds.remove(placement)?.dispose();
    return _loadWaterfall(
      placement: placement,
      adUnitIds: adUnitIds,
      load: (adUnitId) =>
          _loadRewardedInterstitialWithAdUnitId(placement, adUnitId: adUnitId),
    );
  }

  Future<AdResult<void>> _loadRewardedInterstitialWithAdUnitId(
    AdPlacement placement, {
    required String adUnitId,
  }) {
    final completer = Completer<AdResult<void>>();

    try {
      RewardedInterstitialAd.load(
        adUnitId: adUnitId,
        request: _request,
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) =>
                _emitPaid(placement, ad, valueMicros, precision, currencyCode);
            _rewardedInterstitialAds[placement] = ad;
            _logger.log('${placement.key} rewarded interstitial loaded');
            _emitLoaded(placement);
            _completeLoad(completer, const AdResult.success(null));
          },
          onAdFailedToLoad: (error) {
            final failure = _mapAdError(error);
            _completeLoad(completer, AdResult.failure(failure));
          },
        ),
      );
    } catch (error) {
      return Future.value(
        AdResult.failure(_mapLoadException('rewarded interstitial', error)),
      );
    }

    return completer.future;
  }

  Future<AdResult<void>> _loadAppOpen(AdPlacement placement) {
    final adUnitIds = _adUnitIdsFor(placement);
    if (adUnitIds.isEmpty) {
      return Future.value(_missingAdUnitId(placement));
    }

    _appOpenAds.remove(placement)?.dispose();
    return _loadWaterfall(
      placement: placement,
      adUnitIds: adUnitIds,
      load: (adUnitId) =>
          _loadAppOpenWithAdUnitId(placement, adUnitId: adUnitId),
    );
  }

  Future<AdResult<void>> _loadAppOpenWithAdUnitId(
    AdPlacement placement, {
    required String adUnitId,
  }) {
    final completer = Completer<AdResult<void>>();

    try {
      AppOpenAd.load(
        adUnitId: adUnitId,
        request: _request,
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) =>
                _emitPaid(placement, ad, valueMicros, precision, currencyCode);
            _appOpenAds[placement] = ad;
            _logger.log('${placement.key} app open loaded');
            _emitLoaded(placement);
            _completeLoad(completer, const AdResult.success(null));
          },
          onAdFailedToLoad: (error) {
            final failure = _mapAdError(error);
            _completeLoad(completer, AdResult.failure(failure));
          },
        ),
      );
    } catch (error) {
      return Future.value(
        AdResult.failure(_mapLoadException('app open', error)),
      );
    }

    return completer.future;
  }

  Future<AdResult<void>> _showInterstitial(AdPlacement placement) async {
    final ad = _interstitialAds[placement];
    if (ad == null) {
      return const AdResult.failure(AdFailure.notReady());
    }

    final completer = Completer<AdResult<void>>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAds.remove(placement);
        _emitDismissed(placement);
        if (!completer.isCompleted) {
          completer.complete(const AdResult.success(null));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAds.remove(placement);
        _emitFailed(placement, _mapAdError(error));
        if (!completer.isCompleted) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        }
      },
      onAdShowedFullScreenContent: (_) => _emitShown(placement),
      onAdImpression: (_) => _emitImpression(placement),
      onAdClicked: (_) => _emitClicked(placement),
    );

    try {
      ad.show();
    } catch (error) {
      ad.dispose();
      _interstitialAds.remove(placement);
      final failure = AdFailure.unknown(
        'Failed to show interstitial ad',
        error,
      );
      _emitFailed(placement, failure);
      if (!completer.isCompleted) {
        completer.complete(AdResult.failure(failure));
      }
    }
    return completer.future;
  }

  Future<AdResult<void>> _showAppOpen(AdPlacement placement) async {
    final ad = _appOpenAds[placement];
    if (ad == null) {
      return const AdResult.failure(AdFailure.notReady());
    }

    final completer = Completer<AdResult<void>>();
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAds.remove(placement);
        _emitDismissed(placement);
        if (!completer.isCompleted) {
          completer.complete(const AdResult.success(null));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAds.remove(placement);
        _emitFailed(placement, _mapAdError(error));
        if (!completer.isCompleted) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        }
      },
      onAdShowedFullScreenContent: (_) => _emitShown(placement),
      onAdImpression: (_) => _emitImpression(placement),
      onAdClicked: (_) => _emitClicked(placement),
    );

    try {
      ad.show();
    } catch (error) {
      ad.dispose();
      _appOpenAds.remove(placement);
      final failure = AdFailure.unknown('Failed to show app open ad', error);
      _emitFailed(placement, failure);
      if (!completer.isCompleted) {
        completer.complete(AdResult.failure(failure));
      }
    }
    return completer.future;
  }

  AdResult<void> _missingAdUnitId(AdPlacement placement) {
    return AdResult.failure(
      AdFailure(
        code: 'missing_ad_unit_id',
        message: 'Missing ad unit ID for placement ${placement.key}.',
      ),
    );
  }

  Future<AdResult<void>> _unsupported(AdPlacement placement) {
    return Future.value(
      AdResult.failure(
        AdFailure(
          code: 'unsupported_ad_type',
          message:
              '${placement.type.name} is not implemented by GoogleAdsService yet.',
        ),
      ),
    );
  }

  Future<AdResult<void>> _loadWaterfall({
    required AdPlacement placement,
    required List<String> adUnitIds,
    required Future<AdResult<void>> Function(String adUnitId) load,
  }) async {
    AdFailure? lastFailure;

    for (var index = 0; index < adUnitIds.length; index++) {
      final adUnitId = adUnitIds[index];
      _logger.log(
        '${placement.key} waterfall index=$index '
        'START LOAD adUnitId=$adUnitId',
      );
      final result = await load(adUnitId);
      if (result.isSuccess) {
        _logger.log(
          '${placement.key} waterfall index=$index '
          'LOADED adUnitId=$adUnitId',
        );
        return result;
      }

      final failure = (result as AdFailed<void>).failure;
      lastFailure = failure;
      _logger.log(
        '${placement.key} waterfall index=$index '
        'FAILED adUnitId=$adUnitId code=${failure.code}',
      );
    }

    return AdResult.failure(
      lastFailure ??
          AdFailure(
            code: 'missing_ad_unit_id',
            message: 'Missing ad unit ID for placement ${placement.key}.',
          ),
    );
  }

  List<String> _adUnitIdsFor(AdPlacement placement) {
    return _config?.adUnitIds.idsFor(placement) ?? const <String>[];
  }

  AdFailure? _validateProductionAdUnitIds(AdsConfig config) {
    if (config.isTest) {
      return null;
    }

    final testPlacements = config.adUnitIds.typedValues.entries
        .where((entry) => entry.value.ids.any(_isGoogleSampleAdUnitId))
        .map((entry) => entry.key.key)
        .toList(growable: false);

    if (testPlacements.isEmpty) {
      return null;
    }

    return AdFailure.testAdUnitInProduction(
      'Production config contains Google sample ad unit IDs for: '
      '${testPlacements.join(', ')}. Use AdsEnvironment.test for sample IDs '
      'or replace them with real ad unit IDs before release.',
    );
  }

  bool _isGoogleSampleAdUnitId(String adUnitId) {
    return adUnitId.startsWith('ca-app-pub-3940256099942544/');
  }

  void _disposeAll<T extends Ad>(Map<AdPlacement, T> ads) {
    for (final ad in ads.values) {
      ad.dispose();
    }
    ads.clear();
  }

  void _completeLoad(
    Completer<AdResult<void>> completer,
    AdResult<void> result,
  ) {
    if (!completer.isCompleted) {
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
        network: AdNetwork.google,
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
    _logger.log('${placement.key} ${placement.type.name} impression');
    _config?.callbacks.onImpression?.call(_event(placement));
  }

  void _emitPaid(
    AdPlacement placement,
    Ad ad,
    double valueMicros,
    PrecisionType precision,
    String currencyCode,
  ) {
    final responseInfo = ad.responseInfo;
    final loadedAdapter = responseInfo?.loadedAdapterResponseInfo;
    _config?.callbacks.onPaid?.call(
      AdsPaidEvent(
        placement: placement,
        network: AdNetwork.google,
        adUnitId: ad.adUnitId,
        valueMicros: valueMicros,
        currencyCode: currencyCode,
        precision: precision.name,
        responseId: responseInfo?.responseId,
        mediationAdapterClassName: responseInfo?.mediationAdapterClassName,
        adSourceName: loadedAdapter?.adSourceName,
        adSourceId: loadedAdapter?.adSourceId,
        adSourceInstanceName: loadedAdapter?.adSourceInstanceName,
        adSourceInstanceId: loadedAdapter?.adSourceInstanceId,
      ),
    );
  }

  void _emitReward(AdPlacement placement, RewardItem reward) {
    _config?.callbacks.onRewardEarned?.call(
      AdsRewardEvent(
        placement: placement,
        network: AdNetwork.google,
        amount: reward.amount,
        rewardType: reward.type,
      ),
    );
  }

  AdsEvent _event(AdPlacement placement) {
    return AdsEvent(placement: placement, network: AdNetwork.google);
  }

  AdFailure _mapAdError(AdError error) {
    final code = error.code.toString();
    final message = error.message;

    if (_isMissingNativeAdFactoryMessage(message)) {
      return AdFailure.missingNativeAdFactory(message, error);
    }

    return switch (code) {
      '0' => AdFailure(code: 'internal_error', message: message, cause: error),
      '1' => AdFailure(code: 'invalid_request', message: message, cause: error),
      '2' => AdFailure(code: 'network_error', message: message, cause: error),
      '3' => AdFailure(code: 'no_fill', message: message, cause: error),
      _ => AdFailure(code: code, message: message, cause: error),
    };
  }

  AdFailure _mapNativeLoadException(Object error) {
    final message = error.toString();
    if (_isMissingNativeAdFactoryMessage(message)) {
      return AdFailure.missingNativeAdFactory(message, error);
    }

    return AdFailure.unknown('Failed to load native ad', error);
  }

  AdFailure _mapLoadException(String adName, Object error) {
    final message = error.toString();
    if (_isMissingNativeAdFactoryMessage(message)) {
      return AdFailure.missingNativeAdFactory(message, error);
    }

    return AdFailure.unknown('Failed to load $adName ad', error);
  }

  bool _isMissingNativeAdFactoryMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('nativeadfactory') ||
        normalized.contains('native ad factory');
  }

  @override
  Future<void> dispose() async {
    _nativeRequests.clear();
    for (final ad in _bannerAds.values) {
      ad.dispose();
    }
    for (final ad in _interstitialAds.values) {
      ad.dispose();
    }
    for (final ad in _rewardedAds.values) {
      ad.dispose();
    }
    for (final ad in _rewardedInterstitialAds.values) {
      ad.dispose();
    }
    for (final ad in _appOpenAds.values) {
      ad.dispose();
    }
    for (final ad in _nativeAds.values) {
      ad.dispose();
    }

    _bannerAds.clear();
    _interstitialAds.clear();
    _rewardedAds.clear();
    _rewardedInterstitialAds.clear();
    _appOpenAds.clear();
    _nativeAds.clear();
  }
}
