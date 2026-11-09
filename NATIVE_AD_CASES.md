# Quy tắc native ads trong config v2

Config v2 chỉ dùng `enable: true/false` để bật hoặc tắt placement. `template`
chọn layout native. Các trường `pages` quyết định native xuất hiện ở màn nào;
`enable` không còn mang số thứ tự màn. Nếu một placement sai, parser ghi log và
tắt riêng placement đó; các placement khác vẫn được đọc.

## Language và Get Start

`AdsLanguageStartNative` chọn placement theo `hasSelectedLanguage`. Trước khi
chọn, màn Language dùng `native_language`; sau khi chọn, dùng
`native_language_2`. Get Start dùng cặp `native_get_start` và
`native_get_start_2`. Mỗi placement có ad unit và `template` riêng, nên khi
chuyển trạng thái widget tải ad của placement mới. Không dùng `pages` để chọn
placement và không đổi CTA của ad đã tải. Nếu thiếu `template`, native dùng
layout mặc định `Big1`.

```json
{
  "ad_placements": {
    "full": {
      "native_language": {"enable": true, "template": "LanguageStart1"},
      "native_language_2": {"enable": true, "template": "LanguageStart2"}
    },
    "basic": {}
  }
}
```

```dart
AdsLanguageStartNative(
  controller: ads,
  placementKey: 'native_language',
  selectedPlacementKey: 'native_language_2',
  hasSelectedLanguage: selectedLanguage != null,
)
```

Mã nguồn: [widget Flutter](lib/src/ads/native/ads_language_start_native.dart),
[factory Android](android/src/main/kotlin/com/quanganh/core_ads/NativeAdLayouts.kt),
[factory iOS](ios/core_ads/Sources/core_ads/NativeAdLayouts.swift).

## Onboarding

`pages.native_onboarding` là danh sách các màn 1–4 hiển thị native inline.
`pages.native_full_onboarding` là danh sách các lần chuyển màn 1–4 mở native
toàn màn hình. Ví dụ:

```json
{
  "ad_placements": {
    "full": {
      "native_onboarding": {"enable": true, "template": "Big4"},
      "native_full_onboarding": {"enable": true, "template": "Full1"}
    },
    "basic": {}
  },
  "pages": {
    "native_onboarding": [2, 4],
    "native_full_onboarding": [2]
  }
}
```

Gọi cùng key full native sau mỗi lần rời một màn onboarding. Với ví dụ trên,
chỉ lần thứ hai mở ad. `showFullscreenAds` hoàn thành khi ad đóng hoặc không thể
hiển thị; app tiếp tục điều hướng sau đó.

```dart
await ads.showFullscreenAds(context, AdScenarioKeys.nativeFullOnboarding);
if (!context.mounted) return;
// Chuyển sang màn onboarding tiếp theo.
```

Khi bắt đầu lượt onboarding mới trên cùng `AdScenarioController`, gọi
`ads.resetNativeFullOnboarding()` trước lần chuyển màn đầu tiên.
