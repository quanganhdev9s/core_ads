import '../core/config/ad_placement.dart';
import '../core/config/ad_unit_ids.dart';
import '../core/enums/ad_type.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import '../app_ads.dart';
import '../ads/native/native_ad_template.dart';
import '../ads/native/native_ad_type.dart';
import 'ad_config_enums.dart';
import 'ad_script.dart';
import 'ad_script_diagnostics.dart';
import 'ad_scenario_keys.dart';

/// App đổi tên ký hiệu trong Remote Config thành ad unit ID theo môi trường.
typedef AdUnitIdResolver = List<String> Function(String name, AdType type);

/// Biến một key logic trong script thành các bước quảng cáo dùng CoreAds.
///
/// Mỗi bước có một [AdPlacement] và một định dạng ad cụ thể. Coordinator
/// chọn ID/factory và quản lý nhịp `step_count`, còn điều hướng màn hình thuộc
/// app hoặc `AdScenarioController`.
final class AdScenarioCoordinator {
  AdScenarioCoordinator({
    required this.script,
    required this.resolveAdUnitIds,
    String? bannerNativeFactoryId,
    String? expandedCollapseFactoryId,
    AdInterstitialCallCounter? callCounter,
  }) : bannerNativeFactoryId =
           bannerNativeFactoryId ??
           NativeAdFactoryDefaults.bannerNative.factoryId,
       expandedCollapseFactoryId =
           expandedCollapseFactoryId ??
           NativeAdFactoryDefaults.expandedCollapse.factoryId,
       _callCounter = callCounter ?? AdInterstitialCallCounter();

  final AdScript script;
  final AdUnitIdResolver resolveAdUnitIds;

  final String bannerNativeFactoryId;
  final String expandedCollapseFactoryId;
  final AdInterstitialCallCounter _callCounter;
  // Mỗi key thiếu hoặc sai chỉ log một lần trong vòng đời coordinator.
  final Set<String> _missingKeysLogged = <String>{};
  final Set<String> _invalidKeysLogged = <String>{};

  /// Dựng kế hoạch từ các nhánh đã được parser chọn trong `selectedBranches`.
  /// Key sai hoặc thiếu trả về plan tắt để không chặn luồng màn hình.
  AdScenarioPlan resolve(String key) {
    try {
      return _resolve(key);
    } on FormatException catch (error) {
      if (_invalidKeysLogged.add(key)) {
        logAdScriptError(key, error.message);
      }
      return AdScenarioPlan(key: key, enable: 0, steps: const []);
    }
  }

  AdScenarioPlan _resolve(String key) {
    final source = script[key];
    if (source == null) {
      if (_missingKeysLogged.add(key)) {
        logAdScriptError(key, 'Placement is missing from the script');
      }
      return AdScenarioPlan(key: key, enable: 0, steps: const []);
    }
    if (source.enable == 0) {
      return AdScenarioPlan(key: key, enable: source.enable, steps: const []);
    }

    // Parser đã hiểu `enable`; tầng này chỉ chuyển nhánh thành placement/ID.
    final branches = source.selectedBranches;
    final steps = <AdScenarioStep>[];
    for (final branch in branches) {
      final unit = source.unit(branch);
      if (unit == null) continue;
      final type = _typeForBranch(branch);
      final ids = <String>[];
      if (unit.ids.isNotEmpty) {
        ids.addAll(unit.ids);
      } else {
        for (final name in unit.names) {
          try {
            ids.addAll(resolveAdUnitIds(name, type));
          } catch (error) {
            throw FormatException(
              '$key.$branch could not resolve ad unit $name: $error',
            );
          }
        }
      }
      if (ids.every((id) => id.trim().isEmpty)) {
        throw FormatException('$key.$branch has no resolved ad unit IDs');
      }
      final template = type == AdType.native
          ? _nativeFactoryIdFor(source, branch)
          : null;
      steps.add(
        AdScenarioStep(
          branch: branch,
          placement: AdPlacement(
            key: '$key.$branch',
            type: type,
            nativeFactoryId: template,
            nativeStyle: type == AdType.native
                ? source.nativeStyle ?? script.factoryStyles[template]
                : null,
          ),
          ids: List.unmodifiable(ids.where((id) => id.trim().isNotEmpty)),
          refreshRate: type == AdType.native || type == AdType.banner
              ? source.refreshRate
              : null,
          waitTime: source.waitTime,
          stepCount: type == AdType.interstitial ? source.stepCount : null,
          collapseClickCounts:
              type == AdType.native &&
                  ((source.configType == AdConfigType.banner &&
                          (source.configFormat == AdConfigFormat.native ||
                              source.configFormat ==
                                  AdConfigFormat.nativeCollapsible)) ||
                      NativeAdTemplate.forFactory(template).isCollapsible)
              ? source.collapseClickCounts
              : const <int>{},
        ),
      );
    }
    return AdScenarioPlan(
      key: key,
      enable: source.enable,
      steps: List.unmodifiable(steps),
      resumeMode: key == 'on_resume' ? source.enable : null,
      configType: source.configType,
      format: source.configFormat,
    );
  }

