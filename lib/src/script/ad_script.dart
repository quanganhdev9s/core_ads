import 'dart:convert';

import '../ads/native/native_ad_template.dart';
import '../ads/native/native_ad_type.dart';
import '../ads/native/native_ad_style.dart';
import 'ad_config_enums.dart';
import 'ad_scenario_keys.dart';
import 'ad_script_diagnostics.dart';

/// Bộ quảng cáo do app chọn trước khi đưa script vào package.
enum AdScriptScenario { off, full, basic }

/// Bản chụp cấu hình quảng cáo sau khi đọc JSON từ Remote Config.
///
/// App tự fetch và activate Remote Config. Package chỉ nhận chuỗi JSON nên
/// không phụ thuộc dự án Firebase hoặc lịch cập nhật của từng app.
final class AdScript {
  AdScript._({
    required this.settings,
    required this.placements,
    required this.scenario,
    required this.factoryStyles,
  });

  final AdScriptSettings settings;
  final Map<String, AdScriptPlacement> placements;
  final AdScriptScenario scenario;
  final Map<String, NativeAdStyle> factoryStyles;

  /// Đọc JSON; key quảng cáo sai sẽ được log và tắt riêng.
  ///
  /// Chỉ JSON sai cấu trúc ở cấp toàn bộ script mới báo [FormatException]
  /// để bên gọi giữ cấu hình hợp lệ trước đó.
  factory AdScript.parse(
    String source, {
    AdScriptScenario scenario = AdScriptScenario.full,
    String? pagesJson,
    bool useTestIds = false,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid ad script JSON: ${error.message}');
    }
    final root = _object(decoded, 'ad script');
    // Chấp nhận cả JSON trực tiếp và JSON được bọc trong trường `response`.
    final body = root.containsKey('response')
        ? _object(root['response'], 'response')
        : root;
    if (!body.containsKey('ad_placements')) {
      throw const FormatException(
        'Config v2 requires ad_placements; v1 is no longer supported',
      );
    }
    final parsedBody = _normalize(
      body,
      scenario,
      pagesJson: pagesJson,
      useTestIds: useTestIds,
    );
    final settings = _safeSettings(parsedBody['settings']);
    final placements = <String, AdScriptPlacement>{};
    for (final entry in parsedBody.entries) {
      if (entry.key == 'settings') continue;
      if (entry.value is! Map) {
        if (_isPlacementKey(entry.key)) {
          logAdScriptError(entry.key, 'Expected a placement object');
          placements[entry.key] = AdScriptPlacement._disabled(entry.key);
        }
        continue;
      }
      try {
        placements[entry.key] = AdScriptPlacement._parse(
          entry.key,
          _object(entry.value, entry.key),
        );
      } on FormatException catch (error) {
        logAdScriptError(entry.key, error.message);
        placements[entry.key] = AdScriptPlacement._disabled(entry.key);
      }
    }
    return AdScript._(
      settings: settings,
      placements: Map.unmodifiable(placements),
      scenario: scenario,
      factoryStyles: _factoryStyles(body),
    );
  }

  AdScriptPlacement? operator [](String key) => placements[key];

  /// Style ghi đè của các factory có sẵn, kể cả khi placement không khai báo
  /// `template` và coordinator chọn factory mặc định lúc chạy.
  static Map<String, NativeAdStyle> _factoryStyles(Map<String, Object?> body) {
    final templates = _object(
      body[AdConfigTemplateKeys.templates] ?? {},
      AdConfigTemplateKeys.templates,
    );
    final styles = <String, NativeAdStyle>{};
    for (final name in templates.keys) {
      if (AdConfigTemplate.fromKey(name) == null &&
          NativeAdType.fromFactoryId(name) == null) {
        continue;
      }
      try {
        final resolved = _resolveTemplate(name, templates);
        final style = NativeAdStyle.fromJson(resolved.overrides);
        if (style != null) styles[resolved.factoryId] = style;
      } on FormatException catch (error) {
        logAdScriptError(
          '${AdConfigTemplateKeys.templates}.$name',
          error.message,
        );
      }
    }
    return Map.unmodifiable(styles);
  }

