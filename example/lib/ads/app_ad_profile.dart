import 'dart:convert';

import 'package:core_ads/core_ads.dart';

/// Quyết định bộ quảng cáo ở tầng app từ Remote Config và thông tin user.
AdScriptScenario selectAppAdScenario(
  String source, {
  required bool isMarketingUser,
  required bool isTestAdDevice,
  required bool isPremium,
}) {
  if (isPremium) return AdScriptScenario.off;

  final root = jsonDecode(source);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('Ad config must be a JSON object');
  }
  final body = root['response'] ?? root;
  if (body is! Map<String, dynamic>) {
    throw const FormatException('Ad config response must be a JSON object');
  }
  final settings = body['ad_settings'];
  if (settings != null && settings is! Map<String, dynamic>) {
    throw const FormatException('ad_settings must be a JSON object');
  }
  final profile = (settings as Map<String, dynamic>?)?['ads_profile'] ?? 1;
  if (profile is! num ||
      !profile.isFinite ||
      profile != profile.roundToDouble()) {
    throw const FormatException('ads_profile must be an integer from 0 to 3');
  }
  return switch (profile.toInt()) {
    0 => AdScriptScenario.off,
    1 => AdScriptScenario.full,
    2 => isMarketingUser ? AdScriptScenario.full : AdScriptScenario.basic,
    3 => isTestAdDevice ? AdScriptScenario.basic : AdScriptScenario.full,
    _ => throw const FormatException('ads_profile must be 0..3'),
  };
}