  String _nativeFactoryIdFor(AdScriptPlacement source, String branch) {
    if (source.nativeTemplate?.isNotEmpty == true) {
      return source.nativeTemplate!;
    }
    if (branch == 'native_inter' ||
        source.key == AdScenarioKeys.nativeFullOnboarding) {
      return NativeAdFactoryDefaults.fullScreen.factoryId;
    }
    if (source.configType == AdConfigType.banner &&
        source.configFormat == AdConfigFormat.nativeCollapsible) {
      return expandedCollapseFactoryId;
    }
    return bannerNativeFactoryId;
  }

  /// Gom ID của các bước hợp lệ để truyền vào [CoreAds.initialize].
  AdUnitIds buildAdUnitIds() {
    final values = <AdPlacement, AdUnitId>{};
    for (final key in script.placements.keys) {
      for (final step in resolve(key).steps) {
        if (step.ids.isEmpty) continue;
        values[step.placement] = step.ids.length == 1
            ? AdUnitId.single(step.ids.first)
            : AdUnitId.waterfall(step.ids);
      }
    }
    return AdUnitIds.typed(values);
  }

  /// Tải song song các bước được bật của key; không tăng bộ đếm `step`.
  /// [onlyType] chỉ tải một định dạng, ví dụ native trong kịch bản inter + native.
  Future<Map<AdPlacement, AdResult<void>>> preload(
    String key, {
    AdType? onlyType,
  }) async {
    if (script.scenario == AdScriptScenario.off) {
      return <AdPlacement, AdResult<void>>{};
    }
    final plan = resolve(key);
    if (!plan.isEnabled ||
        key == AdScenarioKeys.nativeFullOnboarding &&
            (script[key]?.pages.isEmpty ?? true)) {
      return <AdPlacement, AdResult<void>>{};
    }
    final steps = plan.steps.where(
      (step) => onlyType == null || step.placement.type == onlyType,
    );
    final entries = await Future.wait(
      steps.map((step) async {
        final placement = step.placement;
        try {
          return MapEntry(placement, await CoreAds.load(placement));
        } catch (error) {
          return MapEntry(
            placement,
            AdResult<void>.failure(
              AdFailure.unknown('Could not preload ${placement.key}', error),
            ),
          );
        }
      }),
    );
    return Map.fromEntries(entries);
  }

  /// Tăng số lần gọi logic của inter và chỉ thử hiện ở nhịp `step_count`.
  ///
  /// Mỗi placement có bộ đếm riêng. Dùng chung [AdInterstitialCallCounter]
  /// để giữ số đếm khi cập nhật script. Lần chưa đến nhịp trả
  /// `step_count_skipped`; lần đến nhịp trả kết quả show thực tế.
  /// [onBeforeShow] chỉ chạy khi ad sẵn sàng và sắp được show.
  /// [onShown] chỉ áp dụng cho lần show này khi SDK xác nhận ad đã hiện.
  /// [onShowStarted] chạy ngay sau khi gửi lệnh show, không đợi ad đóng.
  Future<AdResult<void>> showInterstitial(
    String key, {
    bool loadIfNeeded = false,
    Future<AdResult<void>> Function(AdPlacement placement)? loadAd,
    void Function()? onShown,
    void Function(AdPlacement placement)? onShowStarted,
    Future<void> Function(AdPlacement placement)? onBeforeShow,
  }) async {
    final step = resolve(key).interstitial;
    if (step != null) {
      final count = _callCounter.record(step.placement.key);
      final stepCount = step.stepCount ?? 1;
      if (count % stepCount != 0) {
        return AdResult.failure(
          AdFailure(
            code: 'step_count_skipped',
            message: 'Interstitial skipped at call $count of $stepCount.',
          ),
        );
      }
      if (loadIfNeeded && !CoreAds.canShow(step.placement)) {
        final loadResult = await (loadAd ?? CoreAds.load)(step.placement);
        if (loadResult.isFailure) return loadResult;
      }
      if (onBeforeShow != null) await onBeforeShow(step.placement);
      final showing = CoreAds.showInterstitial(
        step.placement,
        onShown: onShown,
      );
      onShowStarted?.call(step.placement);
      return showing;
    }
    return const AdResult.failure(
      AdFailure(
        code: 'no_interstitial_step',
        message: 'This ad scenario has no interstitial step.',
      ),
    );
  }
}