  static Map<String, Object?> _normalize(
    Map<String, Object?> body,
    AdScriptScenario scenario, {
    String? pagesJson,
    bool useTestIds = false,
  }) {
    final settings = _object(body['ad_settings'] ?? {}, 'ad_settings');
    final all = _object(body['ad_placements'], 'ad_placements');
    final selected = scenario == AdScriptScenario.off
        ? <String, Object?>{}
        : _object(all[scenario.name] ?? {}, 'ad_placements.${scenario.name}');
    final ids = _object(body['ad_ids'] ?? {}, 'ad_ids');
    final templates = _object(
      body[AdConfigTemplateKeys.templates] ?? {},
      AdConfigTemplateKeys.templates,
    );
    final externalPages = _object(
      pagesJson == null ? (body['pages'] ?? {}) : jsonDecode(pagesJson),
      'pages',
    );
    final result = <String, Object?>{'settings': settings};
    for (final key in selected.keys) {
      try {
        final raw = _object(
          selected[key] ?? {},
          'ad_placements.${scenario.name}.$key',
        );
        final type =
            AdConfigType.fromPlacementKey(key) ??
            (throw FormatException('Unknown ad placement key: $key'));
        final defaultFormat = switch (type) {
          AdConfigType.splash || AdConfigType.inter => AdConfigFormat.inter,
          AdConfigType.banner => AdConfigFormat.banner,
          AdConfigType.resume => AdConfigFormat.aoa,
          AdConfigType.native ||
          AdConfigType.reward ||
          AdConfigType.rewardInter => null,
        };
        final format = raw['format'] == null
            ? defaultFormat
            : AdConfigFormat.parse(raw['format'].toString());
        if (format == null ? type.requiresFormat : !type.allows(format)) {
          throw FormatException(
            '$key.format ${format?.key ?? '(empty)'} is invalid for ${type.key}',
          );
        }
        // Placement có mặt trong bộ được chọn mặc định là bật.
        final enabled = _boolean(raw['enable'], '$key.enable') ?? true;
        final pages = _pages(externalPages[key] ?? raw['pages'], 'pages.$key');
        final templateName =
            raw[AdConfigTemplateKeys.placementTemplate]?.toString() ??
            _defaultTemplateName(key, type, format);
        final template = templateName == null
            ? null
            : _resolveTemplate(templateName, templates);
        final placement = <String, Object?>{
          'enable': 0,
          if (format != null) 'format': format.key,
          if (template != null)
            AdConfigTemplateKeys.resolvedTemplate: template.factoryId,
          if (template != null && template.overrides.isNotEmpty)
            NativeAdStyleKeys.normalizedStyle: template.overrides,
          if (raw['step'] != null) 'step_count': raw['step'],
          if (raw['wait_ms'] != null) 'wait_time': raw['wait_ms'],
          if (raw['refresh_ms'] != null) 'refresh_rate': raw['refresh_ms'],
          if (raw['open_ad_on_clicks'] != null)
            'open_ad_on_clicks': raw['open_ad_on_clicks'],
          if (pages.isNotEmpty) 'pages': pages,
        };
        if (enabled && scenario != AdScriptScenario.off) {
          final branches = _branches(key, type, format, pages);
          placement['enable'] = branches.$1;
          placement['selected_branches'] = branches.$2.keys.toList();
          for (final unit in branches.$2.entries) {
            placement[unit.key] = _unitFromIds(
              ids[unit.value],
              unit.value,
              useTestIds: useTestIds,
            );
          }
        }
        result[key] = placement;
        if (key == 'native_language' &&
            !selected.containsKey('native_language_2') &&
            ids.containsKey('native_language_2')) {
          result['native_language_2'] = {
            ...placement,
            if (enabled && scenario != AdScriptScenario.off)
              'native': _unitFromIds(
                ids['native_language_2'],
                'native_language_2',
                useTestIds: useTestIds,
              ),
          };
        }
      } on FormatException catch (error) {
        logAdScriptError(key, error.message);
        result[key] = {'enable': 0};
      }
    }
    if (scenario != AdScriptScenario.off &&
        settings['splash_fallback'] == 'inter_language') {
      final unitIds = ids['inter_language'];
      final list = unitIds is List
          ? unitIds
                .whereType<String>()
                .where((id) => id.trim().isNotEmpty)
                .toList()
          : <String>[];
      result['inter_language_fallback'] = {
        'enable': 1,
        'format': AdConfigFormat.inter.key,
        'selected_branches': ['inter'],
        'inter': useTestIds || list.isEmpty
            ? {'name1': 'inter_language'}
            : {for (var i = 0; i < list.length; i++) 'id${i + 1}': list[i]},
      };
    }
    return result;
  }

