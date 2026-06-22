import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/ad_placement.dart';
import '../core/config/ads_config.dart';
import '../core/enums/ad_type.dart';
import '../core/logging/ads_logger.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
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
  final Map<AdPlacement, AppOpenAd> _appOpenAds = {};

  AdRequest get _request => adRequest ?? const AdRequest();

  @override
  Future<AdResult<void>> initialize(AdsConfig config) async {
    _config = config;
    _logger = AdsLogger(enabled: config.enableDebugLogs);

    try {
      await MobileAds.instance.initialize();
      _logger.log('Google Mobile Ads initialized');
      return const AdResult.success(null);
    } catch (error) {
      return AdResult.failure(
        AdFailure.unknown('Failed to initialize ads', error),
      );
    }
  }

  @override
  Future<AdResult<void>> load(AdPlacement placement) {
    return switch (placement.type) {
      AdType.banner => _loadBanner(placement),
      AdType.interstitial => _loadInterstitial(placement),
      AdType.rewarded => _loadRewarded(placement),
      AdType.rewardedInterstitial => _unsupported(placement),
      AdType.native => _unsupported(placement),
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
        if (!completer.isCompleted) {
          completer.complete(const AdResult.success(null));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAds.remove(placement);
        if (!completer.isCompleted) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        }
      },
    );

    ad.show(
      onUserEarnedReward: (_, reward) {
        _logger.log('Reward earned: ${reward.amount} ${reward.type}');
        onRewardEarned();
      },
    );

    return completer.future;
  }

  Future<AdResult<void>> _loadBanner(AdPlacement placement) async {
    final adUnitId = _adUnitIdFor(placement);
    if (adUnitId == null) {
      return _missingAdUnitId(placement);
    }

    final completer = Completer<AdResult<void>>();
    _bannerAds.remove(placement)?.dispose();

    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: _request,
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAds[placement] = ad as BannerAd;
          _logger.log('${placement.key} banner loaded');
          completer.complete(const AdResult.success(null));
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAds.remove(placement);
          completer.complete(AdResult.failure(_mapAdError(error)));
        },
      ),
    );

    await bannerAd.load();
    return completer.future;
  }

  Future<AdResult<void>> _loadInterstitial(AdPlacement placement) {
    final adUnitId = _adUnitIdFor(placement);
    if (adUnitId == null) {
      return Future.value(_missingAdUnitId(placement));
    }

    final completer = Completer<AdResult<void>>();
    _interstitialAds.remove(placement)?.dispose();

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: _request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAds[placement] = ad;
          _logger.log('${placement.key} interstitial loaded');
          completer.complete(const AdResult.success(null));
        },
        onAdFailedToLoad: (error) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        },
      ),
    );

    return completer.future;
  }

  Future<AdResult<void>> _loadRewarded(AdPlacement placement) {
    final adUnitId = _adUnitIdFor(placement);
    if (adUnitId == null) {
      return Future.value(_missingAdUnitId(placement));
    }

    final completer = Completer<AdResult<void>>();
    _rewardedAds.remove(placement)?.dispose();

    RewardedAd.load(
      adUnitId: adUnitId,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAds[placement] = ad;
          _logger.log('${placement.key} rewarded loaded');
          completer.complete(const AdResult.success(null));
        },
        onAdFailedToLoad: (error) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        },
      ),
    );

    return completer.future;
  }

  Future<AdResult<void>> _loadAppOpen(AdPlacement placement) {
    final adUnitId = _adUnitIdFor(placement);
    if (adUnitId == null) {
      return Future.value(_missingAdUnitId(placement));
    }

    final completer = Completer<AdResult<void>>();
    _appOpenAds.remove(placement)?.dispose();

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: _request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAds[placement] = ad;
          _logger.log('${placement.key} app open loaded');
          completer.complete(const AdResult.success(null));
        },
        onAdFailedToLoad: (error) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        },
      ),
    );

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
        if (!completer.isCompleted) {
          completer.complete(const AdResult.success(null));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAds.remove(placement);
        if (!completer.isCompleted) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        }
      },
    );

    ad.show();
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
        if (!completer.isCompleted) {
          completer.complete(const AdResult.success(null));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAds.remove(placement);
        if (!completer.isCompleted) {
          completer.complete(AdResult.failure(_mapAdError(error)));
        }
      },
    );

    ad.show();
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

  String? _adUnitIdFor(AdPlacement placement) {
    return _config?.adUnitIds.idFor(placement);
  }

  AdFailure _mapAdError(AdError error) {
    final code = error.code.toString();
    final message = error.message;

    if (code == '3') {
      return AdFailure.noFill(message);
    }

    if (code == '2') {
      return AdFailure.network(message);
    }

    return AdFailure(code: code, message: message, cause: error);
  }

  @override
  Future<void> dispose() async {
    for (final ad in _bannerAds.values) {
      ad.dispose();
    }
    for (final ad in _interstitialAds.values) {
      ad.dispose();
    }
    for (final ad in _rewardedAds.values) {
      ad.dispose();
    }
    for (final ad in _appOpenAds.values) {
      ad.dispose();
    }

    _bannerAds.clear();
    _interstitialAds.clear();
    _rewardedAds.clear();
    _appOpenAds.clear();
  }
}
