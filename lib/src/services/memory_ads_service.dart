import 'package:flutter/widgets.dart';

import '../core/config/ad_placement.dart';
import '../core/config/ads_config.dart';
import '../core/enums/ad_load_status.dart';
import '../core/logging/ads_logger.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import 'ads_service.dart';

/// A lightweight in-memory ads service used before a real SDK is configured.
///
/// This implementation does not show real ads. It exists so the package has a
/// concrete service for development, architecture validation, and app-side
/// integration before Google Mobile Ads is wired in.
class MemoryAdsService implements AdsService {
  /// Creates an in-memory ads service.
  MemoryAdsService();

  final Map<AdPlacement, AdLoadStatus> _statuses =
      <AdPlacement, AdLoadStatus>{};

  AdsLogger _logger = const AdsLogger(enabled: false);
  bool _isInitialized = false;

  @override
  Future<AdResult<void>> initialize(AdsConfig config) async {
    _logger = AdsLogger(enabled: config.enableDebugLogs);
    _isInitialized = true;
    _logger.log('MemoryAdsService initialized');

    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> load(AdPlacement placement) async {
    if (!_isInitialized) {
      return const AdResult.failure(
        AdFailure(
          code: 'not_initialized',
          message: 'Ads service has not been initialized.',
        ),
      );
    }

    _statuses[placement] = AdLoadStatus.ready;
    _logger.log('${placement.key} marked ready');

    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> show(AdPlacement placement) async {
    if (!_isInitialized) {
      return const AdResult.failure(
        AdFailure(
          code: 'not_initialized',
          message: 'Ads service has not been initialized.',
        ),
      );
    }

    if (_statuses[placement] != AdLoadStatus.ready) {
      _logger.log('${placement.key} is not ready');
      return const AdResult.failure(AdFailure.notReady());
    }

    _statuses[placement] = AdLoadStatus.shown;
    _logger.log('${placement.key} shown by memory service');

    return const AdResult.success(null);
  }

  @override
  Future<AdResult<void>> showRewarded({
    required AdPlacement placement,
    required void Function() onRewardEarned,
  }) async {
    final result = await show(placement);
    if (result.isSuccess) {
      onRewardEarned();
    }

    return result;
  }

  @override
  Widget banner(AdPlacement placement) {
    return const SizedBox.shrink();
  }

  @override
  Future<void> dispose() async {
    _statuses.clear();
    _isInitialized = false;
    _logger.log('MemoryAdsService disposed');
  }
}