  static Map<String, Object?> _unitFromIds(
    Object? unitIds,
    String name, {
    required bool useTestIds,
  }) {
    final list = unitIds is List
        ? unitIds
              .whereType<String>()
              .where((id) => id.trim().isNotEmpty)
              .toList()
        : <String>[];
    return useTestIds || list.isEmpty
        ? <String, Object?>{'name1': name}
        : <String, Object?>{
            for (var i = 0; i < list.length; i++) 'id${i + 1}': list[i],
          };
  }

  static (int, Map<String, String>) _branches(
    String key,
    AdConfigType type,
    AdConfigFormat? format,
    List<int> pages,
  ) {
    if (type == AdConfigType.splash) {
      return switch (format) {
        AdConfigFormat.aoa => (1, {'app_open': 'aoa_splash'}),
        AdConfigFormat.inter => (2, {'inter': 'inter_splash'}),
        AdConfigFormat.interThenNativeFull => (
          3,
          {'inter': 'inter_splash', 'native_inter': 'native_inter_splash'},
        ),
        _ => throw FormatException('$key.format is invalid: $format'),
      };
    }
    if (type == AdConfigType.inter) {
      return switch (format) {
        AdConfigFormat.inter => (1, {'inter': key}),
        AdConfigFormat.nativeFull => (2, {'native_inter': 'native_$key'}),
        AdConfigFormat.interThenNativeFull => (
          3,
          {'inter': key, 'native_inter': 'native_$key'},
        ),
        _ => throw FormatException('$key.format is invalid: $format'),
      };
    }
    if (type == AdConfigType.banner) {
      final suffix = key.startsWith('banner_')
          ? key.substring('banner_'.length)
          : key;
      return switch (format) {
        AdConfigFormat.banner ||
        AdConfigFormat.bannerCollapsible => (1, {'banner': key}),
        AdConfigFormat.native => (3, {'native': 'native_$suffix'}),
        AdConfigFormat.nativeCollapsible => (
          4,
          {'native_collap': 'native_collap_$suffix'},
        ),
        _ => throw FormatException('$key.format is invalid: $format'),
      };
    }
    if (type == AdConfigType.resume) {
      return switch (format) {
        AdConfigFormat.aoa => (1, {'app_open': key}),
        // Coordinator dùng chính plan của inter_welcome_back cho mode này.
        AdConfigFormat.welcomeBack => (2, <String, String>{}),
        _ => throw FormatException('$key.format is invalid: $format'),
      };
    }
    if (type == AdConfigType.reward) {
      return (1, {'reward': key});
    }
    if (type == AdConfigType.rewardInter) {
      return (1, {'reward_inter': key});
    }
    if (key == 'native_onboarding') {
      final selected = pages.isEmpty ? [1, 2, 3, 4] : pages;
      return (
        int.parse(selected.join()),
        {
          for (final i in selected)
            'native_onboarding$i': 'native_onboarding_$i',
        },
      );
    }
    if (key == 'native_full_onboarding') {
      return (1, {'native': key});
    }
    return (1, {'native': key});
  }

  static String? _defaultTemplateName(
    String key,
    AdConfigType type,
    AdConfigFormat? format,
  ) {
    if (type == AdConfigType.native) {
      if (key == 'native_full_onboarding') {
        return NativeAdFactoryDefaults.fullScreen.factoryId;
      }
      if (key == 'native_language_small') {
        return NativeAdFactoryDefaults.languageSmall.factoryId;
      }
      return NativeAdFactoryDefaults.native.factoryId;
    }
    if (type == AdConfigType.inter &&
            (format == AdConfigFormat.nativeFull ||
                format == AdConfigFormat.interThenNativeFull) ||
        type == AdConfigType.splash &&
            format == AdConfigFormat.interThenNativeFull) {
      return NativeAdFactoryDefaults.fullScreen.factoryId;
    }
    return null;
  }

