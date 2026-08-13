# Ads Load And Cache

Tài liệu này mô tả cơ chế load, waterfall, preload, retry và cache hiện tại của
package.

Show lifecycle được mô tả riêng trong `ADS_SHOW.md`.

Khi thay đổi bất kỳ logic nào liên quan đến các phần sau, phải cập nhật file
này trong cùng thay đổi:

- `CoreAds.load`, `CoreAds.getStatus`
- `AdsRepository.load`, `AdsRepository.getStatus`
- các manager trong `lib/src/ads/**`
- `GoogleAdsService.load`, `_loadWaterfall`, `clear`, `clearType`
- `AdPlacement.preloadAfterShow`
- `AdUnitId`, `AdUnitIds`
- retry hoặc `clearOnDispose` của `AdsBanner`, `AdsNative`, `AdsCollapsibleNative`

## Khái Niệm

### AdResult

`AdResult<T>` thể hiện kết quả của một operation async.

Ví dụ:

- `CoreAds.initialize(...)`
- `CoreAds.load(placement)`
- `CoreAds.showInterstitial(placement)`
- `CoreAds.showRewarded(...)`

`AdResult.success` nghĩa là operation vừa gọi thành công.
`AdResult.failure` nghĩa là operation vừa gọi thất bại và có `AdFailure`.

`AdResult` không đại diện cho trạng thái cache lâu dài của placement.

### AdLoadStatus

`AdLoadStatus` thể hiện trạng thái load/cache hiện tại của một placement.

Các trạng thái hợp lệ:

- `idle`: chưa load, đã clear, đã show xong và không còn ad ready, hoặc manager chưa tồn tại.
- `loading`: đang có request load.
- `ready`: đã load thành công và có ad cache sẵn sàng.
- `failed`: lần load gần nhất thất bại.

`shown`, `dismissed`, `impression` thuộc show lifecycle, không thuộc load
status. Các trạng thái đó đi qua `AdsCallbacks`.

## Load Flow Chung

Ứng dụng gọi:

```dart
await CoreAds.load(placement);
```

Luồng hiện tại:

1. `CoreAds.load` kiểm tra repository đã initialize chưa.
2. Nếu chưa có repository, trả `AdResult.failure(AdFailure.notReady())` và emit load status `failed`.
3. `AdsRepositoryImpl.load` emit `AdLoadStatus.loading`.
4. Repository chọn manager theo `placement.type`.
5. Manager kiểm tra điều kiện load.
6. Manager gọi `AdsService.load`.
7. `GoogleAdsService` load theo ad unit id hoặc waterfall.
8. Repository emit:
   - `AdLoadStatus.ready` nếu result success.
   - `AdLoadStatus.failed` nếu result failure.
9. Repository trả `AdResult` cho caller.

`CoreAds.getStatus(placement)` đọc status từ manager hiện có. Nếu manager chưa
tồn tại, trả `AdLoadStatus.idle` và không tạo manager mới.

## Điều Kiện Được Load

### Tất Cả Ad Types

Manager chỉ load khi consent cho phép request ads:

```dart
consentManager.canRequestAds == true
```

Nếu không được request ads:

- status chuyển `failed`.
- trả `AdResult.failure(AdFailure.consentDenied())`.

### Banner Và Native

`BannerManager` và `NativeManager` có guard cache:

- nếu status đang `ready`, `load()` trả success ngay.
- không gọi SDK load lại.

Điều này tránh dispose/recreate `AdWidget` không cần thiết.

### Fullscreen Ads

Áp dụng cho:

- interstitial
- rewarded
- rewarded interstitial
- app open

Các manager fullscreen có guard:

- nếu status `ready`, `load()` trả success ngay.
- nếu đang có `_loadFuture`, các lần gọi `load()` tiếp theo dùng chung future đó.
- nếu status `idle` hoặc `failed`, sẽ load mới.

Mục tiêu là tránh nhiều load request song song và tránh mất ad cache đang ready.

### App Open Expiration

