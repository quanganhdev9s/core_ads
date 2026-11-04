import 'package:core_ads/core_ads.dart';
import 'package:core_ads/src/data/repositories/ads_repository_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart' as plugin;

const _placement = AdPlacement(
  key: 'native_test',
  type: AdType.native,
  nativeFactoryId: 'nativeFactory',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoogleAdsService service;
  late AdsRepositoryImpl repository;
  late List<MethodCall> calls;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    plugin.instanceManager = plugin.AdInstanceManager(
      'plugins.flutter.io/google_mobile_ads',
    );
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(plugin.instanceManager.channel, (call) async {
          calls.add(call);
          if (call.method == 'MobileAds#initialize') {
            return InitializationStatus(<String, AdapterStatus>{});
          }
          return null;
        });
    final config = AdsConfig(
      environment: AdsEnvironment.test,
      adUnitIds: AdUnitIds.typed({
        _placement: const AdUnitId.waterfall(['high', 'fallback']),
      }),
    );
    service = GoogleAdsService();
    repository = AdsRepositoryImpl(config: config, service: service);
    expect((await repository.initialize()).isSuccess, isTrue);
  });

  tearDown(() async {
    await repository.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(plugin.instanceManager.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('clear discards a late success without caching it', () async {
    final loading = repository.load(_placement);
    await Future<void>.delayed(Duration.zero);
    final ad = plugin.instanceManager.adFor(0) as NativeAd;
    await repository.clear(_placement);
    ad.listener.onAdLoaded!(ad);
    final result = await loading;
    expect((result as AdFailed<void>).failure.code, 'load_cancelled');
    expect(repository.getStatus(_placement), AdLoadStatus.idle);
    expect(service.nativeAd(_placement), isA<SizedBox>());
    expect(plugin.instanceManager.adFor(0), isNull);
    expect(calls.where((c) => c.method == 'loadNativeAd'), hasLength(1));
  });

  test(
    'late failure cannot clear a newly loaded native or run fallback',
    () async {
      final first = repository.load(_placement);
      await Future<void>.delayed(Duration.zero);
      final oldAd = plugin.instanceManager.adFor(0) as NativeAd;
      await repository.clear(_placement);
      final second = repository.load(_placement);
      await Future<void>.delayed(Duration.zero);
      final newAd = plugin.instanceManager.adFor(1) as NativeAd;
      newAd.listener.onAdLoaded!(newAd);
      expect((await second).isSuccess, isTrue);
      oldAd.listener.onAdFailedToLoad!(
        oldAd,
        LoadAdError(
          3,
          'test',
          'no fill',
          ResponseInfo(
            responseId: '',
            mediationAdapterClassName: '',
            adapterResponses: [],
            loadedAdapterResponseInfo: null,
            responseExtras: {},
          ),
        ),
      );
      expect((await first as AdFailed<void>).failure.code, 'load_cancelled');
      expect(repository.getStatus(_placement), AdLoadStatus.ready);
      expect((service.nativeAd(_placement) as AdWidget).ad, same(newAd));
      expect(calls.where((c) => c.method == 'loadNativeAd'), hasLength(2));
    },
  );

  test('late success cannot replace a newer native or emit ready', () async {
    final statuses = <AdLoadStatus>[];
    void listener(AdsLoadEvent event) {
      if (event.placement == _placement) statuses.add(event.status);
    }

    CoreAds.addLoadListener(listener);
    addTearDown(() => CoreAds.removeLoadListener(listener));
    final first = repository.load(_placement);
    await Future<void>.delayed(Duration.zero);
    final oldAd = plugin.instanceManager.adFor(0) as NativeAd;
    await repository.clear(_placement);
    final second = repository.load(_placement);
    await Future<void>.delayed(Duration.zero);
    final newAd = plugin.instanceManager.adFor(1) as NativeAd;
    newAd.listener.onAdLoaded!(newAd);
    expect((await second).isSuccess, isTrue);
    oldAd.listener.onAdLoaded!(oldAd);
    expect((await first as AdFailed<void>).failure.code, 'load_cancelled');
    expect((service.nativeAd(_placement) as AdWidget).ad, same(newAd));
    expect(plugin.instanceManager.adFor(0), isNull);
    expect(statuses, [
      AdLoadStatus.loading,
      AdLoadStatus.loading,
      AdLoadStatus.ready,
    ]);
  });

  test('repeated load and clear only keeps the latest native', () async {
    final first = repository.load(_placement);
    await Future<void>.delayed(Duration.zero);
    final firstAd = plugin.instanceManager.adFor(0) as NativeAd;
    await repository.clear(_placement);
    final second = repository.load(_placement);
    await Future<void>.delayed(Duration.zero);
    final secondAd = plugin.instanceManager.adFor(1) as NativeAd;
    await repository.clear(_placement);
    final third = repository.load(_placement);
    await Future<void>.delayed(Duration.zero);
    final latestAd = plugin.instanceManager.adFor(2) as NativeAd;
    latestAd.listener.onAdLoaded!(latestAd);
    expect((await third).isSuccess, isTrue);
    secondAd.listener.onAdLoaded!(secondAd);
    firstAd.listener.onAdLoaded!(firstAd);
    expect((await first as AdFailed<void>).failure.code, 'load_cancelled');
    expect((await second as AdFailed<void>).failure.code, 'load_cancelled');
    expect((service.nativeAd(_placement) as AdWidget).ad, same(latestAd));
    expect(plugin.instanceManager.adFor(0), isNull);
    expect(plugin.instanceManager.adFor(1), isNull);
    expect(calls.where((c) => c.method == 'loadNativeAd'), hasLength(3));
  });

  test('new load can start before clear completes', () async {
    final first = repository.load(_placement);
    await Future<void>.delayed(Duration.zero);
    final oldAd = plugin.instanceManager.adFor(0) as NativeAd;
    final clearing = repository.clear(_placement);
    final second = repository.load(_placement);
    await clearing;
    await Future<void>.delayed(Duration.zero);
    final newAd = plugin.instanceManager.adFor(1) as NativeAd;
    oldAd.listener.onAdLoaded!(oldAd);
    newAd.listener.onAdLoaded!(newAd);
    expect((await first as AdFailed<void>).failure.code, 'load_cancelled');
    expect((await second).isSuccess, isTrue);
    expect((service.nativeAd(_placement) as AdWidget).ad, same(newAd));
  });

  test('an active request still tries the next waterfall unit', () async {
    final loading = repository.load(_placement);
    await Future<void>.delayed(Duration.zero);
    final firstAd = plugin.instanceManager.adFor(0) as NativeAd;
    firstAd.listener.onAdFailedToLoad!(
      firstAd,
      LoadAdError(3, 'test', 'no fill', const ResponseInfo(responseExtras: {})),
    );
    await Future<void>.delayed(Duration.zero);
    final fallback = plugin.instanceManager.adFor(1) as NativeAd;
    expect(fallback.adUnitId, 'fallback');
    fallback.listener.onAdLoaded!(fallback);
    expect((await loading).isSuccess, isTrue);
    expect((service.nativeAd(_placement) as AdWidget).ad, same(fallback));
  });

  for (final operation in ['clearType', 'dispose']) {
    test('$operation invalidates a pending native callback', () async {
      final loading = repository.load(_placement);
      await Future<void>.delayed(Duration.zero);
      final ad = plugin.instanceManager.adFor(0) as NativeAd;
      if (operation == 'clearType') {
        await repository.clearType(AdType.native);
      } else {
        await repository.dispose();
      }
      ad.listener.onAdLoaded!(ad);
      expect((await loading as AdFailed<void>).failure.code, 'load_cancelled');
      expect(service.nativeAd(_placement), isA<SizedBox>());
      expect(plugin.instanceManager.adFor(0), isNull);
    });
  }
}
