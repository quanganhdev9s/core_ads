import 'package:flutter/material.dart';

import '../ads/native/ads_full_screen_native.dart';
import '../ads/native/native_ad_type.dart';
import '../app_ads.dart';
import '../core/config/ad_placement.dart';
import '../core/config/ads_config.dart';
import '../core/config/ad_unit_ids.dart';
import '../core/enums/ad_type.dart';
import '../core/fullscreen/fullscreen_ad_cooldown_config.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import 'ad_scenario_coordinator.dart';
import 'ad_script.dart';
import 'ad_script_diagnostics.dart';
import 'ad_scenario_keys.dart';

/// App tạo [AdsConfig] từ danh sách ID mà script đang chọn.
typedef ScenarioAdsConfigBuilder = AdsConfig Function(AdUnitIds ids);

/// Hàm khởi tạo CoreAds; có thể thay bằng bản giả trong test.
typedef ScenarioAdsInitializer =
    Future<AdResult<void>> Function(AdsConfig config);

/// Giữ script đang chạy và thông báo cho các ad slot khi cấu hình đổi.
///
/// App tự fetch Remote Config rồi gọi [applyRemoteJson] ở thời điểm an toàn.
/// Khi ID thay đổi, việc khởi tạo lại CoreAds có thể giải phóng ad đang hiện.
final class AdScenarioController extends ChangeNotifier {
  AdScenarioController({
    required AdScript initialScript,
    required this.resolveAdUnitIds,
    required this.buildAdsConfig,
    String? defaultNativeFactoryId,
    String? expandedCollapseFactoryId,
    String? collapsedNativeFactoryId,
    ScenarioAdsInitializer? initializeAds,
  }) : defaultNativeFactoryId =
           defaultNativeFactoryId ?? NativeAdType.small1.factoryId,
       expandedCollapseFactoryId =
           expandedCollapseFactoryId ?? NativeAdType.big4.factoryId,
       collapsedNativeFactoryId =
           collapsedNativeFactoryId ?? NativeAdType.small1.factoryId,
       _initializeAds = initializeAds ?? CoreAds.initialize,
       _script = initialScript {
    _coordinator = _makeCoordinator(initialScript);
  }

  final AdUnitIdResolver resolveAdUnitIds;
  final ScenarioAdsConfigBuilder buildAdsConfig;
  final String defaultNativeFactoryId;
  final String expandedCollapseFactoryId;
  final String collapsedNativeFactoryId;
  final ScenarioAdsInitializer _initializeAds;
  final AdInterstitialCallCounter _callCounter = AdInterstitialCallCounter();
  int _onboardingTransitionCount = 0;

  late AdScenarioCoordinator _coordinator;
  AdScript _script;
  bool _initialized = false;
  bool _busy = false;
  int _revision = 0;
  AdFailure? lastError;

  AdScript get script => _script;
  AdScenarioCoordinator get coordinator => _coordinator;
  bool get isInitialized => _initialized;

  /// Tăng sau mỗi lần khởi tạo/cập nhật thành công để widget dựng lại.
  int get revision => _revision;

  AdScenarioPlan resolve(String key) => _coordinator.resolve(key);

  /// Gọi khi bắt đầu lại luồng onboarding để đếm chuyển màn từ 1.
  void resetNativeFullOnboarding() => _onboardingTransitionCount = 0;