`AppOpenManager` hiện có check hết hạn khi show hoặc khi handle app resume.

- Nếu app open đã expired khi show: trả failure `expired`.
- Nếu app resume mà app open expired: manager load lại.

Các fullscreen ad khác hiện chưa có TTL/expiration check.

## Waterfall

Một placement có thể dùng single ad unit id:

```dart
AdUnitIds({
  placement: 'ca-app-pub-xxx/unit',
})
```

Hoặc dùng typed config để hỗ trợ waterfall:

```dart
AdUnitIds.typed({
  placement: AdUnitId.waterfall([
    'ca-app-pub-xxx/high',
    'ca-app-pub-xxx/mid',
    'ca-app-pub-xxx/backfill',
  ]),
})
```

Waterfall áp dụng trong `GoogleAdsService` cho:

- banner
- native
- interstitial
- rewarded
- rewarded interstitial
- app open

Quy trình waterfall:

1. Lấy list ad unit ids từ `AdUnitIds.idsFor(placement)`.
2. Nếu list rỗng, trả `missing_ad_unit_id`.
3. Thử load id ở index `0`.
4. Nếu success, cache ad và trả success.
5. Nếu fail, log failure và thử id tiếp theo.
6. Chỉ trả failure khi toàn bộ ids fail.

`onFailed`/load failure chỉ nên được app xem là fail cuối cùng của placement.
Các fail ở giữa waterfall là fallback nội bộ.

## Preload Sau Khi Show

`AdPlacement` có:

```dart
preloadAfterShow
```

Mặc định là `true`.

Áp dụng cho fullscreen managers:

- interstitial
- rewarded
- rewarded interstitial
- app open

Sau khi show success:

1. Manager set load status về `idle` vì ad fullscreen đã bị consume.
2. Nếu `preloadAfterShow == true`, manager gọi `load()` lại.
3. Nếu preload thành công, status quay về `ready`.
4. Nếu preload fail, status là `failed`.

Nếu `preloadAfterShow == false`, sau show success status giữ ở `idle`.

Banner/native không có preload sau show vì chúng không có show operation riêng.

## Retry

Package không tự retry vô hạn khi load fail.

### Widget Retry

`AdsBanner` và `AdsNative` có:

- `errorBuilder(context, retry)`
- `showRetryButton`

Khi user bấm retry:

- widget gọi lại `CoreAds.load(placement)`.
- nếu success, widget render `CoreAds.banner(...)` hoặc `CoreAds.nativeAd(...)`.
- nếu fail, widget tiếp tục hiển thị error.

### Waterfall Không Phải Retry

Waterfall là fallback trong một lần load operation.

Ví dụ 3 ids:

```text
id_0 fail -> id_1 fail -> id_2 success
```

Vẫn được xem là một lần `CoreAds.load` success.

### Fullscreen Retry

Fullscreen không tự retry sau load fail.

Ứng dụng có thể gọi lại:

```dart
await CoreAds.load(placement);
```

hoặc dùng UI listener/status để hiện nút retry.

## Cache

Cache được lưu theo `AdPlacement`.

`GoogleAdsService` giữ các map riêng:

- `_bannerAds`
- `_interstitialAds`
- `_rewardedAds`
- `_rewardedInterstitialAds`
- `_appOpenAds`
- `_nativeAds`

Repository cũng giữ manager theo placement:

- `_bannerManagers`
- `_interstitialManagers`
- `_rewardManagers`
- `_rewardedInterstitialManagers`
- `_appOpenManagers`
- `_nativeManagers`

Vì key là `AdPlacement`, nếu app cần 2 banner/native cùng hiển thị đồng thời,
nên dùng 2 placement khác nhau. Hai placement có thể dùng cùng ad unit id.

Không dùng cùng một placement cho 2 `AdWidget` đồng thời, vì cùng một native/banner
ad instance không thể mount ở nhiều vị trí trong widget tree.

## Cache Theo Ad Type

### Banner

