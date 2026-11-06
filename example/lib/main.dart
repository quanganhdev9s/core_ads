import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/core_ads_example_app.dart';

void main() {
  DevicePreview.enable(enabled: kDebugMode);
  runApp(const CoreAdsExampleApp());
}
