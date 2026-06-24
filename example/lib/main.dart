import 'dart:io';

import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoreAdsExampleApp());
}

class ExamplePlacements {
  static const banner = AdPlacement(key: 'example_banner', type: AdType.banner);

  static const native = AdPlacement(key: 'example_native', type: AdType.native);

  static const interstitial = AdPlacement(
    key: 'example_interstitial',
    type: AdType.interstitial,
  );

  static const rewarded = AdPlacement(
    key: 'example_rewarded',
    type: AdType.rewarded,
  );

  static const rewardedInterstitial = AdPlacement(
    key: 'example_rewarded_interstitial',
    type: AdType.rewardedInterstitial,
  );

  static const appOpen = AdPlacement(
    key: 'example_app_open',
    type: AdType.appOpen,
  );

  static const values = [
    banner,
    native,
    interstitial,
    rewarded,
    rewardedInterstitial,
    appOpen,
  ];
}

class ExampleAdConfigs {
  static const banner = BannerAdConfig.anchoredAdaptive();
}

class ExampleAdUnitIds {
  static String get banner {
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/2934735716'
        : 'ca-app-pub-3940256099942544/6300978111';
  }

  static String get interstitial {
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/4411468910'
        : 'ca-app-pub-3940256099942544/1033173712';
  }

  static String get rewarded {
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/1712485313'
        : 'ca-app-pub-3940256099942544/5224354917';
  }

  static String get rewardedInterstitial {
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/6978759866'
        : 'ca-app-pub-3940256099942544/5354046379';
  }

  static String get appOpen {
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/5575463023'
        : 'ca-app-pub-3940256099942544/9257395921';
  }

  static String get native {
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/3986624511'
        : 'ca-app-pub-3940256099942544/2247696110';
  }
}

class CoreAdsExampleApp extends StatelessWidget {
  const CoreAdsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'core_ads example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const AdsExamplePage(),
    );
  }
}

class AdsExamplePage extends StatefulWidget {
  const AdsExamplePage({super.key});

  @override
  State<AdsExamplePage> createState() => _AdsExamplePageState();
}

class _AdsExamplePageState extends State<AdsExamplePage> {
  late final AdsAppLifecycleObserver _lifecycleObserver;