  static ({String factoryId, Map<String, Object?> overrides}) _resolveTemplate(
    String template,
    Map<String, Object?> customTemplates, [
    Set<String>? visited,
  ]) {
    final builtIn = AdConfigTemplate.fromKey(template);
    final defaultFactory =
        builtIn?.factoryId ?? NativeAdType.fromFactoryId(template)?.factoryId;
    if (!customTemplates.containsKey(template)) {
      if (defaultFactory != null) {
        return (factoryId: defaultFactory, overrides: {});
      }
      throw FormatException('Unknown native template: $template');
    }
    final names = visited ?? <String>{};
    if (!names.add(template)) {
      throw FormatException('Cyclic native template base: $template');
    }
    final fields = _object(
      customTemplates[template],
      '${AdConfigTemplateKeys.templates}.$template',
    );
    final base = fields[AdConfigTemplateKeys.base]?.toString().trim();
    if ((base == null || base.isEmpty) && defaultFactory == null) {
      throw FormatException(
        '${AdConfigTemplateKeys.templates}.$template.${AdConfigTemplateKeys.base} is required',
      );
    }
    // Mẫu có sẵn được phép cấu hình ngay dưới tên của nó, không cần base.
    // Nếu base trùng chính tên đó, lấy factory gốc thay vì đệ quy vô hạn.
    final ({String factoryId, Map<String, Object?> overrides}) parent;
    if (base == null || base.isEmpty) {
      parent = (factoryId: defaultFactory!, overrides: {});
    } else if (base == template) {
      if (defaultFactory == null) {
        throw FormatException('Cyclic native template base: $template');
      }
      parent = (factoryId: defaultFactory, overrides: {});
    } else {
      parent = _resolveTemplate(base, customTemplates, names);
    }
    final validOverrides = NativeAdStyle.fromJson({
      for (final entry in fields.entries)
        if (entry.key != AdConfigTemplateKeys.base) entry.key: entry.value,
    });
    return (
      factoryId: defaultFactory ?? parent.factoryId,
      overrides: {...parent.overrides, ...?validOverrides?.values},
    );
  }

  static int? _integer(Object? value, String path) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    throw FormatException('$path must be an integer');
  }

  static bool? _boolean(Object? value, String path) {
    if (value == null) return null;
    if (value is bool) return value;
    throw FormatException('$path must be true or false');
  }

  static List<int> _pages(Object? value, String path) {
    if (value == null) return [];
    final list = value is List ? value : [value];
    final pages = <int>[];
    for (final item in list) {
      final page = _integer(item, path);
      if (page == null || page < 1 || page > 4 || pages.contains(page)) {
        throw FormatException('$path must contain distinct pages 1..4');
      }
      pages.add(page);
    }
    return pages..sort();
  }
}

/// Giữ script gần nhất khi toàn bộ JSON mới không thể phân tích.
///
/// Sau khi cập nhật thành công, bên gọi cần tạo coordinator mới từ [current].
/// Nếu danh sách ad unit ID đã đổi, app cần khởi tạo lại CoreAds tại thời điểm
/// an toàn vì quảng cáo đang hiển thị có thể bị giải phóng.
final class AdScriptStore {
  AdScriptStore(this.current, {this.useTestIds = false});

  AdScript current;
  final bool useTestIds;
  FormatException? lastError;

  bool tryUpdate(
    String source, {
    AdScriptScenario? scenario,
    String? pagesJson,
  }) {
    try {
      final next = AdScript.parse(
        source,
        scenario: scenario ?? current.scenario,
        pagesJson: pagesJson,
        useTestIds: useTestIds,
      );
      current = next;
      lastError = null;
      return true;
    } on FormatException catch (error) {
      logAdScriptError('script', error.message, action: 'previous script kept');
      lastError = error;
      return false;
    }
  }
}

/// Các setting dùng chung của script; key chưa hỗ trợ vẫn được giữ trong [values].
final class AdScriptSettings {
  AdScriptSettings._(this.values);

  final Map<String, Object?> values;

  /// Placement bù khi Splash không hiện được ad, ví dụ `inter_language`.
  String? get splashFallback => values['splash_fallback']?.toString();

  String get languageNextStyle =>
      values['language_next_style']?.toString() ?? 'text';
  Duration get languageNextDelay => Duration(
    milliseconds:
        _optionalInt(
          values['language_next_delay_ms'],
          'settings.language_next_delay_ms',
        ) ??
        0,
  );
  bool get languageShowLoading => values['language_show_loading'] == true;