  /// Hiện inter hoặc app-open rồi mở route native toàn màn hình nếu plan có.
  ///
  /// App quyết định lúc gọi và màn sản phẩm tiếp theo. Native vẫn được mở
  /// khi inter bị bỏ qua bởi `step_count` hoặc tải/hiện thất bại.
  /// Với [AdScenarioKeys.nativeFullOnboarding], gọi sau mỗi màn onboarding; chỉ lần thứ
  /// `enable` mới mở native toàn màn hình.
  /// [onBeforeInterstitialShow] chỉ chạy khi inter đã qua `step_count` và
  /// tải thành công, ngay trước lệnh show thực tế.
  Future<AdScenarioShowResult> showScenario(
    BuildContext context,
    String key, {
    Future<void> Function(AdPlacement placement)? onBeforeInterstitialShow,
  }) async {
    final plan = resolve(key);
    if (plan.inlineMode != null) {
      throw ArgumentError.value(key, 'key', 'Inline ads belong in CoreAdSlot');
    }
    if (key == AdScenarioKeys.nativeFullOnboarding) {
      _onboardingTransitionCount++;
      if (_onboardingTransitionCount != plan.enable) {
        return AdScenarioShowResult(plan: plan, nativeAdShown: false);
      }
    }
    if (!plan.isEnabled) {
      return AdScenarioShowResult(plan: plan, nativeAdShown: false);
    }

    AdResult<void>? fullscreenResult;
    if (plan.interstitial != null) {
      fullscreenResult = await _coordinator.showInterstitial(
        key,
        loadIfNeeded: true,
        onBeforeShow: onBeforeInterstitialShow,
      );
    } else {
      for (final step in plan.steps) {
        if (step.placement.type != AdType.appOpen) continue;
        if (!CoreAds.canShow(step.placement)) {
          final loaded = await CoreAds.load(step.placement);
          if (loaded.isFailure) {
            fullscreenResult = loaded;
            break;
          }
        }
        fullscreenResult = await CoreAds.showAppOpen(step.placement);
        break;
      }
    }

    var nativeAdShown = false;
    final native = plan.native;
    if (native != null && context.mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (routeContext) => Scaffold(
            body: AdsFullScreenNative(
              step: native,
              onVisible: () => nativeAdShown = true,
              onClose: () => Navigator.of(routeContext).pop(),
            ),
          ),
        ),
      );
    }
    return AdScenarioShowResult(
      plan: plan,
      fullscreenResult: fullscreenResult,
      nativeAdShown: nativeAdShown,
    );
  }

  /// Khởi tạo CoreAds bằng ID và cooldown lấy từ script ban đầu.
  Future<AdResult<void>> initialize() async {
    if (_busy) return _busyResult();
    _busy = true;
    try {
      final result = await _initializeAds(
        _configForScript(_script, _coordinator),
      );
      lastError = switch (result) {
        AdFailed<void>(failure: final failure) => failure,
        AdSuccess<void>() => null,
      };
      if (result.isSuccess) {
        _initialized = true;
        _revision++;
        notifyListeners();
      }
      return result;
    } catch (error) {
      lastError = AdFailure.unknown('Could not initialize ad scenario', error);
      return AdResult.failure(lastError!);
    } finally {
      _busy = false;
    }
  }

  /// Đọc JSON mới và chỉ công bố script sau khi khởi tạo ID map thành công.
  ///
  /// JSON sai toàn bộ hoặc khởi tạo thất bại thì giữ script và ID map cũ.
  /// Placement sai riêng lẻ được log và tắt trong script mới.
  Future<AdResult<void>> applyRemoteJson(String source) async {
    if (_busy) return _busyResult();
    _busy = true;
    try {
      final nextScript = AdScript.parse(source);
      final nextCoordinator = _makeCoordinator(nextScript);
      if (_initialized) {
        final result = await _initializeAds(
          _configForScript(nextScript, nextCoordinator),
        );
        if (result case AdFailed<void>(failure: final failure)) {
          lastError = failure;
          return result;
        }
      }
      _script = nextScript;
      _coordinator = nextCoordinator;
      lastError = null;
      _revision++;
      notifyListeners();
      return const AdResult.success(null);
    } on FormatException catch (error) {
      logAdScriptError('script', error.message, action: 'previous script kept');
      lastError = AdFailure(
        code: 'invalid_ad_script',
        message: error.message,
        cause: error,
      );
      return AdResult.failure(lastError!);
    } catch (error) {
      lastError = AdFailure.unknown('Could not apply ad script', error);
      return AdResult.failure(lastError!);
    } finally {
      _busy = false;
    }
  }

  AdScenarioCoordinator _makeCoordinator(AdScript script) =>
      AdScenarioCoordinator(
        script: script,
        resolveAdUnitIds: resolveAdUnitIds,
        defaultNativeFactoryId: defaultNativeFactoryId,
        expandedCollapseFactoryId: expandedCollapseFactoryId,
        collapsedNativeFactoryId: collapsedNativeFactoryId,
        callCounter: _callCounter,
      );

  /// Áp `inter_delay_time` vào cooldown có sẵn, giữ các khoảng app-open của app.
  AdsConfig _configForScript(
    AdScript script,
    AdScenarioCoordinator coordinator,
  ) {
    final base = buildAdsConfig(coordinator.buildAdUnitIds());
    final gap = script.settings.interDelayTime;
    if (gap == null) return base;

    final cooldown = base.fullscreenCooldown;
    return base.withFullscreenCooldown(
      FullscreenAdCooldownConfig(
        interstitialInterval: gap.interval,
        ignoredInterstitialPlacementKeys: {
          for (final key in gap.ignoredScenarioKeys) '$key.inter',
        },
        appOpenInterval: cooldown.appOpenInterval,
        interstitialAppOpenInterval: cooldown.interstitialAppOpenInterval,
      ),
    );
  }

  AdResult<void> _busyResult() => const AdResult.failure(
    AdFailure(
      code: 'scenario_update_in_progress',
      message: 'Another ad scenario operation is in progress.',
    ),
  );
}

/// Kết quả của một lần gọi [AdScenarioController.showScenario].
///
/// [fullscreenResult] là kết quả inter/app-open; [nativeAdShown] cho biết
/// native toàn màn hình đã thực sự xuất hiện hay chưa.
final class AdScenarioShowResult {
  const AdScenarioShowResult({
    required this.plan,
    required this.nativeAdShown,
    this.fullscreenResult,
  });

  final AdScenarioPlan plan;
  final AdResult<void>? fullscreenResult;
  final bool nativeAdShown;
}
