# foldable_scaffold: tài liệu bàn giao

File này để một phiên Claude mới (hoặc người mới) tiếp tục công việc mà không cần lịch sử chat. Cập nhật nó mỗi khi có thay đổi lớn. Trạng thái ghi nhận: `0.1.0-dev.10` (pha 2: scaffold theo `foldable_core` 0.2.0-dev.1).

## 1. Mục tiêu

Làm `foldable_scaffold` thành một Scaffold hai pane "chuẩn" như `Scaffold` của Flutter, và hỗ trợ **iPhone Duo** (màn hình gập hai màn của Apple, HIG: https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo). Package còn pre-release nên **được phép đổi API phá vỡ** mà không cần báo trước.

Workspace (melos): `packages/foldable_scaffold` (package này), `foldable_core`, `foldable_router`, `foldable_dev_tools`. **`foldable_dev_tools` hỏng từ trước, bỏ qua.** Test của `foldable_router/example` fail từ trước ("Cycle in the parent chain"), không liên quan.

## 2. Quy ước làm việc với người dùng

- Trả lời bằng **tiếng Việt**. Code, tên API, dartdoc, CHANGELOG viết tiếng Anh.
- **Không commit.** Người dùng tự commit.
- Việc code lớn giao cho sub-agent; mình kiểm tra lại độc lập rồi báo cáo.
- Tên thiết bị luôn là **iPhone Duo** (không dùng "iPhone Fold" trong tài liệu).
- Người dùng chạy iOS build (máy Ubuntu này **không compile được Swift**). Người dùng điền số đo thiết bị từ nút Copy của dialog "Platform data".
- Chỉ hỗ trợ Xcode mới nhất (chỉ nó build được cho iPhone Duo). iOS tối thiểu **15**.
- App bar luôn ở trên. Navigation/toolbar bên trong từng pane **không hỗ trợ**.
- Báo cáo trung thực: nói rõ cái gì chưa kiểm chứng trên máy thật.

## 3. Lệnh kiểm tra (chạy ở `packages/foldable_scaffold`)

Flutter qua FVM: `~/fvm/versions/3.44.0/bin/{flutter,dart}`.

```bash
F=~/fvm/versions/3.44.0/bin
$F/dart format --output=none --set-exit-if-changed lib test example/lib example/test
$F/flutter analyze --fatal-infos          # cũng chạy trong example/
$F/flutter test                           # package; cũng example/, ../foldable_router, ../foldable_core
$F/dart doc --dry-run; rm -rf doc         # phải 0 warning; xoá doc/ do lệnh tạo ra
```

Mốc pha 2: package **443** test (trước 435), example **8** test, tất cả pass. Thêm `foldable_scaffold_pane_scope_test`, `foldable_scaffold_transition_scope_test`.

Ràng buộc kiến trúc: `foldable_scaffold` và `foldable_router` **không** phụ thuộc nhau; cả hai chỉ phụ thuộc `foldable_core`; core chỉ phụ thuộc `flutter`. Không import router từ scaffold.

## 4. Cấu trúc code (`lib/src`)

| File | Vai trò |
|---|---|
| `foldable_scaffold.dart` | Widget và State chính: slot kiểu Scaffold, `navigationBuilder`, `_buildSideNavigation`/`_buildTopNavigation`/`_buildBottomNavigationBar`, `_railCutoutInsets`, `_CutoutAvoidingAppBar`, ẩn pane, controller, state restoration. Publish `FoldablePaneLayout` (canSplit / visibility / axis) quanh cả hai pane; mỗi pane bọc `FoldablePaneScope`. Delegate layout private: `_PaneLayoutDelegate`. `_isTransitioning` ưu tiên `paneTransition`, rồi `FoldablePaneTransitionScope`. |
| `foldable_scaffold_layout.dart` | Hàm thuần: `computeFrameGeometry`, `computePaneLayout`, `computeSnapTarget`, `resolveFold`, `resolveCutouts`, `cutoutInsets`. `FrameGeometry`, `PaneGeometry` (có `axis`), `PaneSlot`. Dễ test nhất. |
| `foldable_navigation.dart` | `FoldableNavigationEdge`, `FoldableNavigationPlacement(edge, {extent, alignment, insideInset})`, `FoldableNavigationAlignment`, `FoldableLayoutInfo`, resolver, `FoldableNavigationPlacements.handheld/desktop/forPlatform`, `defaultNavigationPlacement`, `FoldableNavigationBuilder`, `FoldableVerticalBarScope`. |
| `foldable_fold.dart` | `FoldableFold` (axis, hinge dọc/ngang). |
| `foldable_platform_{state,source,scope}.dart` | Cầu nối Dart cho iOS: `FoldablePlatformScope` đưa vùng reserved + `verticalBarEdge` vào `MediaQuery.displayFeatures` và `FoldableVerticalBarScope`. Ngoài iOS trả child nguyên vẹn. |
| `foldable_scaffold_{controller,divider,theme}.dart`, `foldable_breakpoints.dart` | Controller, divider (bàn phím, semantics), `ThemeExtension`, breakpoints. |

