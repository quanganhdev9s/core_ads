import '../core/enums/ad_load_status.dart';
import '../core/enums/ad_type.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import '../services/ads_service.dart';
import 'ad_manager.dart';
import 'consent_manager.dart';

/// Manages app open ad cache, expiration, and show flow.
class AppOpenManager implements AdManager {
  /// Creates an app open manager.
  AppOpenManager({
    required this.service,
    required this.consentManager,
    this.expiration = const Duration(hours: 4),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AdsService service;
  final ConsentManager consentManager;
  final Duration expiration;
  final DateTime Function() _now;

  AdLoadStatus _status = AdLoadStatus.idle;
  DateTime? _loadedAt;

  @override
  AdLoadStatus get status => _status;

  /// Whether the cached app open ad has expired.
  bool get isExpired {
    final loadedAt = _loadedAt;
    if (loadedAt == null) {
      return true;
    }

    return _now().difference(loadedAt) >= expiration;
  }

  @override
  Future<AdResult<void>> load() async {
    if (!consentManager.canRequestAds) {
      _status = AdLoadStatus.failed;
      return const AdResult.failure(AdFailure.consentDenied());
    }

    _status = AdLoadStatus.loading;
    final result = await service.load(AdType.appOpen);
    if (result.isSuccess) {
      _status = AdLoadStatus.ready;
      _loadedAt = _now();
    } else {
      _status = AdLoadStatus.failed;
      _loadedAt = null;
    }

    return result;
  }

  /// Shows the app open ad only when it is ready and not expired.
  Future<AdResult<void>> show() async {
    if (_status != AdLoadStatus.ready) {
      return const AdResult.failure(AdFailure.notReady());
    }

    if (isExpired) {
      _status = AdLoadStatus.failed;
      _loadedAt = null;
      return const AdResult.failure(
        AdFailure(code: 'expired', message: 'App open ad has expired.'),
      );
    }

    final result = await service.show(AdType.appOpen);
    _status = result.isSuccess ? AdLoadStatus.shown : AdLoadStatus.failed;

    if (result.isSuccess) {
      await load();
    }

    return result;
  }

  @override
  Future<void> dispose() async {
    _status = AdLoadStatus.disposed;
    _loadedAt = null;
  }
}
