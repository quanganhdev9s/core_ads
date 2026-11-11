import 'dart:async';

import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import 'demo_ad_config.dart';
import 'app_ad_profile.dart';
import 'demo_ad_loading.dart';
import 'scripted_demo_ads.dart';
import 'demo_ad_keys.dart';

/// Quản lý ads ở tầng ứng dụng để các màn hình không phải tự khởi tạo CoreAds.
/// Khi tích hợp thật, thay nguồn JSON trong [ScriptedDemoAds] bằng Remote Config.
class DemoAdsController extends ChangeNotifier {
  /// Đăng ký nhận sự kiện tải quảng cáo ngay khi controller được tạo.
  DemoAdsController() {
    CoreAds.addLoadListener(_onAdLoad);
  }

  AdScenarioController? _ads;
  bool _disposed = false;
  bool isMarketingUser = false;
  bool isTestAdDevice = false;
  bool isPremium = false;
  bool isInitializing = false;
  bool isBusy = false;
  String? error;
  int rewardCount = 0;
  bool _splashNeedsFallback = false;
  final List<String> events = [];

  /// Controller của package sau khi [initialize] thành công.
  AdScenarioController get ads => _ads!;

  /// Truy cập kế hoạch quảng cáo đã giải từ JSON cho từng placement.
  AdScenarioCoordinator get scenarios => ads.coordinator;

  /// Cho biết đã có cấu hình ads sẵn sàng để các màn hình sử dụng.
  bool get isReady => _ads != null && !isInitializing;

  /// Splash hết thời gian chờ hoặc không có ad để hiện; Language sẽ dùng fallback.
  void markSplashAdSkipped() {
    _splashNeedsFallback = true;
    log('ads_splash: skipped before show');
  }

  /// Nạp config v2, khởi tạo lại CoreAds và đặt lại log/bộ đếm test.
  Future<void> initialize() async {
    if (isInitializing || isBusy) return;
    isInitializing = true;
    error = null;
    rewardCount = 0;
    _splashNeedsFallback = false;
    events.clear();
    final previous = _ads;
    _ads = null;
    _notify();
    previous?.dispose();

    AdScenarioController? loaded;
    try {
      loaded = ScriptedDemoAds.loadConfig(
        selectAppAdScenario(
          demoAdConfigJson,
          isMarketingUser: isMarketingUser,
          isTestAdDevice: isTestAdDevice,
          isPremium: isPremium,
        ),
      );
      final result = await loaded.initialize();
      if (_disposed) {
        loaded.dispose();
        return;
      }
      if (result case AdFailed<void>(failure: final failure)) {
        loaded.dispose();
        error = 'Initialize: ${failure.code} — ${failure.message}';
        return;
      }
      _ads = loaded;
      log('Loaded config v2: ${ads.script.placements.length} placements');
    } catch (exception) {
      loaded?.dispose();
      error = 'Script error: $exception';
    } finally {
      isInitializing = false;
      _notify();
    }
  }

  /// Đổi nhóm user giả lập rồi nạp lại JSON để kiểm tra ads_profile.
  Future<void> setAudience({
    bool? marketing,
    bool? testDevice,
    bool? premium,
  }) async {
    if (isBusy || isInitializing) return;
    isMarketingUser = marketing ?? isMarketingUser;
    isTestAdDevice = testDevice ?? isTestAdDevice;
    isPremium = premium ?? isPremium;
    await initialize();
  }

  /// Áp dụng lại config v2 mà vẫn giữ bộ đếm gọi inter của phiên hiện tại.
  /// Chỉ gọi khi đang ở Overview, nơi không có ad slot đang hiển thị.
  Future<void> applyConfigLive() async {
    if (!isReady || isBusy) return;
    isBusy = true;
    _notify();
    try {
      final result = await ads.applyRemoteJson(
        demoAdConfigJson,
        scenario: selectAppAdScenario(
          demoAdConfigJson,
          isMarketingUser: isMarketingUser,
          isTestAdDevice: isTestAdDevice,
          isPremium: isPremium,
        ),
      );
      if (result.isFailure) {
        log('Apply config v2: ${_resultText(result)}');
        return;
      }
      log('Applied config v2 without resetting inter call counts');
    } catch (exception) {
      log('Apply config v2: $exception');
    } finally {
      isBusy = false;
      _notify();
    }
  }

