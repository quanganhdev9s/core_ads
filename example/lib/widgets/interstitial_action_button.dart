import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

class InterstitialActionButton extends StatefulWidget {
  const InterstitialActionButton({
    required this.placement,
    this.onLoad,
    this.onShow,
    super.key,
  });

  final AdPlacement placement;
  final Function()? onLoad;
  final Function()? onShow;

  @override
  State<InterstitialActionButton> createState() =>
      _InterstitialActionButtonState();
}

class _InterstitialActionButtonState extends State<InterstitialActionButton> {
  String _state = 'idle';

  @override
  void initState() {
    super.initState();
    CoreAds.addLoadListener(_handleAdLoad);
    _state = _stateFromStatus(CoreAds.getStatus(widget.placement));
  }

  @override
  void didUpdateWidget(covariant InterstitialActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _state = _stateFromStatus(CoreAds.getStatus(widget.placement));
    }
  }

  @override
  void dispose() {
    CoreAds.removeLoadListener(_handleAdLoad);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: _onPressed, child: Text(_text));
  }

  void _handleAdLoad(AdsLoadEvent event) {
    if (!mounted || event.placement != widget.placement) {
      return;
    }

    setState(() {
      _state = _stateFromStatus(event.status, failure: event.failure);
    });
  }

  String _stateFromStatus(AdLoadStatus status, {AdFailure? failure}) {
    return switch (status) {
      AdLoadStatus.idle => 'idle',
      AdLoadStatus.loading => 'loading',
      AdLoadStatus.ready => 'ready',
      AdLoadStatus.failed => 'failed: ${failure?.code ?? 'unknown'}',
    };
  }

  VoidCallback? get _onPressed {
    if (_state == 'ready') {
      return _show;
    }
    if (_state == 'loading' || _state == 'showing') {
      return null;
    }
    return _load;
  }

  Future<void> _load() async {
    setState(() {
      _state = 'loading';
    });
    await widget.onLoad?.call();
    await CoreAds.load(widget.placement);
    if (!mounted) {
      return;
    }

    setState(() {
      _state = _stateFromStatus(CoreAds.getStatus(widget.placement));
    });
  }

  Future<void> _show() async {
    setState(() {
      _state = 'showing';
    });
    await widget.onShow?.call();
    await CoreAds.showInterstitial(widget.placement);
    if (!mounted) {
      return;
    }

    setState(() {
      _state = _stateFromStatus(CoreAds.getStatus(widget.placement));
    });
  }

  String get _text {
    if (_state == 'ready') {
      return 'Show interstitial';
    }
    if (_state == 'loading') {
      return 'Loading interstitial...';
    }
    if (_state == 'showing') {
      return 'Showing interstitial...';
    }
    if (_state.startsWith('failed')) {
      return 'Retry interstitial';
    }
    return 'Load interstitial';
  }
}
