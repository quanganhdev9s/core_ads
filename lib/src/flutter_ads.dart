import 'core/config/ads_config.dart';
import 'core/enums/ad_type.dart';
import 'core/results/ad_failure.dart';
import 'core/results/ad_result.dart';
import 'data/repositories/ads_repository_impl.dart';
import 'domain/repositories/ads_repository.dart';
import 'services/ads_service.dart';
import 'services/memory_ads_service.dart';

/// Public entry-point used by applications to interact with ads.
class FlutterAds {
  FlutterAds._();

  static AdsRepository? _repository;

  /// Initializes the ads package.
  ///
  /// A custom [repository] can be provided by advanced integrations. Most apps
  /// should pass [config] and let the package create its internal repository.
  static Future<AdResult<void>> initialize(
    AdsConfig config, {
    AdsRepository? repository,
    AdsService? service,
  }) async {
    if (repository != null) {
      _repository = repository;
      return _repository!.initialize();
    }

    _repository = AdsRepositoryImpl(
      config: config,
      service: service ?? MemoryAdsService(),
    );

    return _repository!.initialize();
  }

  /// Shows an interstitial ad if one is ready.
  static Future<AdResult<void>> showInterstitial() {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showInterstitial();
  }

  /// Shows a rewarded ad if one is ready.
  ///
  /// [onRewardEarned] is called only after the underlying ad network confirms
  /// the user earned the reward.
  static Future<AdResult<void>> showRewarded({
    required void Function() onRewardEarned,
  }) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showRewarded(onRewardEarned: onRewardEarned);
  }

  /// Shows an app open ad if one is ready and valid.
  static Future<AdResult<void>> showAppOpen() {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.showAppOpen();
  }

  /// Requests loading an ad for [type].
  ///
  /// This is mainly useful for explicit preloading in advanced flows.
  static Future<AdResult<void>> load(AdType type) {
    final repository = _repository;
    if (repository == null) {
      return Future.value(const AdResult.failure(AdFailure.notReady()));
    }

    return repository.load(type);
  }

  /// Disposes ads resources.
  static Future<void> dispose() async {
    await _repository?.dispose();
    _repository = null;
  }
}