  /// Chạy kịch bản fullscreen của [key], bao gồm inter/app open và native tiếp theo.
  /// [onComplete] chạy sau khi kịch bản kết thúc, kể cả khi ad bị bỏ qua hoặc
  /// không hiện được; màn hình dùng callback này để tiếp tục điều hướng.
  Future<void> showFullscreenAds(
    BuildContext context,
    String key, {
    VoidCallback? onComplete,
    bool preloadNextAd = true,
  }) async {
    if (!isReady || isBusy) return;
    isBusy = true;
    _notify();
    try {
      final effectiveKey =
          key == DemoAdKeys.interLanguage &&
              _splashNeedsFallback &&
              ads.script.settings.splashFallback == DemoAdKeys.interLanguage
          ? DemoAdKeys.interLanguageFallback
          : key;
      if (key == DemoAdKeys.interLanguage) _splashNeedsFallback = false;
      final plan = ads.resolve(effectiveKey);
      log(
        '$effectiveKey → ${plan.steps.map((step) => step.branch).join(' → ')}',
      );
      final result = await ads.showFullscreenAds(
        context,
        effectiveKey,
        loading: const DemoAdLoading(),
        preloadNextAd: preloadNextAd,
        onBeforeInterstitialShow: (placement) =>
            _showInterstitialToast(context, placement.key),
      );
      if (result.fullscreenResult != null) {
        log('show $key: ${_resultText(result.fullscreenResult!)}');
      }
      log('native shown: ${result.nativeAdShown}');
      if (key == DemoAdKeys.adsSplash) {
        _splashNeedsFallback =
            result.fullscreenResult?.isSuccess != true && !result.nativeAdShown;
      }
      if (context.mounted) onComplete?.call();
    } catch (exception) {
      log('$key: $exception');
    } finally {
      isBusy = false;
      _notify();
    }
  }

  /// Tải reward/reward_inter nếu cần, hiển thị ad và đếm khi nhận thưởng.
  /// Placement phải có một bước rewarded được bật trong config hiện tại.
  Future<void> showReward(String key) async {
    if (!isReady || isBusy) return;
    AdScenarioStep? reward;
    for (final step in ads.resolve(key).steps) {
      if (step.placement.type == AdType.rewarded ||
          step.placement.type == AdType.rewardedInterstitial) {
        reward = step;
        break;
      }
    }
    if (reward == null) {
      log('$key: disabled or no rewarded step');
      return;
    }
    isBusy = true;
    _notify();
    try {
      if (!CoreAds.canShow(reward.placement)) {
        final loaded = await CoreAds.load(reward.placement);
        if (loaded.isFailure) {
          log('$key load: ${_resultText(loaded)}');
          return;
        }
      }
      void onRewardEarned() {
        rewardCount++;
        log('$key: reward earned');
      }

      final result = reward.placement.type == AdType.rewardedInterstitial
          ? await CoreAds.showRewardedInterstitial(
              placement: reward.placement,
              onRewardEarned: onRewardEarned,
            )
          : await CoreAds.showRewarded(
              placement: reward.placement,
              onRewardEarned: onRewardEarned,
            );
      log('$key show: ${_resultText(result)}');
    } catch (exception) {
      log('$key: $exception');
    } finally {
      isBusy = false;
      _notify();
    }
  }

  /// Mở riêng một bước native dạng toàn màn hình từ Native Catalog.
  /// Route đóng qua callback của AdsFullScreenNative và ghi lại sự kiện hiển thị.
  Future<void> openNativeStep(BuildContext context, AdScenarioStep step) async {
    if (isBusy) return;
    isBusy = true;
    _notify();
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (routeContext) => Scaffold(
            body: AdsFullScreenNative(
              step: step,
              onClose: () => Navigator.of(routeContext).pop(),
              onVisible: () => log('${step.placement.key}: visible'),
              onFailed: (failure) =>
                  log('${step.placement.key}: ${failure.code}'),
            ),
          ),
        ),
      );
    } finally {
      isBusy = false;
      _notify();
    }
  }

  /// Thêm một sự kiện mới vào đầu danh sách và chỉ giữ 40 sự kiện gần nhất.
  void log(String message) {
    if (_disposed) return;
    events.insert(0, message);
    if (events.length > 40) events.removeLast();
    _notify();
  }

  /// Cập nhật UI nếu controller chưa bị giải phóng.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Chuyển sự kiện tải của CoreAds thành dòng log dễ đọc trong example.
  void _onAdLoad(AdsLoadEvent event) =>
      log('${event.placement.key}: ${event.status.name}');

  /// Rút gọn kết quả quảng cáo thành success hoặc mã lỗi để ghi log.
  String _resultText(AdResult<void> result) => switch (result) {
    AdSuccess<void>() => 'success',
    AdFailed<void>(failure: final failure) => failure.code,
  };

  /// Hiện tên placement mà không trì hoãn lệnh show inter.
  /// Callback này không chạy nếu inter bị bỏ qua bởi nhịp `step` hoặc tải thất bại.
  Future<void> _showInterstitialToast(
    BuildContext context,
    String placementKey,
  ) {
    if (!context.mounted) return Future<void>.value();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 24,
        right: 24,
        bottom: 72,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: const Color(0xE6111827),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  'INTER · $placementKey',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    Timer(const Duration(seconds: 4), () {
      entry.remove();
      entry.dispose();
    });
    return Future<void>.value();
  }

  /// Hủy listener, controller của package và tài nguyên CoreAds khi thoát app.
  @override
  void dispose() {
    _disposed = true;
    CoreAds.removeLoadListener(_onAdLoad);
    _ads?.dispose();
    unawaited(CoreAds.dispose());
    super.dispose();
  }
}
