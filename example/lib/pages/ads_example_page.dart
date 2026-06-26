import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../ads/example_ad_configs.dart';
import '../ads/example_ads_manager.dart';
import '../ads/example_placements.dart';
import 'example_second_page.dart';

class AdsExamplePage extends StatefulWidget {
  const AdsExamplePage({super.key});

  @override
  State<AdsExamplePage> createState() => _AdsExamplePageState();
}

class _AdsExamplePageState extends State<AdsExamplePage> {
  late final ExampleAdsManager _adsManager;
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
    _adsManager = ExampleAdsManager();
    _lifecycleObserver = AdsAppLifecycleObserver(
      appOpenPlacement: ExamplePlacements.appOpen,
    )..attach();
    _initialize();
  }

  @override
  void dispose() {
    _lifecycleObserver.detach();
    _adsManager.disposeAds();
    _adsManager.dispose();
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

    final result = await _adsManager.initialize(
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
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _adsInitialized = result.isSuccess;
      _status = result.isSuccess ? 'Initialized' : 'Initialize failed';
    });

    if (result.isSuccess) {
      await _showSplashInterstitial();
      _loadPlacement(ExamplePlacements.appOpen);
    }
  }

  Future<void> _showSplashInterstitial() async {
    _setAdState(ExamplePlacements.splashInterstitial, 'loading');
    final loadResult = await _adsManager.load(
      ExamplePlacements.splashInterstitial,
    );
    if (loadResult.isFailure) {
      _setAdState(
        ExamplePlacements.splashInterstitial,
        'failed: ${_failureCode(loadResult)}',
      );
      _setStatus('Splash interstitial load failed');
      return;
    }

    _setAdState(ExamplePlacements.splashInterstitial, 'showing');
    final showResult = await _adsManager.showInterstitial(
      ExamplePlacements.splashInterstitial,
    );
    if (showResult.isFailure) {
      _setAdState(
        ExamplePlacements.splashInterstitial,
        'skipped: ${_failureCode(showResult)}',
      );
      _setStatus('Splash interstitial skipped');
      return;
    }

    _setStatus('Splash interstitial finished');
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
    final result = await _adsManager.load(placement);
    if (result.isFailure) {
      _setAdState(placement, 'failed: ${_failureCode(result)}');
    }
  }

  Future<void> _showInterstitial() async {
    await _initialize();
    _setAdState(ExamplePlacements.interstitial, 'showing');
    final result = await _adsManager.showInterstitial(
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
    final result = await _adsManager.showRewarded(
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
    final result = await _adsManager.showRewardedInterstitial(
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
    final result = await _adsManager.showAppOpen(ExamplePlacements.appOpen);
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

  void _onNativeLoaded() {
    _setAdState(ExamplePlacements.native, 'ready');
  }

  void _onNativeFailed(AdFailure failure) {
    _setAdState(ExamplePlacements.native, 'failed: ${failure.code}');
  }

  void _onCollapsibleNativeLoaded() {
    _setAdState(ExamplePlacements.collapsibleNative, 'ready');
  }

  void _onCollapsibleNativeFailed(AdFailure failure) {
    _setAdState(ExamplePlacements.collapsibleNative, 'failed: ${failure.code}');
  }

  void _onCollapsedBannerLoaded() {
    _setAdState(ExamplePlacements.collapsedBanner, 'ready');
  }

  void _onCollapsedBannerFailed(AdFailure failure) {
    _setAdState(ExamplePlacements.collapsedBanner, 'failed: ${failure.code}');
  }

  Future<void> _openSecondPage() async {
    await _initialize();
    await _preloadReturnHomeInterstitial();

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ExampleSecondPage()));

    if (!mounted) {
      return;
    }

    await _showReturnHomeInterstitial();
  }

  Future<void> _preloadReturnHomeInterstitial() async {
    _setAdState(ExamplePlacements.returnHomeInterstitial, 'loading');
    final result = await _adsManager.load(
      ExamplePlacements.returnHomeInterstitial,
    );
    if (result.isFailure) {
      _setAdState(
        ExamplePlacements.returnHomeInterstitial,
        'failed: ${_failureCode(result)}',
      );
    }
  }

  Future<void> _showReturnHomeInterstitial() async {
    _setAdState(ExamplePlacements.returnHomeInterstitial, 'showing');
    final result = await _adsManager.showInterstitial(
      ExamplePlacements.returnHomeInterstitial,
    );
    if (result.isFailure) {
      _setAdState(
        ExamplePlacements.returnHomeInterstitial,
        'skipped: ${_failureCode(result)}',
      );
      _setStatus('Return home interstitial skipped');
      return;
    }

    _setStatus('Return home interstitial finished');
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Premium user'),
            value: _adsManager.isPremiumUser,
            onChanged: (value) async {
              setState(() {
                _adsManager.setPremiumUser(value);
                if (!value) {
                  _adsInitialized = false;
                  _initAdsFuture = null;
                }
                _status = value ? 'Premium enabled' : 'Premium disabled';
              });

              if (!value) {
                await _initialize();
              }
            },
          ),
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
            AdsNative(
              placement: ExamplePlacements.native,
              loading: const AdsLoadingWidget(height: 260),
              error: const SizedBox(
                height: 260,
                child: Center(child: Text('Native ad failed to load')),
              ),
              showRetryButton: true,
              onLoaded: _onNativeLoaded,
              onFailed: _onNativeFailed,
            )
          else
            const AdsLoadingWidget(height: 260),
          const SizedBox(height: 24),
          const Text('Collapsible native'),
          const SizedBox(height: 8),
          if (_adsInitialized)
            AdsCollapsibleNative(
              nativePlacement: ExamplePlacements.collapsibleNative,
              bannerPlacement: ExamplePlacements.collapsedBanner,
              nativeHeight: 260,
              bannerConfig: ExampleAdConfigs.collapsedBanner,
              nativeLoading: const AdsLoadingWidget(height: 260),
              nativeError: const SizedBox(
                height: 260,
                child: Center(child: Text('Collapsible native failed to load')),
              ),
              bannerBackgroundColor: Colors.black,
              showRetryButton: true,
              onNativeLoaded: _onCollapsibleNativeLoaded,
              onNativeFailed: _onCollapsibleNativeFailed,
              onBannerLoaded: _onCollapsedBannerLoaded,
              onBannerFailed: _onCollapsedBannerFailed,
              onCollapsed: () => _setStatus('Collapsible native collapsed'),
              onExpanded: () => _setStatus('Collapsible native expanded'),
            )
          else
            const AdsLoadingWidget(height: 260),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _openSecondPage,
            child: const Text('Open second page'),
          ),
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
            onPressed: () => _adsManager.clearType(AdType.interstitial),
            child: const Text('Clear interstitial cache'),
          ),
          OutlinedButton(
            onPressed: () => _adsManager.clearType(AdType.banner),
            child: const Text('Clear banner cache'),
          ),
          OutlinedButton(
            onPressed: () => _adsManager.clearType(AdType.native),
            child: const Text('Clear native cache'),
          ),
        ],
      ),
    );
  }
}
