import '../../core/config/ad_placement.dart';
import '../../core/enums/ad_load_status.dart';
import '../../core/results/ad_failure.dart';
import '../../core/results/ad_result.dart';
import '../../services/ads_service.dart';
import '../../managers/ad_manager.dart';
import '../../consent/consent_manager.dart';
import 'banner_ad_config.dart';

/// Manages banner ad loading and cache state.
class BannerManager implements AdManager {
  /// Creates a banner manager.
  BannerManager({
    required this.service,
    required this.consentManager,
    required this.placement,
  });

  final AdsService service;
  final ConsentManager consentManager;
  final AdPlacement placement;

  AdLoadStatus _status = AdLoadStatus.idle;
  BannerAdConfig? _cachedConfig;
  BannerAdConfig? _loadingConfig;
  Future<AdResult<void>>? _loadFuture;
  int _loadToken = 0;

  @override
  AdLoadStatus get status => _status;

  @override
  bool get canShow => false;

  /// Whether a banner is available to be reused.
  bool get hasCachedBanner => _status == AdLoadStatus.ready;

  @override
  Future<AdResult<void>> load({BannerAdConfig? config}) async {
    if (!consentManager.canRequestAds) {
      _status = AdLoadStatus.failed;
      return const AdResult.failure(AdFailure.consentDenied());
    }

    if (hasCachedBanner && _cachedConfig == config) {
      return const AdResult.success(null);
    }

    final existingLoad = _loadFuture;
    if (existingLoad != null) {
      if (_loadingConfig == config) {
        return existingLoad;
      }

      await existingLoad;
      return load(config: config);
    }

    final token = ++_loadToken;
    final loadFuture = _load(config: config, token: token);
    _loadFuture = loadFuture;
    _loadingConfig = config;

    try {
      return await loadFuture;
    } finally {
      if (identical(_loadFuture, loadFuture)) {
        _loadFuture = null;
        _loadingConfig = null;
      }
    }
  }

  Future<AdResult<void>> _load({
    required BannerAdConfig? config,
    required int token,
  }) async {
    _status = AdLoadStatus.loading;
    final result = await service.load(placement, bannerConfig: config);
    if (token != _loadToken) {
      return result;
    }

    if (result.isSuccess) {
      _status = AdLoadStatus.ready;
      _cachedConfig = config;
    } else {
      _status = AdLoadStatus.failed;
      _cachedConfig = null;
    }

    return result;
  }

  @override
  Future<void> dispose() async {
    _loadFuture = null;
    _loadingConfig = null;
    _loadToken++;
    _status = AdLoadStatus.idle;
    _cachedConfig = null;
  }
}