  bool get onboardingSwipe => values['onboarding_swipe'] != false;
  String get onboardingNextStyle =>
      values['onboarding_next_style']?.toString() ?? 'icon';
  String get onboardingNextPosition =>
      values['onboarding_next_position']?.toString() ?? 'bottom';
  Duration get onboardingNextDelay => Duration(
    milliseconds:
        _optionalInt(
          values['onboarding_next_delay_ms'],
          'settings.onboarding_next_delay_ms',
        ) ??
        0,
  );
  bool get onboardingShowDots => values['onboarding_show_dots'] != false;
  OnboardingFullCloseButtonStyle get onboardingFullCloseButton =>
      OnboardingFullCloseButtonStyle.fromJson(
        values['onboarding_full_close_button'],
      );

  /// Cooldown theo bộ quảng cáo v2, tính bằng mili giây.
  AdInterstitialGapSettings gapFor(AdScriptScenario scenario) {
    final key = scenario == AdScriptScenario.basic
        ? 'basic_inter_gap_ms'
        : 'full_inter_gap_ms';
    final ms =
        _optionalInt(values[key], 'settings.$key') ??
        (scenario == AdScriptScenario.basic ? 90000 : 0);
    if (ms < 0) throw FormatException('settings.$key must be non-negative');
    final ignored = scenario == AdScriptScenario.full
        ? _stringSet(values['full_inter_gap_ignore'])
        : const <String>{};
    return AdInterstitialGapSettings(
      interval: Duration(milliseconds: ms),
      ignoredScenarioKeys: ignored,
    );
  }

  /// Khoảng cách giữa hai lần hiện app-open của bộ quảng cáo đang chọn.
  Duration? appOpenGapFor(AdScriptScenario scenario) => _optionalGapFor(
    scenario == AdScriptScenario.basic
        ? 'basic_open_gap_ms'
        : 'full_open_gap_ms',
  );

  /// Khoảng cách giữa interstitial và app-open theo cả hai chiều.
  Duration? interstitialAppOpenGapFor(AdScriptScenario scenario) =>
      _optionalGapFor(
        scenario == AdScriptScenario.basic
            ? 'basic_open_inter_gap_ms'
            : 'full_open_inter_gap_ms',
      );

  Duration? _optionalGapFor(String key) {
    final ms = _optionalInt(values[key], 'settings.$key');
    if (ms == null) return null;
    if (ms < 0) throw FormatException('settings.$key must be non-negative');
    return Duration(milliseconds: ms);
  }

  Object? operator [](String key) => values[key];
}

/// Bỏ qua từng setting sai để các quảng cáo hợp lệ vẫn được áp dụng.
AdScriptSettings _safeSettings(Object? raw) {
  final values = <String, Object?>{};
  if (raw != null) {
    try {
      values.addAll(_object(raw, 'settings'));
    } on FormatException catch (error) {
      logAdScriptError('settings', error.message, action: 'settings ignored');
    }
  }
  for (final key in [
    'full_inter_gap_ms',
    'basic_inter_gap_ms',
    'full_open_gap_ms',
    'basic_open_gap_ms',
    'full_open_inter_gap_ms',
    'basic_open_inter_gap_ms',
  ]) {
    if (!values.containsKey(key)) continue;
    try {
      final candidate = AdScriptSettings._(values);
      switch (key) {
        case 'full_inter_gap_ms' || 'basic_inter_gap_ms':
          candidate.gapFor(
            key == 'full_inter_gap_ms'
                ? AdScriptScenario.full
                : AdScriptScenario.basic,
          );
        case 'full_open_gap_ms' || 'basic_open_gap_ms':
          candidate.appOpenGapFor(
            key == 'full_open_gap_ms'
                ? AdScriptScenario.full
                : AdScriptScenario.basic,
          );
        case 'full_open_inter_gap_ms' || 'basic_open_inter_gap_ms':
          candidate.interstitialAppOpenGapFor(
            key == 'full_open_inter_gap_ms'
                ? AdScriptScenario.full
                : AdScriptScenario.basic,
          );
      }
    } on FormatException catch (error) {
      logAdScriptError(
        'settings.$key',
        error.message,
        action: 'setting ignored',
      );
      values.remove(key);
    }
  }
  return AdScriptSettings._(Map.unmodifiable(values));
}

bool _isPlacementKey(String key) => AdConfigType.fromPlacementKey(key) != null;

/// Cấu hình `inter_delay_time` đã phân tích để dùng cooldown có sẵn của package.
final class AdInterstitialGapSettings {
  const AdInterstitialGapSettings({
    required this.interval,
    required this.ignoredScenarioKeys,
  });

  final Duration interval;

