import '../core/config/ad_placement.dart';
import '../core/config/ad_unit_ids.dart';
import '../core/enums/ad_type.dart';
import '../core/results/ad_failure.dart';
import '../core/results/ad_result.dart';
import '../app_ads.dart';
import '../ads/native/native_ad_template.dart';
import '../ads/native/native_ad_type.dart';
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
    String? defaultNativeFactoryId,
    String? expandedCollapseFactoryId,
    String? collapsedNativeFactoryId,
    AdInterstitialCallCounter? callCounter,
  }) : defaultNativeFactoryId =
           defaultNativeFactoryId ?? NativeAdType.small1.factoryId,
       expandedCollapseFactoryId =
           expandedCollapseFactoryId ?? NativeAdType.big4.factoryId,
       collapsedNativeFactoryId =
           collapsedNativeFactoryId ?? NativeAdType.small1.factoryId,
       _callCounter = callCounter ?? AdInterstitialCallCounter();

  final AdScript script;
  final AdUnitIdResolver resolveAdUnitIds;

  final String defaultNativeFactoryId;
  final String expandedCollapseFactoryId;
  final String collapsedNativeFactoryId;
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
      if (key == 'on_resume') {
        final mode = script.settings.onResume ?? 0;
        return AdScenarioPlan(
          key: key,
          enable: mode,
          steps: const [],
          resumeMode: mode == 0 ? null : mode,
        );
      }
      if (_missingKeysLogged.add(key)) {
        logAdScriptError(key, 'Placement is missing from the script');
      }
      return AdScenarioPlan(key: key, enable: 0, steps: const []);
    }
    if (source.enable == 0) {
      return AdScenarioPlan(key: key, enable: source.enable, steps: const []);
    }

    if (key == 'on_resume') {
      return AdScenarioPlan(
        key: key,
        enable: source.enable,
        steps: const [],
        resumeMode: source.enable,
      );
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
          ),
          ids: List.unmodifiable(ids.where((id) => id.trim().isNotEmpty)),
          refreshRate: type == AdType.native ? source.refreshRate : null,
          waitTime: source.waitTime,
          stepCount: type == AdType.interstitial ? source.stepCount : null,
          collapseClickCounts:
              type == AdType.native &&
                  ((key.startsWith('banner_') &&
                          (source.enable == 2 || source.enable == 4)) ||
                      NativeAdTemplate.forFactory(template).isCollapsible)
              ? source.collapseClickCounts
              : const <int>{},
        ),
      );
      final hasNativeCollapse =
          type == AdType.native &&
          ((key.startsWith('banner_') && source.enable == 4) ||
              (key.startsWith('native_') &&
                  branch == 'native' &&
                  NativeAdTemplate.forFactory(template).isCollapsible));
      if (hasNativeCollapse) {
        steps.add(
          AdScenarioStep(
            branch: 'native_small',
            placement: AdPlacement(
              key: '$key.native_small',
              type: AdType.native,
              nativeFactoryId:
                  NativeAdTemplate.forFactory(template).collapsedFactoryId ??
                  collapsedNativeFactoryId,
            ),
            ids: List.unmodifiable(ids.where((id) => id.trim().isNotEmpty)),
            collapseClickCounts: const <int>{},
          ),
        );
      }
    }
    return AdScenarioPlan(
      key: key,
      enable: source.enable,
      steps: List.unmodifiable(steps),
    );
  }

  String _nativeFactoryIdFor(AdScriptPlacement source, String branch) {
    if (source.key == 'native_language' || source.key == 'native_get_start') {
      if (branch == '${source.key}1') {
        return NativeAdType.languageStart1.factoryId;
      }
      if (branch == '${source.key}2') {
        return NativeAdType.languageStart2.factoryId;
      }
    }
    if (source.nativeTemplate?.isNotEmpty == true) {
      return source.nativeTemplate!;
    }
    if (branch == 'native_inter' ||
        source.key == AdScenarioKeys.nativeFullOnboarding) {
      return NativeAdType.full1.factoryId;
    }
    if (source.key.startsWith('banner_') &&
        (source.enable == 2 || source.enable == 4)) {
      return expandedCollapseFactoryId;
    }
    return defaultNativeFactoryId;
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

  /// Tải trước các bước đã chọn theo thứ tự trong script; không tăng step_count.
  Future<Map<AdPlacement, AdResult<void>>> preload(String key) async {
    final results = <AdPlacement, AdResult<void>>{};
    for (final step in resolve(key).steps) {
      results[step.placement] = await CoreAds.load(step.placement);
    }
    return results;
  }

  /// Tăng số lần gọi logic của inter và chỉ thử hiện ở nhịp `step_count`.
  ///
  /// Mỗi placement có bộ đếm riêng. Dùng chung [AdInterstitialCallCounter]
  /// để giữ số đếm khi cập nhật script. Lần chưa đến nhịp trả
  /// `step_count_skipped`; lần đến nhịp trả kết quả show thực tế.
  /// [onBeforeShow] chỉ chạy khi ad sẵn sàng và sắp được show.
  Future<AdResult<void>> showInterstitial(
    String key, {
    bool loadIfNeeded = false,
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
        final loadResult = await CoreAds.load(step.placement);
        if (loadResult.isFailure) return loadResult;
      }
      if (onBeforeShow != null) await onBeforeShow(step.placement);
      return CoreAds.showInterstitial(step.placement);
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
  });

  final String key;
  final int enable;
  final List<AdScenarioStep> steps;

  /// `1` chọn on-resume; `2` chọn luồng welcome-back.
  final int? resumeMode;
  bool get isEnabled => steps.isNotEmpty || resumeMode != null;

  /// Cách dựng ad inline theo chế độ banner hoặc native collapse.
  AdInlineMode? get inlineMode {
    if (enable == 0) return null;
    if (key.startsWith('native_') && collapsedNative != null) {
      return AdInlineMode.collapsibleNative;
    }
    if (!key.startsWith('banner_')) return null;
    return switch (enable) {
      1 => AdInlineMode.banner,
      2 => AdInlineMode.collapsibleBanner,
      3 => AdInlineMode.native,
      4 => AdInlineMode.collapsibleNative,
      _ => null,
    };
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
      if (step.branch == 'native_intro$screen') return step;
    }
    return null;
  }
}

/// Các kiểu hiển thị tại một vị trí ad nằm trong màn hình app.
enum AdInlineMode { banner, collapsibleBanner, native, collapsibleNative }

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
  if (branch.startsWith('reward')) return AdType.rewarded;
  throw FormatException('Unknown ad unit branch: $branch');
}
