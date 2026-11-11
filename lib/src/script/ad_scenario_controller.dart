import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/native/ads_full_screen_native.dart';
import '../ads/native/native_ad_type.dart';
import '../app_ads.dart';
import '../core/config/ad_placement.dart';
import '../core/config/ads_config.dart';
import '../core/config/ad_unit_ids.dart';
import '../core/enums/ad_type.dart';
import '../core/enums/ad_load_status.dart';
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
    String? bannerNativeFactoryId,
    String? expandedCollapseFactoryId,
    String? collapsedNativeFactoryId,
    ScenarioAdsInitializer? initializeAds,
    this.useTestIds = false,
  }) : bannerNativeFactoryId =
           bannerNativeFactoryId ??
           NativeAdFactoryDefaults.bannerNative.factoryId,
       expandedCollapseFactoryId =
           expandedCollapseFactoryId ??
           NativeAdFactoryDefaults.expandedCollapse.factoryId,
       collapsedNativeFactoryId =
           collapsedNativeFactoryId ??
           NativeAdFactoryDefaults.collapsedCollapse.factoryId,
       _initializeAds = initializeAds ?? CoreAds.initialize {
    _coordinator = _makeCoordinator(initialScript);
  }

  final AdUnitIdResolver resolveAdUnitIds;
  final ScenarioAdsConfigBuilder buildAdsConfig;
  final String bannerNativeFactoryId;
  final String expandedCollapseFactoryId;
  final String collapsedNativeFactoryId;
  final ScenarioAdsInitializer _initializeAds;
  final bool useTestIds;
  final AdInterstitialCallCounter _callCounter = AdInterstitialCallCounter();
  int _onboardingTransitionCount = 0;

  late AdScenarioCoordinator _coordinator;
  bool _initialized = false;
  bool _busy = false;
  int _revision = 0;
  AdFailure? lastError;

  AdScript get script => _coordinator.script;
  AdScenarioCoordinator get coordinator => _coordinator;
  bool get isInitialized => _initialized;

  /// Tăng sau mỗi lần khởi tạo/cập nhật thành công để widget dựng lại.
  int get revision => _revision;

  AdScenarioPlan resolve(String key) => _coordinator.resolve(key);

  /// Tải tất cả bước được bật của [key] theo config hiện tại.
  /// Kết quả rỗng nếu key tắt/thiếu hoặc không có bước cần tải.
  /// Không tăng bộ đếm `step` của inter.
  Future<Map<AdPlacement, AdResult<void>>> preloadScenario(String key) =>
      _coordinator.preload(key);

  /// Chỉ tải các native placement được bật của [key].
  /// Ví dụ `inter_home` tải native kế tiếp mà không tải inter.
  Future<Map<AdPlacement, AdResult<void>>> preloadNative(String key) =>
      _coordinator.preload(key, onlyType: AdType.native);

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
  /// [loading] do app cung cấp, phủ toàn màn hình khi phải đợi tải inter hoặc
  /// app-open; cũng được dùng trong route native toàn màn hình khi native tải.
  /// [preloadNextAd] tải trước native tiếp theo khi inter/app-open bắt đầu show.
  /// [skipInterstitial] chỉ bỏ bước inter; native tiếp theo vẫn được hiển thị.
  /// [readyTimeout] giới hạn thời gian chờ tải inter/app-open trước khi show.
  /// [onAdReady] chạy sau khi ad sẵn sàng.
  Future<AdScenarioShowResult> showFullscreenAds(
    BuildContext context,
    String key, {
    Widget? loading,
    bool preloadNextAd = true,
    bool skipInterstitial = false,
    Future<void> Function(AdPlacement placement)? onBeforeInterstitialShow,
    Future<void> Function()? onAdReady,
    Duration? readyTimeout,
  }) async {
    final plan = resolve(key);
    if (plan.inlineMode != null) {
      throw ArgumentError.value(key, 'key', 'Inline ads belong in CoreAdSlot');
    }
    if (key == AdScenarioKeys.nativeFullOnboarding) {
      _onboardingTransitionCount++;
      final pages = script[key]?.pages ?? const <int>{};
      if (!pages.contains(_onboardingTransitionCount)) {
        return AdScenarioShowResult(plan: plan, nativeAdShown: false);
      }
    }
    if (!plan.isEnabled) {
      return AdScenarioShowResult(plan: plan, nativeAdShown: false);
    }

    final native = plan.native;
    var readyReported = false;
    Future<void> reportReady() async {
      if (readyReported) return;
      readyReported = true;
      await onAdReady?.call();
    }

    Future<AdResult<void>> loadAd(AdPlacement placement) {
      final loadingAd = CoreAds.load(placement);
      if (readyTimeout case final timeout?) {
        return loadingAd.timeout(
          timeout,
          onTimeout: () => const AdResult.failure(AdFailure.notReady()),
        );
      }
      return loadingAd;
    }

    void preloadFollowingNative() {
      if (!preloadNextAd || native == null) return;
      final placement = native.placement;
      final status = CoreAds.getStatus(placement);
      if (status == AdLoadStatus.ready || status == AdLoadStatus.loading) {
        return;
      }
      unawaited(_preloadNextNative(placement));
    }

    AdResult<void>? fullscreenResult;
    _FullscreenLoadingRoute? loadingRoute;
    if (plan.interstitial != null && !skipInterstitial) {
      try {
        fullscreenResult = await _coordinator.showInterstitial(
          key,
          loadIfNeeded: true,
          loadAd: (placement) {
            loadingRoute = _openLoadingRoute(context, placement, loading);
            return loadAd(placement);
          },
          onShown: () => loadingRoute?.close(),
          onShowStarted: (_) => preloadFollowingNative(),
          onBeforeShow: (placement) async {
            await onBeforeInterstitialShow?.call(placement);
            await reportReady();
          },
        );
      } finally {
        loadingRoute?.close();
      }
    } else {
      for (final step in plan.steps) {
        if (step.placement.type != AdType.appOpen) continue;
        if (!context.mounted) break;
        try {
          if (!CoreAds.canShow(step.placement)) {
            loadingRoute = _openLoadingRoute(context, step.placement, loading);
            final loaded = await loadAd(step.placement);
            if (loaded.isFailure) {
              fullscreenResult = loaded;
              break;
            }
          }
          await reportReady();
          final showing = CoreAds.showAppOpen(
            step.placement,
            onShown: () => loadingRoute?.close(),
          );
          preloadFollowingNative();
          fullscreenResult = await showing;
        } finally {
          loadingRoute?.close();
        }
        break;
      }
    }

    var nativeAdShown = false;
    if (native != null && context.mounted) {
      await reportReady();
      if (!context.mounted) {
        return AdScenarioShowResult(
          plan: plan,
          fullscreenResult: fullscreenResult,
          nativeAdShown: false,
        );
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (routeContext) => Scaffold(
            body: AdsFullScreenNative(
              step: native,
              loading: loading,
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

  Future<void> _preloadNextNative(AdPlacement placement) async {
    try {
      await CoreAds.load(placement);
    } catch (_) {
      // AdsNative sẽ thử lại khi route mở nếu lần tải trước gặp lỗi.
    }
  }

  _FullscreenLoadingRoute? _openLoadingRoute(
    BuildContext context,
    AdPlacement placement,
    Widget? loading,
  ) {
    if (loading == null ||
        !context.mounted ||
        CoreAds.getStatus(placement) == AdLoadStatus.ready) {
      return null;
    }
    return _FullscreenLoadingRoute.open(context, loading);
  }

  /// Khởi tạo CoreAds bằng ID và cooldown lấy từ script ban đầu.
  Future<AdResult<void>> initialize() async {
    if (_busy) return _busyResult();
    _busy = true;
    try {
      final result = await _initializeAds(_configForScript(_coordinator));
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
  Future<AdResult<void>> applyRemoteJson(
    String source, {
    AdScriptScenario? scenario,
    String? pagesJson,
  }) async {
    if (_busy) return _busyResult();
    _busy = true;
    try {
      final nextScript = AdScript.parse(
        source,
        scenario: scenario ?? script.scenario,
        pagesJson: pagesJson,
        useTestIds: useTestIds,
      );
      final nextCoordinator = _makeCoordinator(nextScript);
      if (_initialized) {
        final result = await _initializeAds(_configForScript(nextCoordinator));
        if (result case AdFailed<void>(failure: final failure)) {
          lastError = failure;
          return result;
        }
      }
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
        bannerNativeFactoryId: bannerNativeFactoryId,
        expandedCollapseFactoryId: expandedCollapseFactoryId,
        callCounter: _callCounter,
      );

  /// Áp các fullscreen gap của config v2 vào cooldown hiện có.
  AdsConfig _configForScript(AdScenarioCoordinator coordinator) {
    final script = coordinator.script;
    final base = buildAdsConfig(coordinator.buildAdUnitIds());
    final gap = script.settings.gapFor(script.scenario);
    final cooldown = base.fullscreenCooldown;
    return base.withFullscreenCooldown(
      FullscreenAdCooldownConfig(
        interstitialInterval: gap.interval,
        ignoredInterstitialPlacementKeys: {
          for (final key in gap.ignoredScenarioKeys) '$key.inter',
        },
        appOpenInterval:
            script.settings.appOpenGapFor(script.scenario) ??
            cooldown.appOpenInterval,
        interstitialAppOpenInterval:
            script.settings.interstitialAppOpenGapFor(script.scenario) ??
            cooldown.interstitialAppOpenInterval,
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

/// Giữ route loading cho đến khi SDK báo ad đã hiện hoặc lần show kết thúc.
final class _FullscreenLoadingRoute {
  _FullscreenLoadingRoute._(this.navigator, this.route);

  final NavigatorState navigator;
  final PageRoute<void> route;
  bool _closed = false;

  static _FullscreenLoadingRoute open(BuildContext context, Widget loading) {
    final navigator = Navigator.of(context);
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final route = PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => PopScope(
        canPop: false,
        child: Material(
          color: backgroundColor,
          child: SizedBox.expand(child: loading),
        ),
      ),
    );
    final session = _FullscreenLoadingRoute._(navigator, route);
    navigator.push(route);
    return session;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (navigator.mounted && route.isActive) navigator.removeRoute(route);
  }
}

/// Kết quả của một lần gọi [AdScenarioController.showFullscreenAds].
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