  /// Key kịch bản logic được miễn gap, ví dụ `inter_language`, `ads_splash`.
  final Set<String> ignoredScenarioKeys;
}

/// Cấu hình của một key logic, gồm chế độ bật và các nhánh ad đã chọn.
///
/// Ví dụ `inter_home.enable=3` chọn nhánh `inter` và `native_inter`. Dữ liệu
/// ở đây chưa phải `AdPlacement` dùng trực tiếp để tải/hiển thị quảng cáo.
final class AdScriptPlacement {
  AdScriptPlacement._({
    required this.key,
    required this.enable,
    required this.units,
    required this.pages,
    required this.selectedBranches,
    required this.collapseClickCounts,
    this.configType,
    this.configFormat,
    this.nativeTemplate,
    this.nativeStyle,
    this.stepCount,
    this.refreshRate,
    this.waitTime,
  });

  factory AdScriptPlacement._disabled(String key) => AdScriptPlacement._(
    key: key,
    enable: 0,
    units: const {},
    pages: const {},
    selectedBranches: const [],
    collapseClickCounts: const {},
  );

  final String key;
  final int enable;
  final AdConfigType? configType;
  final AdConfigFormat? configFormat;
  final String? nativeTemplate;
  final NativeAdStyle? nativeStyle;
  final int? stepCount;

  /// Chu kỳ làm mới native, đổi từ `refresh_rate` tính bằng mili giây.
  final Duration? refreshRate;

  /// Thời gian chờ của native toàn màn hình, đổi từ `wait_time` mili giây.
  final Duration? waitTime;

  /// Danh sách nhánh đã được chọn và kiểm tra theo `enable` đúng một lần.
  final List<String> selectedBranches;

  /// Nhánh đã chọn của placement native.
  List<String> get selectedNativeBranches =>
      configType == AdConfigType.native ? selectedBranches : const <String>[];

  /// Số thứ tự các lần bấm collapse cần bỏ qua; widget giữ bộ đếm thực tế.
  final Set<int> collapseClickCounts;
  final Map<String, AdScriptUnit> units;

  /// Trang onboarding được chọn trong config v2, tách khỏi enable.
  final Set<int> pages;

  AdScriptUnit? unit(String branch) => units[branch];

  /// Đổi một placement trong JSON thành dữ liệu có kiểu để coordinator dùng.
  static AdScriptPlacement _parse(String key, Map<String, Object?> values) {
    final enable = _optionalInt(values['enable'], '$key.enable') ?? 0;
    final configType = AdConfigType.fromPlacementKey(key);
    final configFormat = values['format'] == null
        ? null
        : AdConfigFormat.parse(values['format'].toString());

    final units = <String, AdScriptUnit>{};
    for (final entry in values.entries) {
      if (entry.value is! Map) continue;
      final fields = _object(entry.value, '$key.${entry.key}');
      units[entry.key] = AdScriptUnit._parse(fields);
    }
    final selected = values['selected_branches'];
    if (enable > 0 && selected is! List) {
      throw FormatException('$key.selected_branches is required');
    }
    final selectedBranches = selected is List
        ? List<String>.unmodifiable(selected.map((branch) => branch.toString()))
        : const <String>[];

    if (key == AdScenarioKeys.nativeFullOnboarding && enable > 0) {
      final template = values[AdConfigTemplateKeys.resolvedTemplate]
          ?.toString();
      if (template != null &&
          !NativeAdType.values.any(
            (type) =>
                type.factoryId == template && type.factoryId.startsWith('Full'),
          )) {
        logAdScriptError(key, '$key.native_template must be a Full factory');
        return AdScriptPlacement._disabled(key);
      }
    }

    if (enable > 0) {
      for (final branch in selectedBranches) {
        final unit = units[branch];
        if (unit == null || (unit.names.isEmpty && unit.ids.isEmpty)) {
          logAdScriptError(key, '$key.$branch is required for enable=$enable');
          return AdScriptPlacement._disabled(key);
        }
      }
    }

    final stepCount = _optionalInt(values['step_count'], '$key.step_count');
    if (stepCount != null && stepCount <= 0) {
      throw FormatException('$key.step_count must be positive');
    }
    final refreshMilliseconds = _optionalInt(
      values['refresh_rate'],
      '$key.refresh_rate',
    );
    final waitMilliseconds = _optionalInt(
      values['wait_time'],
      '$key.wait_time',
    );
    if (refreshMilliseconds != null && refreshMilliseconds < 0) {
      throw FormatException('$key.refresh_rate must be non-negative');
    }
    if (waitMilliseconds != null && waitMilliseconds < 0) {
      throw FormatException('$key.wait_time must be non-negative');
    }

    return AdScriptPlacement._(
      key: key,
      enable: enable,
      configType: configType,
      configFormat: configFormat,
      nativeTemplate: values[AdConfigTemplateKeys.resolvedTemplate]?.toString(),
      nativeStyle: values[NativeAdStyleKeys.normalizedStyle] is Map
          ? NativeAdStyle.fromJson(
              _object(
                values[NativeAdStyleKeys.normalizedStyle],
                '$key.${NativeAdStyleKeys.normalizedStyle}',
              ),
            )
          : null,
      stepCount: stepCount,
      refreshRate: refreshMilliseconds == null
          ? null
          : Duration(milliseconds: refreshMilliseconds),
      waitTime: waitMilliseconds == null
          ? null
          : Duration(milliseconds: waitMilliseconds),
      selectedBranches: List.unmodifiable(selectedBranches),
      collapseClickCounts:
          (configType == AdConfigType.banner &&
                  (configFormat == AdConfigFormat.native ||
                      configFormat == AdConfigFormat.nativeCollapsible)) ||
              (configType == AdConfigType.native &&
                  NativeAdTemplate.forFactory(
                    values[AdConfigTemplateKeys.resolvedTemplate]?.toString(),
                  ).isCollapsible)
          ? _collapseTapCounts(
              values['open_ad_on_clicks'],
              '$key.open_ad_on_clicks',
            )
          : const <int>{},
      units: Map.unmodifiable(units),
      pages: _pageSet(values['pages'], '$key.pages'),
    );
  }
}

