import 'package:flutter/foundation.dart';

/// Luôn in lỗi Remote Config nổi bật, kể cả khi tắt debug log của SDK.
void logAdScriptError(
  String key,
  String reason, {
  String action = 'ad skipped',
}) {
  debugPrint(
    '🚨🚨🚨 [CORE_ADS][REMOTE_CONFIG_ERROR] $key: $reason '
    '— $action 🚨🚨🚨',
  );
}
