import 'package:core_ads/core_ads.dart';
import 'package:flutter/foundation.dart';

import 'example_ad_configs.dart';
import 'example_ad_unit_ids.dart';
import 'example_placements.dart';

class ExampleAdsManager extends ChangeNotifier {
  bool _isPremiumUser = false;
  bool _isInitialized = false;
  Future<AdResult<void>>? _initializeFuture;

  bool get isPremiumUser => _isPremiumUser;

  bool get isInitialized => _isInitialized;

  void setPremiumUser(bool value) {
    if (_isPremiumUser == value) {
      return;
    }

    _isPremiumUser = value;
    notifyListeners();

    if (_isPremiumUser) {
      AppAds.clearType(AdType.banner);
      AppAds.clearType(AdType.native);
      AppAds.clearType(AdType.interstitial);
      AppAds.clearType(AdType.appOpen);
    }
  }

  Future<AdResult<void>> initialize({required AdsCallbacks callbacks}) async {
    if (_isPremiumUser) {
      _isInitialized = true;
      notifyListeners();
      return const AdResult.success(null);
    }

    final existingFuture = _initializeFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = AppAds.initialize(_config(callbacks));
    _initializeFuture = future;
    final result = await future;

    _isInitialized = result.isSuccess;
    if (result.isFailure) {
      _initializeFuture = null;
    }
    notifyListeners();

    return result;
  }

  Future<AdResult<void>> load(AdPlacement placement) {
    if (_shouldSkipPlacement(placement)) {
      return Future.value(const AdResult.success(null));
    }

    return AppAds.load(placement);
  }

  Future<AdResult<void>> showInterstitial(AdPlacement placement) {
    if (_shouldSkipPlacement(placement)) {
      return Future.value(const AdResult.success(null));
    }

    return AppAds.showInterstitial(placement);
  }

  Future<AdResult<void>> showAppOpen(AdPlacement placement) {
    if (_shouldSkipPlacement(placement)) {
      return Future.value(const AdResult.success(null));
    }

    return AppAds.showAppOpen(placement);
  }

  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required VoidCallback onRewardEarned,
    bool allowForPremium = true,
  }) {
    if (_isPremiumUser && !allowForPremium) {
      onRewardEarned();
      return Future.value(const AdResult.success(null));
    }

    return AppAds.showRewarded(
      placement: placement,
      onRewardEarned: onRewardEarned,
    );
  }

  Future<AdResult<void>> showRewardedInterstitial({
    required AdPlacement placement,
    required VoidCallback onRewardEarned,
    bool allowForPremium = true,
  }) {
    if (_isPremiumUser && !allowForPremium) {
      onRewardEarned();
      return Future.value(const AdResult.success(null));
    }

    return AppAds.showRewardedInterstitial(
      placement: placement,
      onRewardEarned: onRewardEarned,
    );
  }

  Future<void> clear(AdPlacement placement) {
    return AppAds.clear(placement);
  }

  Future<void> clearType(AdType type) {
    return AppAds.clearType(type);
  }

  Future<void> disposeAds() async {
    _initializeFuture = null;
    _isInitialized = false;
    await AppAds.dispose();
  }

  bool _shouldSkipPlacement(AdPlacement placement) {
    if (!_isPremiumUser) {
      return false;
    }

    return switch (placement.type) {
      AdType.banner ||
      AdType.native ||
      AdType.interstitial ||
      AdType.appOpen => true,
      AdType.rewarded || AdType.rewardedInterstitial => false,
    };
  }

  AdsConfig _config(AdsCallbacks callbacks) {
    return AdsConfig(
      environment: AdsEnvironment.test,
      adUnitIds: AdUnitIds.typed({
        ExamplePlacements.banner: AdUnitId.single(ExampleAdUnitIds.banner),
        ExamplePlacements.collapsedBanner: AdUnitId.single(
          ExampleAdUnitIds.banner,
        ),
        ExamplePlacements.interstitial: AdUnitId.waterfall([
          ExampleAdUnitIds.invalid,
          ExampleAdUnitIds.interstitial,
        ]),
        ExamplePlacements.splashInterstitial: AdUnitId.waterfall([
          ExampleAdUnitIds.interstitial,
          ExampleAdUnitIds.interstitial,
        ]),
        ExamplePlacements.returnHomeInterstitial: AdUnitId.waterfall([
          ExampleAdUnitIds.interstitial,
          ExampleAdUnitIds.interstitial,
        ]),
        ExamplePlacements.rewarded: AdUnitId.waterfall([
          ExampleAdUnitIds.invalid,
          ExampleAdUnitIds.rewarded,
        ]),
        ExamplePlacements.rewardedInterstitial: AdUnitId.single(
          ExampleAdUnitIds.rewardedInterstitial,
        ),
        ExamplePlacements.appOpen: AdUnitId.waterfall([
          ExampleAdUnitIds.invalid,
          ExampleAdUnitIds.appOpen,
        ]),
        ExamplePlacements.native: AdUnitId.single(ExampleAdUnitIds.native),
        ExamplePlacements.collapsibleNative: AdUnitId.single(
          ExampleAdUnitIds.native,
        ),
      }),
      bannerAdConfigs: BannerAdConfigs({
        ExamplePlacements.banner: ExampleAdConfigs.banner,
        ExamplePlacements.collapsedBanner: ExampleAdConfigs.collapsedBanner,
      }),
      nativeAdConfigs: NativeAdConfigs({
        ExamplePlacements.native: ExampleAdConfigs.native,
        ExamplePlacements.collapsibleNative: ExampleAdConfigs.native,
      }),
      consent: const AdsConsentConfig(
        enabled: true,
        requestTrackingAuthorizationOnIos: true,
        testDeviceIds: [
          'B3EEABB8EE11C2BE770B684D95219ECB',
        ]
      ),
      callbacks: _wrapCallbacks(callbacks),
      enableDebugLogs: true,
    );
  }

  AdsCallbacks _wrapCallbacks(AdsCallbacks callbacks) {
    return AdsCallbacks(
      onLoaded: callbacks.onLoaded,
      onFailed: callbacks.onFailed,
      onShown: callbacks.onShown,
      onDismissed: callbacks.onDismissed,
      onClicked: callbacks.onClicked,
      onImpression: callbacks.onImpression,
      onRewardEarned: callbacks.onRewardEarned,
      onPaid: (event) {
        _trackAdjustAdRevenue(event);
        callbacks.onPaid?.call(event);
      },
    );
  }

  void _trackAdjustAdRevenue(AdsPaidEvent event) {
    debugPrint(
      'Forward to Adjust: ${event.placement.key} '
      '${event.valueMicros} ${event.currencyCode}',
    );
  }
}
