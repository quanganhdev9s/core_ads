import 'dart:convert';

import '../ads/native/native_ad_template.dart';
import '../ads/native/native_ad_type.dart';
import 'ad_scenario_keys.dart';
import 'ad_script_diagnostics.dart';

/// Bản chụp cấu hình quảng cáo sau khi đọc JSON từ Remote Config.
///
/// App tự fetch và activate Remote Config. Package chỉ nhận chuỗi JSON nên
/// không phụ thuộc dự án Firebase hoặc lịch cập nhật của từng app.
final class AdScript {
  AdScript._({required this.settings, required this.placements});

  final AdScriptSettings settings;
  final Map<String, AdScriptPlacement> placements;

  /// Đọc JSON; key quảng cáo sai sẽ được log và tắt riêng.
  ///
  /// Chỉ JSON sai cấu trúc ở cấp toàn bộ script mới báo [FormatException]
  /// để bên gọi giữ cấu hình hợp lệ trước đó.
  factory AdScript.parse(String source) {
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
    final settings = _safeSettings(body['settings']);
    final placements = <String, AdScriptPlacement>{};
    for (final entry in body.entries) {
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
    );
  }

  AdScriptPlacement? operator [](String key) => placements[key];
}

/// Giữ script gần nhất khi toàn bộ JSON mới không thể phân tích.
///
/// Sau khi cập nhật thành công, bên gọi cần tạo coordinator mới từ [current].
/// Nếu danh sách ad unit ID đã đổi, app cần khởi tạo lại CoreAds tại thời điểm
/// an toàn vì quảng cáo đang hiển thị có thể bị giải phóng.
final class AdScriptStore {
  AdScriptStore(this.current);

  AdScript current;
  FormatException? lastError;

