# Ads Show

Tai lieu nay mo ta co che show fullscreen ads hien tai cua package.

Khi thay doi bat ky logic nao lien quan den cac phan sau, cap nhat file nay
trong cung thay doi:

- `CoreAds.showInterstitial`
- `CoreAds.showRewarded`
- `CoreAds.showRewardedInterstitial`
- `CoreAds.showAppOpen`
- `CoreAds.canShow`
- `CoreAds.handleAppResume`
- cac fullscreen manager trong `lib/src/ads/**`
- `FullscreenAdController`
- `AdPlacement.preloadAfterShow`

## Pham Vi

Show operation chi ap dung cho fullscreen ads:

- interstitial
- rewarded
- rewarded interstitial
- app open

Banner va native khong co show operation rieng. Hai format nay duoc load va
render qua widget `AdsBanner` hoac `AdsNative`.

## Dieu Kien Duoc Show

Mot fullscreen placement chi show khi manager dang co status `ready`.

Neu ad chua ready, package tra:

```dart
AdResult.failure(AdFailure.notReady())
```

Luon preload truoc khi show:

```dart
final loadResult = await CoreAds.load(placement);
if (loadResult.isSuccess) {
  await CoreAds.showInterstitial(placement);
}
```

Co the check nhanh bang:

```dart
if (CoreAds.canShow(placement)) {
  await CoreAds.showInterstitial(placement);
}
```

`canShow` chi la snapshot tai thoi diem goi. App van phai xu ly `AdResult` cua
`show...()` vi trang thai co the thay doi ngay sau do.

Theo ad type:

- banner: luon `false`, vi banner render qua widget.
- native: luon `false`, vi native render qua widget.
- interstitial: `ready`, khong co fullscreen ad khac dang show, va cooldown hop le.
- rewarded: `ready` va khong co fullscreen ad khac dang show.
- rewarded interstitial: `ready` va khong co fullscreen ad khac dang show.
- app open: `ready`, chua expired, khong dang show, khong co fullscreen ad khac
  dang show, va cooldown hop le.

Neu can doi fullscreen gap sau khi da init:

```dart
CoreAds.updateFullscreenCooldown(
  const FullscreenAdCooldownConfig(
    interstitialInterval: Duration(seconds: 3),
    appOpenInterval: Duration(seconds: 10),
    interstitialAppOpenInterval: Duration(seconds: 10),
  ),
);
```

Gia tri moi duoc dung cho cac lan `canShow` va `show...()` tiep theo.

## Ket Qua Show

`show...()` tra `Future<AdResult<void>>`.

Voi Google Mobile Ads service hien tai:

- success duoc complete khi SDK bao fullscreen ad dismissed.
- failure duoc complete khi SDK bao failed-to-show hoac khi service throw.
- reward khong duoc suy ra tu `AdResult.success`; reward chi cap trong SDK
  reward callback.

Dieu nay giup caller biet show flow da ket thuc, nhung cac analytics callbacks
nhu `onShown`, `onImpression`, `onPaid`, `onClicked` van la event rieng.

## Show Interstitial

Ung dung goi:

```dart
await CoreAds.showInterstitial(placement);
```

Luong hien tai:

1. `CoreAds` kiem tra repository da initialize chua.
2. Repository kiem tra `placement.type == AdType.interstitial`.
3. `InterstitialManager` kiem tra status `ready`.
4. Manager kiem tra fullscreen cooldown.
5. Manager acquire fullscreen lock.
6. Service show ad da cache.
7. Service emit callbacks theo SDK lifecycle.
8. Manager release fullscreen lock.
9. Neu show success, manager mark shown va consume cache.
10. Neu `preloadAfterShow == true`, manager load lai trong background.

Sau show success, ad interstitial cu khong con reusable.

## Show Rewarded

Ung dung goi:

```dart
await CoreAds.showRewarded(
  placement: placement,
  onRewardEarned: () {
    // Grant reward here.
  },
);
```

`onRewardEarned` chi duoc goi khi SDK xac nhan user earned reward. Khong grant
reward dua tren `AdResult.success` rieng le.

`AdResult.success` cua show rewarded nghia la show flow hoan tat thanh cong theo
manager/service. Reward callback van la nguon dung de cap phan thuong.

Rewarded ad dung fullscreen lock, nen khong show de len interstitial, rewarded
interstitial hoac app open dang show.

## Show Rewarded Interstitial

Ung dung goi:

```dart
await CoreAds.showRewardedInterstitial(
  placement: placement,
  onRewardEarned: () {
    // Grant reward here.
  },
);
```

Flow giong rewarded ad:

- can status `ready`.
- can acquire fullscreen lock.
- reward chi cap trong `onRewardEarned`.
- sau show success, cache bi consume.
- neu `preloadAfterShow == true`, manager load lai.