/// Giữ số lần gọi inter riêng theo placement trong một phiên app.
final class AdInterstitialCallCounter {
  final Map<String, int> _counts = <String, int>{};

  int record(String placementKey) =>
      _counts.update(placementKey, (count) => count + 1, ifAbsent: () => 1);

  int countFor(String placementKey) => _counts[placementKey] ?? 0;
}

/// Kế hoạch của một key logic sau khi giải quyết các nhánh quảng cáo.
///
/// Plan có thể có nhiều bước, ví dụ inter rồi native toàn màn hình, hoặc
/// không có bước nào khi key bị tắt/sai. `on_resume` chỉ mang [resumeMode].
final class AdScenarioPlan {
  const AdScenarioPlan({
    required this.key,
    required this.enable,
    required this.steps,
    this.resumeMode,
    this.configType,
    this.format,
  });

  final String key;
  final int enable;
  final List<AdScenarioStep> steps;

  /// `1` chọn on-resume; `2` chọn luồng welcome-back.
  final int? resumeMode;
  final AdConfigType? configType;
  final AdConfigFormat? format;
  bool get isEnabled => steps.isNotEmpty || resumeMode != null;

  /// Cách dựng ad inline theo chế độ banner hoặc native collapse.
  AdInlineMode? get inlineMode {
    if (enable == 0) return null;
    if (configType == AdConfigType.banner) {
      return switch (format) {
        AdConfigFormat.banner => AdInlineMode.banner,
        AdConfigFormat.bannerCollapsible => AdInlineMode.adMobCollapsibleBanner,
        AdConfigFormat.native => AdInlineMode.native,
        AdConfigFormat.nativeCollapsible => AdInlineMode.collapsibleNative,
        _ => null,
      };
    }
    if (configType == AdConfigType.native && native != null) {
      return NativeAdTemplate.forFactory(
            native!.placement.nativeFactoryId,
          ).isCollapsible
          ? AdInlineMode.collapsibleNative
          : null;
    }
    return null;
  }

  AdScenarioStep? get interstitial {
    for (final step in steps) {
      if (step.placement.type == AdType.interstitial) return step;
    }
    return null;
  }

  AdScenarioStep? get native {
    for (final step in steps) {
      if (step.placement.type == AdType.native) return step;
    }
    return null;
  }

  AdScenarioStep? get collapsedNative {
    for (final step in steps) {
      if (step.branch == 'native_small') return step;
    }
    return null;
  }

  AdScenarioStep? get banner {
    for (final step in steps) {
      if (step.placement.type == AdType.banner) return step;
    }
    return null;
  }

  AdScenarioStep? nativeForIntro(int screen) {
    for (final step in steps) {
      if (step.branch == 'native_onboarding$screen') {
        return step;
      }
    }
    return null;
  }
}

/// Các kiểu hiển thị tại một vị trí ad nằm trong màn hình app.
enum AdInlineMode { banner, adMobCollapsibleBanner, native, collapsibleNative }

/// Một bước ad cụ thể: placement, ID ứng viên và chính sách hiển thị đi kèm.
final class AdScenarioStep {
  const AdScenarioStep({
    required this.branch,
    required this.placement,
    required this.ids,
    required this.collapseClickCounts,
    this.refreshRate,
    this.waitTime,
    this.stepCount,
  });

  final String branch;
  final AdPlacement placement;
  final List<String> ids;
  final Duration? refreshRate;
  final Duration? waitTime;
  final int? stepCount;
  final Set<int> collapseClickCounts;
}

/// Xác định định dạng ad từ tên nhánh đã được chọn trong script.
AdType _typeForBranch(String branch) {
  if (branch == 'app_open') return AdType.appOpen;
  if (branch.startsWith('inter')) return AdType.interstitial;
  if (branch.startsWith('banner')) return AdType.banner;
  if (branch.startsWith('native')) return AdType.native;
  if (branch == 'reward_inter') return AdType.rewardedInterstitial;
  if (branch == 'reward') return AdType.rewarded;
  throw FormatException('Unknown ad unit branch: $branch');
}