  bool tryUpdate(String source) {
    try {
      final next = AdScript.parse(source);
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

  /// Chọn kịch bản do từng app định nghĩa; không phải công tắc chung của ads.
  int? get adsEnable =>
      _optionalInt(values['ads_enable'], 'settings.ads_enable');

  /// Chọn luồng resume khi JSON không có placement `on_resume` riêng.
  int? get onResume {
    final value = _optionalInt(values['on_resume'], 'settings.on_resume');
    if (value != null && (value < 0 || value > 2)) {
      throw FormatException('settings.on_resume must be 0..2');
    }
    return value;
  }

  /// Khoảng cách chung giữa các inter; `time` tính bằng mili giây.
  AdInterstitialGapSettings? get interDelayTime {
    final raw = values['inter_delay_time'];
    if (raw == null) return null;
    if (raw is! String) {
      throw FormatException('settings.inter_delay_time must be a string');
    }

    final fields = <String, String>{};
    for (final part in raw.split(',')) {
      final match = RegExp(
        r'^\s*(time|ignore)\s*=\s*(.*?)\s*$',
      ).firstMatch(part);
      if (match == null || fields.containsKey(match.group(1))) {
        throw FormatException('Invalid settings.inter_delay_time: $raw');
      }
      fields[match.group(1)!] = match.group(2)!;
    }
    final milliseconds = int.tryParse(fields['time'] ?? '');
    if (milliseconds == null || milliseconds < 0) {
      throw FormatException(
        'settings.inter_delay_time.time must be non-negative',
      );
    }

    final ignored = <String>{};
    final ignoredValue = fields['ignore'];
    if (ignoredValue != null && ignoredValue.isNotEmpty) {
      for (final item in ignoredValue.split('|')) {
        final key = item.trim();
        if (key.isEmpty || !ignored.add(key)) {
          throw FormatException(
            'Invalid settings.inter_delay_time.ignore: $raw',
          );
        }
      }
    }
    return AdInterstitialGapSettings(
      interval: Duration(milliseconds: milliseconds),
      ignoredScenarioKeys: Set.unmodifiable(ignored),
    );
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
  for (final key in ['ads_enable', 'on_resume', 'inter_delay_time']) {
    if (!values.containsKey(key)) continue;
    try {
      final candidate = AdScriptSettings._(values);
      switch (key) {
        case 'ads_enable':
          candidate.adsEnable;
        case 'on_resume':
          candidate.onResume;
        case 'inter_delay_time':
          candidate.interDelayTime;
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

bool _isPlacementKey(String key) =>
    key == 'ads_splash' ||
    key == 'on_resume' ||
    key.startsWith('inter_') ||
    key.startsWith('banner_') ||
    key.startsWith('native_') ||
    key.startsWith('reward_');

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
    required this.values,
    required this.introScreens,
    required this.selectedBranches,
    required this.collapseClickCounts,
    this.nativeTemplate,
    this.stepCount,
    this.refreshRate,
    this.waitTime,
  });

  factory AdScriptPlacement._disabled(String key) => AdScriptPlacement._(
    key: key,
    enable: 0,
    units: const {},
    values: const {},
    introScreens: const {},
    selectedBranches: const [],
    collapseClickCounts: const {},
  );

  final String key;
  final int enable;
  final String? nativeTemplate;
  final int? stepCount;

  /// Chu kỳ làm mới native, đổi từ `refresh_rate` tính bằng mili giây.
  final Duration? refreshRate;

  /// Thời gian chờ của native toàn màn hình, đổi từ `wait_time` mili giây.
  final Duration? waitTime;

  /// Các màn intro được chọn; `enable=24` tương ứng màn 2 và 4.
  final Set<int> introScreens;

  /// Danh sách nhánh đã được chọn và kiểm tra theo `enable` đúng một lần.
  final List<String> selectedBranches;

  /// Nhánh đã chọn của placement thuộc nhóm `native_*`.
  List<String> get selectedNativeBranches =>
      key.startsWith('native_') ? selectedBranches : const <String>[];

  /// Số thứ tự các lần bấm collapse cần bỏ qua; widget giữ bộ đếm thực tế.
  final Set<int> collapseClickCounts;
  final Map<String, AdScriptUnit> units;
  final Map<String, Object?> values;

  AdScriptUnit? unit(String branch) => units[branch];

  /// Đổi một placement trong JSON thành dữ liệu có kiểu để coordinator dùng.
  static AdScriptPlacement _parse(String key, Map<String, Object?> values) {
    final enable = _optionalInt(values['enable'], '$key.enable') ?? 0;

    final units = <String, AdScriptUnit>{};
    for (final entry in values.entries) {
      if (entry.value is! Map) continue;
      final fields = _object(entry.value, '$key.${entry.key}');
      units[entry.key] = AdScriptUnit._parse(fields);
    }
    final selection = _selectBranches(key, enable, units);
    if (selection.error case final error?) {
      logAdScriptError(key, error);
      return AdScriptPlacement._disabled(key);
    }
    final selectedBranches = selection.branches;

    if (key == AdScenarioKeys.nativeFullOnboarding && enable > 0) {
      final template = values['native_template']?.toString();
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
      nativeTemplate: values['native_template']?.toString(),
      stepCount: stepCount,
      refreshRate: refreshMilliseconds == null
          ? null
          : Duration(milliseconds: refreshMilliseconds),
      waitTime: waitMilliseconds == null
          ? null
          : Duration(milliseconds: waitMilliseconds),
      introScreens: key == 'native_intro'
          ? Set.unmodifiable(
              selectedBranches.map(
                (branch) => int.parse(branch.substring(key.length)),
              ),
            )
          : const <int>{},
      selectedBranches: List.unmodifiable(selectedBranches),
      collapseClickCounts:
          (key.startsWith('banner_') && (enable == 2 || enable == 4)) ||
              (key.startsWith('native_') &&
                  NativeAdTemplate.forFactory(
                    values['native_template']?.toString(),
                  ).isCollapsible)
          ? _collapseTapCounts(values['collap_config'], '$key.collap_config')
          : const <int>{},
      units: Map.unmodifiable(units),
      values: Map.unmodifiable(values),
    );
  }
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

/// Kết quả chọn nhánh: danh sách hợp lệ hoặc lỗi dữ liệu, không ném exception.
final class _BranchSelection {
  const _BranchSelection.valid(this.branches) : error = null;
  const _BranchSelection.invalid(this.error) : branches = const [];

  final List<String> branches;
  final String? error;
}

/// Một nơi duy nhất diễn giải `enable` thành danh sách nhánh cho mọi nhóm ad.
_BranchSelection _selectBranches(
  String key,
  int enable,
  Map<String, AdScriptUnit> units,
) {
  if (enable < 0) {
    return _BranchSelection.invalid('$key.enable must be non-negative');
  }

  if (key == 'ads_splash') {
    return switch (enable) {
      0 => const _BranchSelection.valid([]),
      1 => const _BranchSelection.valid(['app_open']),
      2 => const _BranchSelection.valid(['inter']),
      3 => const _BranchSelection.valid(['inter', 'native_inter']),
      _ => _BranchSelection.invalid('$key.enable must be 0..3'),
    };
  }
  if (key.startsWith('inter_')) {
    return switch (enable) {
      0 => const _BranchSelection.valid([]),
      1 => const _BranchSelection.valid(['inter']),
      2 => const _BranchSelection.valid(['native_inter']),
      3 => const _BranchSelection.valid(['inter', 'native_inter']),
      _ => _BranchSelection.invalid('$key.enable must be 0..3'),
    };
  }
  if (key.startsWith('banner_')) {
    return switch (enable) {
      0 => const _BranchSelection.valid([]),
      1 => const _BranchSelection.valid(['banner']),
      2 => const _BranchSelection.valid(['native', 'banner_collap']),
      3 => const _BranchSelection.valid(['native']),
      4 => _BranchSelection.valid([
        units.containsKey('native_collap') ? 'native_collap' : 'native',
      ]),
      _ => _BranchSelection.invalid('$key.enable must be 0..4'),
    };
  }
  if (key == 'on_resume') {
    if (enable > 2) {
      return _BranchSelection.invalid('$key.enable must be 0..2');
    }
    return const _BranchSelection.valid([]);
  }
  if (key == 'native_language' || key == 'native_get_start') {
    return switch (enable) {
      0 => const _BranchSelection.valid([]),
      1 => _BranchSelection.valid(['${key}1']),
      2 => _BranchSelection.valid(['${key}2']),
      _ => _BranchSelection.invalid('$key.enable must be 0, 1 or 2'),
    };
  }
  if (key == AdScenarioKeys.nativeFullOnboarding) {
    return enable == 0
        ? const _BranchSelection.valid([])
        : const _BranchSelection.valid(['native']);
  }
  if (key == 'native_intro' && enable > 0) {
    final screens = enable.toString().split('');
    if (screens.any((screen) => !'1234'.contains(screen)) ||
        screens.toSet().length != screens.length) {
      return _BranchSelection.invalid(
        '$key.enable must contain distinct screen numbers from 1..4',
      );
    }
  }
  if (key.startsWith('native_')) {
    return _selectNativeBranches(key, enable, units);
  }
  if (enable == 0) return const _BranchSelection.valid([]);
  if (enable == 1 && units.length == 1) {
    return _BranchSelection.valid([units.keys.single]);
  }
  return _BranchSelection.invalid(
    '$key requires enable=1 and one ad branch; no scenario rule is defined',
  );
}

/// Một native dùng `0/1`; nhiều native đánh số dùng từng chữ số của `enable`.
/// `native_language` và `native_get_start` được xử lý riêng ở trên: chỉ `0/1/2`.
_BranchSelection _selectNativeBranches(
  String key,
  int enable,
  Map<String, AdScriptUnit> units,
) {
  if (!key.startsWith('native_')) {
    return const _BranchSelection.valid([]);
  }
  if (enable == 0) return const _BranchSelection.valid([]);

  final branches = units.keys
      .where((branch) => branch.startsWith('native'))
      .toList();
  if (branches.isEmpty) {
    return _BranchSelection.invalid(
      '$key requires native branches for enable=$enable',
    );
  }
  final numberedBranch = RegExp('^${RegExp.escape(key)}([1-9])\$');
  if (branches.length == 1 && !numberedBranch.hasMatch(branches.single)) {
    if (enable > 1) {
      return _BranchSelection.invalid(
        '$key.enable must be 0 or 1 for a single native',
      );
    }
    return _BranchSelection.valid(enable == 1 ? branches : const []);
  }

  if (branches.any((branch) => !numberedBranch.hasMatch(branch))) {
    return _BranchSelection.invalid('$key must use numbered native branches');
  }
  final selected = <int>{};
  for (final character in enable.toString().split('')) {
    final digit = int.tryParse(character);
    if (digit == null || digit < 1 || digit > 9 || !selected.add(digit)) {
      return _BranchSelection.invalid(
        '$key.enable contains an invalid or repeated digit',
      );
    }
  }
  for (final number in selected) {
    if (!units.containsKey('$key$number')) {
      return _BranchSelection.invalid(
        '$key$number is required for enable=$enable',
      );
    }
  }
  final chosen =
      branches
          .where(
            (branch) =>
                selected.contains(int.tryParse(branch.substring(key.length))),
          )
          .toList()
        ..sort();
  return _BranchSelection.valid(chosen);
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
  final parts = value is String ? value.split('/') : <Object?>[value];
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
