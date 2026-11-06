# Quy tắc xử lý `native_*` ads

`enable` được đọc khi parse JSON. Nếu giá trị nằm ngoài các trường hợp hỗ trợ, hoặc nhánh được chọn thiếu `name*`/`id*`, placement đó được quy về `enable=0`: không tải và không hiển thị native. Các placement khác trong cùng script vẫn hoạt động.

| Placement | `enable` hợp lệ | Cách chọn native |
| --- | --- | --- |
| `native_*` có một nhánh `native` | `0`, `1` | `0` tắt; `1` hiển thị nhánh `native`. Ví dụ `native_result`, `native_intro_full`. |
| `native_*` có nhiều nhánh đánh số | `0` hoặc các chữ số 1–9 khác nhau, có nhánh tương ứng | Mỗi chữ số chọn một nhánh. Ví dụ `24` chọn nhánh 2 và 4. Chữ số `0`, chữ số lặp, hoặc thiếu nhánh tương ứng đều về `0`. |
| `native_intro` | `0` hoặc các chữ số 1–4 khác nhau | Chọn native ở từng màn intro theo số màn. Ví dụ `24` chọn màn 2 và 4. Số ngoài 1–4, dù JSON có thêm nhánh, đều về `0`. |
| `native_language`, `native_get_start` | Chỉ `0`, `1`, `2` | Dùng factory riêng và thay đổi CTA theo trạng thái chọn ngôn ngữ; xem phần dưới. `12`, `21` và mọi giá trị khác đều về `0`. |
| `native_full_onboarding` | `0` hoặc số nguyên dương | `enable=N` mở native toàn màn hình sau lần chuyển màn onboarding thứ N, đếm từ 1. Số âm về `0`. |

Các nhánh native trong `inter_*`, `ads_splash` và `banner_*` theo quy tắc `enable` của nhóm placement tương ứng; chúng không dùng quy tắc chữ số của `native_*`.

## `native_language` và `native_get_start`

Hai key này dùng widget `AdsLanguageStartNative` trên Android và iOS. Màn hình truyền trạng thái **đã chọn ngôn ngữ** qua `hasSelectedLanguage`; widget đọc `enable` từ `AdScenarioController` để chọn nhánh quảng cáo và kiểu CTA.

| `enable` | Nhánh native | Trước khi chọn ngôn ngữ | Sau khi chọn ngôn ngữ |
| --- | --- | --- | --- |
| `0` | Không có | Ẩn quảng cáo | Ẩn quảng cáo |
| `1` | `native_language1` hoặc `native_get_start1` | Media → thông tin ad → CTA xanh rộng hết card | Giữ nguyên ad; CTA xanh thu nhỏ, nằm bên phải phía dưới |
| `2` | `native_language2` hoặc `native_get_start2` | CTA tím rộng hết card → media → thông tin ad | Giữ nguyên ad; CTA đổi sang xanh, không đổi vị trí hoặc kích thước |
| Giá trị khác | Không có | Quy về `0`, ẩn quảng cáo | Quy về `0`, ẩn quảng cáo |

Ví dụ `enable=12` không hiển thị hai ad. Giá trị này cũng được quy về `0`, kể cả khi JSON khai báo đủ cả hai nhánh.

### Cách dùng

```dart
AdsLanguageStartNative(
  controller: ads, // AdScenarioController đã initialize.
  placementKey: 'native_language', // Hoặc 'native_get_start'.
  hasSelectedLanguage: selectedLanguage != null,
)
```

Màn hình sở hữu biến `selectedLanguage` và cập nhật nó khi người dùng chọn ngôn ngữ. Khi vào màn Get Start, truyền trạng thái đã chọn thực tế của ứng dụng vào cùng tham số. Widget không tự lưu lựa chọn này.

`enable` chỉ quyết định nhánh ad được tải; `hasSelectedLanguage` chỉ đổi giao diện CTA. Khi giá trị bool thay đổi, CTA được cập nhật ngay trên native ad đã tải, không gửi thêm yêu cầu tải ad. CTA vẫn là asset được đăng ký với Google Mobile Ads để nhận tương tác đúng cách.

Hai nhánh dùng factory riêng `LanguageStart1` và `LanguageStart2`. Với hai key đặc biệt này, factory tương ứng được ưu tiên dù JSON có `native_template`; các key native khác vẫn theo `native_template` thông thường. Chiều cao mặc định của hai factory là `0.36 ×` chiều cao màn hình trên Android và iOS; có thể truyền `height` vào widget nếu màn hình cần kích thước khác. Khi đang tải, widget hiển thị shimmer theo bố cục của nhánh đã chọn.

Mã nguồn: [widget Flutter](lib/src/ads/native/ads_language_start_native.dart), [factory Android](android/src/main/kotlin/com/quanganh/core_ads/NativeAdLayouts.kt), [factory iOS](ios/core_ads/Sources/core_ads/NativeAdLayouts.swift).

## `native_full_onboarding`

Trong script, khai báo một nhánh `native`. Có thể đặt `native_template` bằng `Full1` đến `Full5`; mặc định là `Full1`. Template khác loại Full làm placement về `enable=0`.

```json
{
  "native_full_onboarding": {
    "enable": 2,
    "native_template": "Full1",
    "native": {"name1": "NATIVE_FULL_ONBOARDING"}
  }
}
```

Gọi cùng key **một lần ở mỗi lần rời màn onboarding**, kể cả khi ad đang tắt. Ví dụ `enable=2`: sau màn 1 package bỏ qua, sau màn 2 package mở native toàn màn hình, các lần sau bỏ qua. `showScenario` hoàn thành khi ad đóng; sau đó app tiếp tục điều hướng. Nếu ad không tải được, kết quả `nativeAdShown` là `false` và app vẫn tiếp tục.

```dart
await ads.showScenario(context, AdScenarioKeys.nativeFullOnboarding);
if (!context.mounted) return;
// Chuyển sang màn onboarding tiếp theo.
```

Bộ đếm nằm trong `AdScenarioController`, tiếp tục đếm qua các lần cập nhật Remote Config thành công. Khi bắt đầu **một lượt onboarding mới** trên cùng controller, gọi `ads.resetNativeFullOnboarding()` trước lần chuyển màn đầu tiên. Lần hiển thị chỉ xảy ra một lần cho mỗi lượt; `enable=0` không hiển thị.
