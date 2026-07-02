import 'dart:io';

class ExampleAdUnitIds {
  const ExampleAdUnitIds._();

  static const invalid = 'invalid-ad-unit-id';

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