Set<String> _stringSet(Object? value) {
  if (value == null) return const <String>{};
  final parts = value is List ? value : value.toString().split(',');
  return Set.unmodifiable(
    parts
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty),
  );
}

Set<int> _pageSet(Object? value, String path) {
  if (value == null) return const <int>{};
  if (value is! List) throw FormatException('$path must be a list');
  final pages = <int>{};
  for (final item in value) {
    final page = _positiveInt(item, path);
    if (page > 4 || !pages.add(page)) {
      throw FormatException('$path must contain distinct pages 1..4');
    }
  }
  return Set.unmodifiable(pages);
}

/// Tên quảng cáo hoặc ad unit ID của một nhánh trong JSON.
final class AdScriptUnit {
  AdScriptUnit._({required this.names, required this.ids});

  /// Tên ký hiệu như `INTER_HOME`, sắp theo thứ tự `name1`, `name2`...
  final List<String> names;

  /// Ad unit ID trực tiếp từ `id1`, `id2`... nếu JSON cung cấp.
  final List<String> ids;

  static AdScriptUnit _parse(Map<String, Object?> fields) {
    List<String> numbered(String prefix) {
      final entries = fields.entries.where(
        (entry) => RegExp('^$prefix[0-9]+\$').hasMatch(entry.key),
      );
      final ordered = entries.toList()
        ..sort(
          (a, b) => int.parse(
            a.key.substring(prefix.length),
          ).compareTo(int.parse(b.key.substring(prefix.length))),
        );
      return List.unmodifiable(
        ordered
            .map((entry) => entry.value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty),
      );
    }

    return AdScriptUnit._(names: numbered('name'), ids: numbered('id'));
  }
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map) throw FormatException('$path must be a JSON object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$path contains a non-string key');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

int _requiredInt(Object? value, String path) =>
    _optionalInt(value, path) ?? (throw FormatException('$path is required'));

int _positiveInt(Object? value, String path) {
  final parsed = _requiredInt(value, path);
  if (parsed <= 0) throw FormatException('$path must be positive');
  return parsed;
}

Set<int> _collapseTapCounts(Object? value, String path) {
  if (value == null) return const <int>{};
  final parts = value is String
      ? value.split(RegExp(r'[/,]'))
      : value is List
      ? value
      : <Object?>[value];
  final counts = <int>{};
  for (final part in parts) {
    final count = _positiveInt(part, path);
    if (!counts.add(count)) {
      throw FormatException('$path contains a repeated count');
    }
  }
  return Set.unmodifiable(counts);
}

int? _optionalInt(Object? value, String path) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('$path must be an integer');
}