  String _status = 'Not initialized';
  int _rewardCount = 0;
  bool _adsInitialized = false;
  final Map<AdPlacement, String> _adStates = {
    for (final placement in ExamplePlacements.values) placement: 'idle',
  };
  Future<void>? _initAdsFuture;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AdsAppLifecycleObserver(
      appOpenPlacement: ExamplePlacements.appOpen,
    )..attach();
    _initialize();
  }

  @override
  void dispose() {
    _lifecycleObserver.detach();
    AppAds.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final existingFuture = _initAdsFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _initializeAds();
    _initAdsFuture = future;
    await future;

    if (!_adsInitialized) {
      _initAdsFuture = null;
    }
  }

  Future<void> _initializeAds() async {
    _setStatus('Initializing');

    final result = await AppAds.initialize(
      AdsConfig(
        environment: AdsEnvironment.test,
        adUnitIds: AdUnitIds({
          ExamplePlacements.banner: ExampleAdUnitIds.banner,
          ExamplePlacements.interstitial: ExampleAdUnitIds.interstitial,
          ExamplePlacements.rewarded: ExampleAdUnitIds.rewarded,
          ExamplePlacements.rewardedInterstitial:
              ExampleAdUnitIds.rewardedInterstitial,
          ExamplePlacements.appOpen: ExampleAdUnitIds.appOpen,
          ExamplePlacements.native: ExampleAdUnitIds.native,
        }),
        bannerAdConfigs: BannerAdConfigs({
          ExamplePlacements.banner: ExampleAdConfigs.banner,
        }),
        nativeAdConfigs: NativeAdConfigs({
          ExamplePlacements.native: const NativeAdConfig(
            factoryId: 'example_native_factory',
            height: 140,
          ),
        }),
        consent: const AdsConsentConfig(
          enabled: true,
          requestTrackingAuthorizationOnIos: true,
        ),
        fullscreenCooldown: const FullscreenAdCooldownConfig(),
        callbacks: AdsCallbacks(
          onLoaded: (event) {
            _setAdState(event.placement, 'ready');
            _setStatus('Loaded ${event.placement.key}');
          },
          onFailed: (event) {
            _setAdState(event.placement, 'failed: ${event.failure.code}');
            _setStatus('Failed ${event.placement.key}: ${event.failure.code}');
          },
          onShown: (event) {
            _setAdState(event.placement, 'shown');
            _setStatus('Shown ${event.placement.key}');
          },
          onDismissed: (event) {
            _setAdState(event.placement, 'dismissed');
            _setStatus('Dismissed ${event.placement.key}');
          },
          onImpression: (event) =>
              _setStatus('Impression ${event.placement.key}'),
          onPaid: (event) => _setStatus(
            'Paid ${event.placement.key}: ${event.valueMicros} ${event.currencyCode}',
          ),
          onRewardEarned: (event) => _setStatus(
            'Reward event ${event.placement.key}: ${event.amount} ${event.rewardType}',
          ),
        ),
        enableDebugLogs: true,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _adsInitialized = result.isSuccess;
      _status = result.isSuccess ? 'Initialized' : 'Initialize failed';
    });
  }

  Future<void> _loadFullscreenAds() async {
    await _initialize();
    await _loadPlacement(ExamplePlacements.interstitial);
    await _loadPlacement(ExamplePlacements.rewarded);
    await _loadPlacement(ExamplePlacements.rewardedInterstitial);
    await _loadPlacement(ExamplePlacements.appOpen);
    _setStatus('Fullscreen placements requested');
  }

  Future<void> _loadPlacement(AdPlacement placement) async {
    _setAdState(placement, 'loading');
    final result = await AppAds.load(placement);
    if (result.isFailure) {
      _setAdState(placement, 'failed: ${_failureCode(result)}');
    }
  }

  Future<void> _showInterstitial() async {
    await _initialize();
    _setAdState(ExamplePlacements.interstitial, 'showing');
    final result = await AppAds.showInterstitial(
      ExamplePlacements.interstitial,
    );
    if (result.isFailure) {
      _setAdState(
        ExamplePlacements.interstitial,
        'skipped: ${_failureCode(result)}',
      );
    }
    _setStatus(
      result.isSuccess ? 'Interstitial finished' : 'Interstitial skipped',
    );
  }

  Future<void> _showRewarded() async {
    await _initialize();
    _setAdState(ExamplePlacements.rewarded, 'showing');
    final result = await AppAds.showRewarded(
      placement: ExamplePlacements.rewarded,
      onRewardEarned: _grantReward,
    );
    if (result.isFailure) {
      _setAdState(
        ExamplePlacements.rewarded,
        'skipped: ${_failureCode(result)}',
      );
    }
    _setStatus(result.isSuccess ? 'Rewarded finished' : 'Rewarded skipped');
  }

  Future<void> _showRewardedInterstitial() async {
    await _initialize();
    _setAdState(ExamplePlacements.rewardedInterstitial, 'showing');
    final result = await AppAds.showRewardedInterstitial(
      placement: ExamplePlacements.rewardedInterstitial,
      onRewardEarned: _grantReward,
    );
    if (result.isFailure) {
      _setAdState(
        ExamplePlacements.rewardedInterstitial,
        'skipped: ${_failureCode(result)}',
      );
    }
    _setStatus(
      result.isSuccess
          ? 'Rewarded interstitial finished'
          : 'Rewarded interstitial skipped',
    );
  }

  Future<void> _showAppOpen() async {
    await _initialize();
    _setAdState(ExamplePlacements.appOpen, 'showing');
    final result = await AppAds.showAppOpen(ExamplePlacements.appOpen);
    if (result.isFailure) {
      _setAdState(
        ExamplePlacements.appOpen,
        'skipped: ${_failureCode(result)}',
      );
    }
    _setStatus(result.isSuccess ? 'App open finished' : 'App open skipped');
  }

  void _grantReward() {
    setState(() {
      _rewardCount += 1;
    });
  }

  void _setStatus(String value) {
    if (!mounted) {
      return;
    }

    setState(() {
      _status = value;
    });
  }

  void _setAdState(AdPlacement placement, String state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _adStates[placement] = state;
    });
  }

  void _onBannerLoaded() {
    _setAdState(ExamplePlacements.banner, 'ready');
  }

  void _onBannerFailed(AdFailure failure) {
    _setAdState(ExamplePlacements.banner, 'failed: ${failure.code}');
  }

  String _adStateText() {
    return ExamplePlacements.values
        .map(
          (placement) =>
              '${placement.key} (${placement.type.name}): ${_adStates[placement] ?? 'idle'}',
        )
        .join('\n');
  }

  String _failureCode(AdResult<void> result) {
    return switch (result) {
      AdFailed<void>(failure: final failure) => failure.code,
      _ => 'unknown',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('core_ads example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Status: $_status'),
          const SizedBox(height: 8),
          Text('Rewards: $_rewardCount'),
          const SizedBox(height: 8),
          Text(_adStateText()),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _adsInitialized ? null : _initialize,
            child: const Text('Initialize'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _loadFullscreenAds,
            child: const Text('Load fullscreen ads'),
          ),
          const SizedBox(height: 16),
          const Text('Banner'),
          const SizedBox(height: 8),
          if (_adsInitialized)
            AdsBanner(
              placement: ExamplePlacements.banner,
              config: ExampleAdConfigs.banner,
              showRetryButton: true,
              onLoaded: _onBannerLoaded,
              onFailed: _onBannerFailed,
            )
          else
            const AdsLoadingWidget(),
          const SizedBox(height: 24),
          const Text('Native'),
          const SizedBox(height: 8),
          if (_adsInitialized)
            const AdsNative(
              placement: ExamplePlacements.native,
              loading: AdsLoadingWidget(height: 140),
              error: SizedBox(
                height: 140,
                child: Center(child: Text('Native ad failed to load')),
              ),
            )
          else
            const AdsLoadingWidget(height: 140),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _showInterstitial,
                child: const Text('Interstitial'),
              ),
              OutlinedButton(
                onPressed: _showRewarded,
                child: const Text('Rewarded'),
              ),
              OutlinedButton(
                onPressed: _showRewardedInterstitial,
                child: const Text('Rewarded interstitial'),
              ),
              OutlinedButton(
                onPressed: _showAppOpen,
                child: const Text('App open'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => AppAds.clearType(AdType.interstitial),
            child: const Text('Clear interstitial cache'),
          ),
        ],
      ),
    );
  }
}