## Show App Open

Ung dung co the show thu cong:

```dart
await CoreAds.showAppOpen(placement);
```

`AppOpenManager` co them cac check rieng:

- neu dang show app open: tra failure `already_showing`.
- neu status khong `ready`: tra failure `not_ready`.
- neu cached app open da het han: set status `failed` va tra failure `expired`.
- neu cooldown chua het: tra cooldown failure tu `FullscreenAdController`.
- neu fullscreen ad khac dang show: tra failure `fullscreen_ad_showing`.

Mac dinh app open cache het han sau 60 phut.

## Handle App Resume

Ung dung co the dung lifecycle helper:

```dart
final observer = AdsAppLifecycleObserver(
  appOpenPlacement: placement,
);

observer.attach();
observer.detach();
```

Hoac goi thu cong:

```dart
await CoreAds.handleAppResume(placement);
```

Flow resume:

- neu app open dang show hoac dang load: tra success ngay va khong lam gi them.
- neu chua ready: load app open moi.
- neu ready nhung expired: set failed roi load lai.
- neu ready va con han: show app open.

## Fullscreen Lock

Package dung mot fullscreen lock chung qua `FullscreenAdController`.

Muc tieu:

- khong co 2 fullscreen ads show cung luc.
- rewarded khong de len interstitial.
- app open khong de len interstitial, va nguoc lai.

Neu lock dang bi placement khac giu, show tra:

```text
fullscreen_ad_showing
```

Lock duoc release trong `finally`, ke ca khi service show fail/throw.

## Cooldown

Cooldown hien ap dung cho:

- interstitial -> interstitial
- app open -> app open
- interstitial <-> app open

Rewarded va rewarded interstitial khong dung cooldown mac dinh trong
`FullscreenAdController`, nhung van dung fullscreen lock.

Config:

```dart
FullscreenAdCooldownConfig(
  interstitialInterval: Duration(seconds: 7),
  appOpenInterval: Duration(seconds: 7),
  interstitialAppOpenInterval: Duration(seconds: 7),
);
```

Runtime update:

```dart
CoreAds.updateFullscreenCooldown(
  const FullscreenAdCooldownConfig(
    interstitialInterval: Duration(seconds: 3),
    appOpenInterval: Duration(seconds: 10),
    interstitialAppOpenInterval: Duration(seconds: 10),
  ),
);
```

Cooldown chi duoc mark sau show success.

## Status Sau Khi Show

Sau show success:

- fullscreen ad da cache bi dispose/remove trong service callback.
- manager set status ve `idle`.
- neu `preloadAfterShow == true`, manager goi `load()` lai trong background.
- neu preload lai success, status ve `ready`.
- neu preload lai fail, status ve `failed`.

`show...()` tra ket qua show, khong doi preload sau show hoan tat.

Sau show failure:

- service dispose/remove ad neu SDK bao failed-to-show.
- manager set status `failed`.
- caller nhan `AdResult.failure(...)`.

`AdsLoadListener` khong emit cho toan bo show lifecycle. Listener nay chi the
hien load operation do app goi `CoreAds.load(...)`. Neu UI can trang thai cache
hien tai sau show/preload noi bo, doc:

```dart
CoreAds.getStatus(placement);
```

## Callbacks

Show lifecycle di qua `AdsCallbacks` trong `AdsConfig`:

- `onShown`
- `onDismissed`
- `onClicked`
- `onImpression`
- `onPaid`
- `onFailed`
- `onRewardEarned`

`onDismissed`, `onClicked`, `onImpression`, `onPaid` phu thuoc vao callback SDK
thuc te. Khong phai moi ad/show deu bat buoc co du tat ca event.

## Failure Codes Thuong Gap Khi Show

- `not_ready`: chua load, da consume sau show, hoac chua initialize.
- `invalid_placement_type`: goi sai API show cho placement type.
- `fullscreen_ad_showing`: dang co fullscreen ad khac show.
- `interstitial_cooldown_active`: interstitial cooldown chua het.
- `app_open_cooldown_active`: app open cooldown chua het.
- `interstitial_app_open_cooldown_active`: cooldown cheo interstitial/app open.
- `already_showing`: app open dang show.
- `expired`: app open cache da het han.
- `unknown`: SDK throw hoac loi show khong map duoc.

## Nguyen Tac Khi Sua Show Logic

- Khong show khi status khong `ready`.
- Luon release fullscreen lock trong `finally`.
- Reward chi cap trong SDK reward callback.
- Sau fullscreen show success, cache cu phai duoc consume.
- Neu thay doi preload sau show, cap nhat ca `ADS_LOAD_AND_CACHE.md`.
- Neu them failure code show moi, cap nhat README va file nay.
