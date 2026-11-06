import 'package:core_ads/core_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native types resolve to the height used by templates', () {
    for (final type in NativeAdType.values) {
      expect(NativeAdType.fromFactoryId(type.factoryId), type);
      expect(
        NativeAdTemplate.forFactory(type.factoryId).factoryId,
        type.factoryId,
      );
      expect(
        NativeAdTemplate.forFactory(type.factoryId).referenceHeight,
        type.height,
        reason: type.factoryId,
      );
      expect(
        NativeAdTemplate.forFactory(type.factoryId).heightForScreen(1000),
        type.resolveHeight(1000),
        reason: type.factoryId,
      );
    }
    expect(NativeAdType.fromFactoryId('Unknown'), isNull);
    expect(NativeAdTemplate.forFactory('Unknown').referenceHeight, 136);
    expect(NativeAdTemplate.forFactory('Unknown').factoryId, 'Unknown');
    expect(
      NativeAdTemplate.forFactory(null).factoryId,
      NativeAdType.small1.factoryId,
    );
  });

  test('big and expanded collapse heights use the screen height', () {
    for (final type in [
      NativeAdType.big1,
      NativeAdType.big2,
      NativeAdType.big3,
      NativeAdType.big4,
      NativeAdType.big5,
      NativeAdType.big6,
      NativeAdType.collap1Expanded,
    ]) {
      expect(type.resolveHeight(1000), 360, reason: type.factoryId);
    }
    for (final type in [
      NativeAdType.big7,
      NativeAdType.big8,
      NativeAdType.collap3Expanded,
    ]) {
      expect(type.resolveHeight(1000), 330, reason: type.factoryId);
    }
    expect(NativeAdType.big9.resolveHeight(1000), 300);
    expect(NativeAdType.collap2Expanded.resolveHeight(1000), 400);
    expect(
      NativeAdType.collap1Collapsed.resolveHeight(1000),
      NativeAdType.tiny1.resolveHeight(1000),
    );
    expect(
      NativeAdType.collap3Collapsed.resolveHeight(1000),
      NativeAdType.tiny1.resolveHeight(1000),
    );
    expect(
      NativeAdType.collap2Collapsed.resolveHeight(1000),
      NativeAdType.tiny2.resolveHeight(1000),
    );
    expect(NativeAdType.full1.resolveHeight(1000), isNull);
  });

  test('iOS native heights use their platform-specific fractions', () {
    final expectedHeights = <NativeAdType, double>{
      NativeAdType.small1: 138,
      NativeAdType.small2: 146,
      NativeAdType.small3: 146,
      NativeAdType.small4: 130,
      NativeAdType.small5: 146,
      NativeAdType.big1: 420,
      NativeAdType.big2: 420,
      NativeAdType.big6: 420,
      NativeAdType.collap1Expanded: 420,
      NativeAdType.big3: 390,
      NativeAdType.big4: 390,
      NativeAdType.big7: 390,
      NativeAdType.big8: 390,
      NativeAdType.collap2Expanded: 400,
      NativeAdType.collap3Expanded: 400,
      NativeAdType.big5: 360,
      NativeAdType.big9: 360,
      NativeAdType.card1: 270,
      NativeAdType.card2: 270,
    };
    for (final entry in expectedHeights.entries) {
      expect(
        entry.key.resolveHeight(1000, platform: TargetPlatform.iOS),
        entry.value,
        reason: entry.key.factoryId,
      );
      expect(
        NativeAdTemplate.forFactory(
          entry.key.factoryId,
        ).heightForScreen(1000, platform: TargetPlatform.iOS),
        entry.value,
        reason: entry.key.factoryId,
      );
    }
    expect(
      NativeAdType.card1.resolveHeight(1000, platform: TargetPlatform.android),
      240,
    );
    expect(
      NativeAdType.big1.resolveHeight(1000, platform: TargetPlatform.android),
      360,
    );
    expect(
      NativeAdType.card2.resolveHeight(1000, platform: TargetPlatform.android),
      isNull,
    );
    for (final type in [
      NativeAdType.small2,
      NativeAdType.small3,
      NativeAdType.small5,
    ]) {
      expect(
        type.resolveHeight(
          1200,
          platform: TargetPlatform.iOS,
          screenWidth: 834,
        ),
        166,
        reason: type.factoryId,
      );
    }
  });

  test('native height uses the current platform by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(NativeAdType.big1.resolveHeight(1000), 420);
    expect(NativeAdTemplate.forFactory('Card1').heightForScreen(1000), 270);
  });

  testWidgets('native shimmer families fit their factory reference heights', (
    tester,
  ) async {
    for (final factoryId in [
      'Tiny1',
      'Tiny2',
      'Small1',
      'Small3',
      'Big4',
      'Big5',
      'Full1',
      'Full2',
      'Collap1Expanded',
      'Collap2Expanded',
      'Collap3Expanded',
      'Collap1Collapsed',
      'Card1',
    ]) {
      final template = NativeAdTemplate.forFactory(factoryId);
      final height = template.heightForScreen(1000) ?? 620.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: height,
                child: NativeAdShimmer(
                  factoryId: factoryId,
                  width: 360,
                  height: height,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: factoryId);
    }
  });

  test('collapse factories resolve to their matching compact layouts', () {
    expect(
      NativeAdTemplate.forFactory('Collap1Expanded').collapsedFactoryId,
      'Collap1Collapsed',
    );
    expect(
      NativeAdTemplate.forFactory('Collap2Expanded').collapsedFactoryId,
      'Collap2Collapsed',
    );
    expect(
      NativeAdTemplate.forFactory('Collap3Expanded').collapsedFactoryId,
      'Collap3Collapsed',
    );
    expect(NativeAdTemplate.forFactory('Small1').isCollapsible, isFalse);
  });
}