Khác:
- Barrel `lib/foldable_scaffold.dart` chỉ re-export các tên core cần thiết (`FoldableMotion`, `FoldablePane`, `FoldablePaneLayout`, `FoldablePaneScope`, `FoldablePaneTransitionScope`, `FoldablePaneTransitions`), không export cả barrel core.
- `ios/foldable_scaffold/Sources/foldable_scaffold/FoldableScaffoldPlugin.swift`: plugin iOS (kênh `foldable_scaffold/platform` method `getState` và `foldable_scaffold/platform/events`). KVO bounds + CADisplayLink 10fps. API iOS 27.1+ bọc `#available`. `ios/foldable_scaffold.podspec` và `ios/foldable_scaffold/Package.swift` (deployment 15.0).
- `example/lib/main.dart` (ví dụ đầy đủ, `FoldablePlatformScope` trong `MaterialApp.builder`), `example/lib/platform_debug.dart` (dialog "Platform data" + nút Copy + ô pose, dòng "view padding (raw …)"). Đọc `FoldablePaneLayout.maybeOf(context)?.canSplit`.
- Test: mỗi file trong `test/` theo tên tính năng. `foldable_scaffold_pane_scope_test.dart` (scope từng pane + canSplit theo breakpoints + đếm build). `foldable_scaffold_transition_scope_test.dart` (snap khi `FoldablePaneTransitions.begin()`). `foldable_scaffold_device_profiles_test.dart` chứa 7 profile iPhone Duo thật (số đo từ `report iPhone Duo.rtf`), field `padding` còn TODO (số 0 giữ chỗ). `..._inside_inset_test.dart` (navigation trong dải hệ thống), `..._rail_safe_area_test.dart` (hồi quy SafeArea của rail).

## 5. Mô hình navigation (quan trọng)

- Một `navigationBuilder(context, placement, constraints, padding)` dùng cho mọi vị trí. Vị trí do `navigationPlacement` (hàm resolver) quyết định; mặc định `defaultNavigationPlacement`: có `verticalBarEdge` bên (start/end/left/right) thì `FoldableNavigationPlacement(edge, alignment: end, insideInset: true)`; còn lại rail (start) nếu đủ rộng, không thì bottom.
- `insideInset` + inset hệ thống của cạnh đó > 0: slot rộng đúng bằng dải (84 trên iPhone Duo), `extent` bị bỏ qua, navigation lấp đầy dải, `constraints.maxWidth` = bề rộng dải. Inset = 0 thì rơi về slot `extent`.
- `alignment == end`: scaffold chừa đáy `max(cutout.bottom, padding.bottom)`.
- Scaffold **gỡ phần padding đã áp** (cạnh bên, và đáy khi đã chừa) khỏi `MediaQuery` của navigation cạnh bên, vì `NavigationRail` có `SafeArea` riêng. Bỏ bước này thì rail bị trừ inset hai lần và co về bề rộng 0.
- `padding` truyền cho builder: cạnh bên = 0, các cạnh khác nguyên (kể cả `bottom`), builder đừng áp lại `padding.bottom` khi `alignment: end`.
- `avoidCutouts: false` chỉ tắt việc tránh camera; vị trí trong dải và chừa đáy vẫn giữ.
- Bản lề ngang: pane xếp trên → dưới (`paneAxis`, `stacksAtFold`). Hiện chỉ xếp chồng khi có bản lề ngang đang active.