- Load success cache `BannerAd` vào `_bannerAds[placement]`.
- `BannerManager` status `ready` nghĩa là có cached banner.
- Khi load mới thực sự chạy, service dispose cached banner cũ trước.
- `AdsBanner` mặc định `clearOnDispose: true`, nên khi widget dispose sẽ gọi
  `CoreAds.clear(placement)`.
- Nếu muốn giữ cache khi đổi màn, set `clearOnDispose: false`.

### Native

- Load success cache `NativeAd` vào `_nativeAds[placement]`.
- `NativeManager` status `ready` nghĩa là có cached native ad.
- Khi load mới thực sự chạy, service dispose cached native cũ trước.
- `AdsNative` mặc định `clearOnDispose: true`.
- Nếu cùng màn có nhiều native widgets, mỗi widget nên có placement riêng.

### Interstitial

- Load success cache `InterstitialAd` vào `_interstitialAds[placement]`.
- Show success dispose/remove ad trong service callback.
- Sau show, manager status về `idle`.
- Nếu `preloadAfterShow` true, manager load lại để tạo cache mới.

### Rewarded

- Load success cache `RewardedAd` vào `_rewardedAds[placement]`.
- Show success dispose/remove ad trong service callback.
- Reward callback chỉ gọi khi SDK xác nhận user earned reward.
- Sau show, preload theo `placement.preloadAfterShow`.

### Rewarded Interstitial

- Load success cache `RewardedInterstitialAd` vào `_rewardedInterstitialAds[placement]`.
- Show success dispose/remove ad trong service callback.
- Sau show, preload theo `placement.preloadAfterShow`.

### App Open

- Load success cache `AppOpenAd` vào `_appOpenAds[placement]`.
- Manager lưu `_loadedAt`.
- Show kiểm tra `_isShowing`, status `ready`, expiration và fullscreen cooldown.
- Show success dispose/remove ad trong service callback.
- Sau show, preload theo `placement.preloadAfterShow`.

## Clear Cache

Clear từng placement:

```dart
await CoreAds.clear(placement);
```

Clear theo type:

```dart
await CoreAds.clearType(AdType.interstitial);
```

Khi clear:

1. Repository remove/dispose manager tương ứng.
2. Service remove/dispose ad instance trong cache map.
3. `AdsReloadNotifier` báo widget visible reload lại nếu cần.

`clearType(type)` clear mọi placement đã có manager thuộc type đó, sau đó gọi
service clear theo type.

## Load Listener

`CoreAds.addLoadListener` cho UI listen tiến trình/kết quả của load operation
được phát ra khi app gọi `CoreAds.load(...)`.

Listener này không phải source of truth cho trạng thái cache hiện tại của
placement. Nếu UI cần biết trạng thái hiện tại sau các flow như show, clear,
hoặc preload nội bộ sau fullscreen show, hãy đọc `CoreAds.getStatus(placement)`.

```dart
CoreAds.addLoadListener((event) {
  final placement = event.placement;
  final status = event.status;
  final failure = event.failure;
});
```

`AdsLoadNotifier` dùng queue FIFO và `addPostFrameCallback` khi event phát ra
trong build/layout/paint frame.

Lý do:

- tránh listener UI gọi `setState` khi Flutter đang build.
- giữ đúng thứ tự event, ví dụ `loading -> ready`.

Nếu event đầu tiên phải defer sau frame, các event tiếp theo cũng vào queue để
không bị `ready` chạy trước `loading`.

## Những Điểm Cần Nhớ Khi Sửa Code

- Không thêm auto retry vô hạn nếu chưa có config rõ ràng.
- Không load lại khi placement đang `ready` trừ khi có clear/refresh chủ động.
- Không tạo manager mới chỉ để đọc status. Nếu manager chưa tồn tại, status là `idle`.
- Fullscreen ad sau show không còn cache cũ; status phải về `idle` trước khi preload.
- Banner/native dùng `AdWidget`; không share cùng placement cho nhiều widget đồng thời.
- Khi thay đổi load/cache/preload/retry/waterfall, cập nhật file này.
