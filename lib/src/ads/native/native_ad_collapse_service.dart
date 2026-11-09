import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Đồng bộ layout thu gọn với native view đang giữ cùng một ad.
abstract final class NativeAdCollapseService {
  static const _channel = MethodChannel('core_ads/collapsible_native');

  static void setCollapsed({
    required String placementKey,
    required bool collapsed,
    required String? collapsedFactoryId,
  }) {
    unawaited(
      _invoke('setCollapsed', {
        'placementKey': placementKey,
        'collapsed': collapsed,
        'collapsedFactoryId': collapsedFactoryId,
      }),
    );
  }

  static void clear(String placementKey) {
    unawaited(_invoke('clear', {'placementKey': placementKey}));
  }

  static Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Cho phép dùng widget trong test hoặc app chưa đăng ký native plugin.
    } on PlatformException catch (error) {
      debugPrint('core_ads collapsible native: ${error.message}');
    }
  }
}