## 6. Dữ liệu iPhone Duo đã đo

- Inner: landscape 951x669, portrait 669x951. Outer: 466x678 / 678x466.
- `verticalBarEdge`: inner landscape `end`; inner portrait null; outer `end`/`start` tuỳ phía camera.
- Division (bản lề): inactive khi mở hết, active khi half-open (dọc ở landscape, ngang ở portrait), không có khi đóng.
- Inner landscape mở hết: `MediaQuery.padding` right 84, bottom 35; camera cutout L867 T0 R951 B124; icon hệ thống (đồng hồ, Wi-Fi) trong dải x 867–951, tâm x ≈ 909.
- Outer landscape 678x466, `verticalBarEdge: start`: view padding (84, 0, 0, 34); cutout L29.33 T29.33 R66.33 B66.33 và L0 T0 R84 B82.
- Dialog (`showDialog`) có SafeArea nên padding trong dialog là 0; `DisplayFeatureSubScreen` lọc feature theo nửa màn. Vì vậy dialog "Platform data" in thêm dòng "view padding (raw …)" và "platform displayFeatures (all …)".
- Xoay màn hình ở pose 11 không xoay là hành vi hệ thống (app Maps cũng vậy); đã hoàn nguyên dòng `PortraitUpsideDown` trong Info.plist của example.

## 7. Chưa kiểm chứng / việc còn lại

Chưa kiểm chứng trên máy thật:
1. Swift, podspec, Package.swift chưa từng được compile (cần Xcode mới nhất; thử cả CocoaPods và SwiftPM).
2. iOS cũ (15–26) không crash (`#available`) — chưa chạy.
3. Rail trong dải hệ thống sau fix SafeArea ở outer landscape (kỳ vọng x 0–84, y 82–432). Rail 4 mục có nhãn cao hơn 350 nên có thể phải cuộn: cân nhắc `labelType: selected/none` trong example ở dải thấp.
4. Các tư thế khác: inner portrait, half-open dọc/ngang, outer hai phía camera, xoay lúc đang chạy.
5. Animation khi navigation đổi cạnh/inset, độ trễ polling 10fps, `backgroundColor` tuỳ chỉnh phủ dải, dark mode, Dynamic Type, bàn phím, VoiceOver, các nền tảng khác (Android/web/desktop).

Việc người dùng cần làm: điền `padding` thật vào profile test (copy "Platform data" từng pose), chuyển `report iPhone Duo.rtf` ra khỏi package trước khi publish (hiện chưa được track).

Khoảng trống đã biết:
- Pane content, bottom bar, top bar chưa tránh cutout; app bar không chuyển sang cạnh (quyết định của người dùng).
- **Câu hỏi chưa trả lời:** inner portrait mở hết (cao hơn rộng) có nên xếp hai pane trên–dưới như "arrangement view" của Apple, hay giữ quy tắc hiện tại (chỉ xếp khi có bản lề ngang active)?
- Apple chừa khoảng trống giữa nhóm điều khiển trên và dưới trong dải; mới làm phần navigation ở đáy.

## 8. Bài học để khỏi lặp lại

- Đừng đoán số đo/hành vi thiết bị: tái hiện bằng widget test với `FakeViewPadding`, `tester.view.displayFeatures` và số đo thật trước khi kết luận.
- Widget có `SafeArea` riêng (NavigationRail, AppBar) bị ảnh hưởng bởi `MediaQuery.padding` còn sót: luôn kiểm tra khi scaffold đã tự áp padding.
- Đừng nhầm "chạy bản cũ": người dùng chạy code đã push; tìm nguyên nhân bằng tái hiện.
- Khi tìm tài liệu Apple, WebFetch chỉ trả tiêu đề (trang render bằng JS): dùng browser tích hợp.
