import 'package:core_ads/core_ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validV2 = '''
{
  "ad_settings": {"ads_profile": 1},
  "ad_placements": {"full": {
    "native_result": { "enable": true, "template": "Big2"}
  }}
}
''';

  test('v1 config is rejected instead of silently selecting old rules', () {
    expect(
      () => AdScript.parse('{"settings":{},"native_result":{"enable":1}}'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdScript.parse(
        '{"response":{"settings":{},"native_result":{"enable":1}}}',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('v2 parses the selected placement', () {
    final script = AdScript.parse(validV2);
    expect(script.scenario, AdScriptScenario.full);
    expect(script['native_result']?.enable, 1);
    expect(script['native_result']?.nativeTemplate, 'Big2');
  });

  test('a failed update keeps the last valid v2 script', () {
    final current = AdScript.parse(validV2);
    final store = AdScriptStore(current);
    expect(store.tryUpdate('{"settings":{}}'), isFalse);
    expect(store.current, same(current));
    expect(store.lastError, isA<FormatException>());
  });
}
