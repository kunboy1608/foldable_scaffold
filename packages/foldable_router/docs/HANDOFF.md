# foldable_router: tài liệu bàn giao

Đọc file này trước khi làm bất cứ việc gì trên package ở một phiên mới. Nó ghi
lại cách làm việc đã thống nhất, các quyết định thiết kế, hiện trạng, và việc
còn dở. Cập nhật mục 6 và 7 mỗi khi kết thúc một lượt việc.

Cập nhật lần cuối: 2026-11-13.

## 1. Cách làm việc với chủ dự án

- Trả lời bằng tiếng Việt. Cứ hỏi lại bất cứ lúc nào khi có điểm chưa rõ; các
  quyết định thiết kế là của chủ dự án.
- Chỉ làm trong `packages/foldable_router`. Không quan tâm thư mục anh em;
  package phải đứng độc lập.
- Dùng `fvm flutter` / `fvm dart` (Flutter 3.44.0, Dart SDK ^3.12.0).
- Code do sub-agent viết. Vai trò của phiên chính:
  1. Bàn thiết kế với chủ dự án, hỏi các lựa chọn.
  2. Viết message (brief) trong một khối ```text để chủ dự án copy gửi sub-agent.
  3. Khi chủ dự án dán báo cáo của sub-agent về: tự kiểm lại, không tin báo cáo.
  4. Báo lại trung thực: cái gì đã kiểm, cái gì chưa, báo cáo sai ở đâu.
- Phiên chính được tự viết: test tạm để kiểm (xóa ngay sau khi chạy), công cụ
  thử tay, tài liệu. Không tự sửa code của package.
- Phiên trước chủ dự án yêu cầu không chạy lệnh git và không xem lịch sử git.
  Đó là yêu cầu của riêng phiên đó; phiên mới nên hỏi lại trước khi dùng git.
  Các brief vẫn luôn cấm sub-agent chạy git.

### Khuôn của một brief

Mỗi brief đã dùng đều có: bối cảnh và ràng buộc (thư mục, fvm, không git, "kẹt
thì DỪNG và báo, không lách"), mô tả lỗi kèm cách tái hiện và số đo, yêu cầu
đánh số, test bắt buộc, điều kiện hoàn tất (analyze sạch, test qua, không skip,
không nới test cũ), và danh sách thứ phải báo cáo lại. Sau brief luôn liệt kê
riêng cho chủ dự án những quyết định mà phiên chính tự đưa vào.

### Cách kiểm báo cáo của sub-agent

- Chạy lại `fvm flutter analyze` và `fvm flutter test` ở cả package và example.
- `grep` tìm `skip:`, override lạ (từng có `runtimeType => Navigator`), export
  bị lộ, vùng so ảnh bị thu hẹp cho test qua.
- Viết test tạm `test/zz_repro_test.dart` cho đúng kịch bản của chủ dự án và
  cho các ca mà báo cáo ghi "chưa kiểm". Xóa sau khi chạy.
- Lỗi hiển thị phải kiểm bằng điểm ảnh, không bằng `tester.getRect`. Dùng
  `test/pixel_utils.dart` (`capture`, `Screenshot.diff`), chụp từng khung 16 ms,
  chạy cả `TargetPlatform.linux`, `android`, `iOS` vì hiệu ứng khác nhau.
- Trong `testWidgets`, đừng `await` một điều hướng có `Future.delayed` mà không
  pump: test sẽ treo. Gọi không await rồi `tester.pump(duration)`.
- Test của example cần `setUp(session.reset)`.

## 2. Package làm gì

Router Navigation 2.0. Mỗi đích là một lớp con của `FoldableRoute` (đường dẫn
tĩnh, tham số đi trong query string, chuỗi `parent`). API chính:
`open` / `openUri` / `push` / `pop` / `refresh`, `routeFor`, `isNavigating`,
router là `Listenable`. `FoldableShellRoute` giữ stack riêng cho từng nhánh
(tab). Có predictive back và xử lý back cho route không có page (dialog, sheet).

Tài liệu cho người dùng nằm ở `README.md`; lịch sử thay đổi ở `CHANGELOG.md`
(tất cả đang ghi dưới `0.0.1`, quy ước là không tăng version).

## 3. Bản đồ mã nguồn

| File | Nội dung |
|---|---|
| `lib/foldable_router.dart` | Export công khai. Giữ danh sách `show` chặt. |
| `lib/src/foldable_route.dart` | `FoldableRoute`: `path`, `params`, `parent`, `redirect(context, state)`, `uri`, `==` theo query đã mã hóa. |
| `lib/src/foldable_params.dart` | `FoldableParams`: đọc tham số URL có kiểu. |
| `lib/src/foldable_router.dart` | `FoldableRouter`, `routeFor`, `paneOf`, `close`. |
| `lib/src/foldable_shell_route.dart` | `FoldableShellRoute`, `buildShell`, `buildPanes`. |
| `lib/src/foldable_panes.dart` | Hai ô: `FoldablePanes`, `PaneMetrics`, `BranchArea`/`_RawPaneArea`, `PaneFrame`, `PaneSlot`, `PanePageView`. |
| `lib/src/router_delegate.dart` | Delegate: stack, shell, back, `_BranchPageRoute`, `_BranchNavigator`, kiểm lại ngầm. |
| `lib/src/redirect_resolver.dart` | Chạy chuỗi redirect, token thế hệ, vòng lặp, `maxRedirects`. |
| `lib/src/route_information_parser.dart` | Chuyển URL và bắt context của `Router`. |
| `example/` | App mẫu (linux, android, web). Tab Users hiển thị hai ô từ 840. |
| `example/lib/manual_lab.dart` | App lab cho thử tay params và redirect. |
| `example/tool/manual_test.sh`, `example/MANUAL_TESTS.md` | Script và 45 ca thử tay. |

## 4. Quyết định thiết kế đã chốt

### Hai ô trong ShellRoute

- URL, stack và redirect giống hệt nhau ở một ô và hai ô. Hai ô chỉ là cách vẽ.
- Cửa sổ trượt trên stack của tab: trang trên cùng ở ô phải (`secondary`),
  trang ngay dưới ở ô trái (`primary`), trang sâu hơn bị ẩn nhưng còn sống.
  `[A]`: A trái, phải trống. `[A,B]`: A trái, B phải. `[A,B,C]`: B trái, C phải.
- App quyết định khi nào dùng hai ô: `buildPanes(context, panes)` trả `null`
  là một ô, trả widget chứa `panes.primary` / `panes.secondary` là hai ô.
- Giữ trạng thái trang là yêu cầu cốt lõi, không đánh đổi. Mỗi tab một
  Navigator; trang không rời Navigator, chỉ đổi chỗ được vẽ.
- Back hệ thống và predictive back chỉ gỡ trang trên cùng.
- `BackButton` của Flutter: ở ô phải gỡ trang phải; ở ô trái gỡ cả hai trang
  đang thấy. Ô được đoán từ lần chạm cuối, không có thì theo tiêu điểm. API
  chắc chắn là `FoldableRouter.close(context)`.
- Hero: chỉ bay ở chế độ một ô (`HeroMode(enabled: !twoPane)`).
- Hiệu ứng chuyển trang nằm trong ô và bị cắt tại mép ô. Trong hai ô, trang
  bên dưới không chạy hiệu ứng lùi (secondary animation bị tắt).
- Chế độ một ô phải giống hệt Flutter thường, kể cả trong hiệu ứng.

### Hai bài học về vẽ (đã từng gây lỗi)

- Vị trí khung phải chốt xong trong lúc layout. `flushPaint` vẽ nút sâu nhất
  trước, mỗi route có `RepaintBoundary`, nên tính vị trí ở lúc paint là trang
  đã vẽ xong ở chỗ cũ. Cơ chế hiện tại: `_RawPaneArea` layout bố cục ô trước,
  công bố hình chữ nhật, rồi mới layout các Navigator.
- `PaneSlot` phải bọc BÊN NGOÀI hiệu ứng chuyển trang (`buildTransitions`).
  Nếu để hiệu ứng bọc slot, scrim của hiệu ứng Zoom (Linux/Windows) và bóng
  của Cupertino tràn sang ô kia.

### Params

- `params` là `Map<String, Object?>`; nhận `String`, `int`, `double`, `bool`,
  `DateTime`; `null` bị bỏ. Kiểu khác hoặc double không hữu hạn ném
  `ArgumentError` (cả release).
- `DateTime` ghi ra URL theo UTC ISO 8601, đọc lại là UTC.
- Hai route bằng nhau khi cùng `path` và cùng query đã mã hóa (`id: 1` bằng
  `id: '1'`).
- Factory nhận `FoldableParams`: `getX` bắt buộc, `getXOrNull` trả `null` chỉ
  khi thiếu; có mà sai định dạng thì ném, dẫn tới trang not-found. `params['id']`
  vẫn trả chuỗi thô.

### Redirect và context

- Chữ ký: `redirect(BuildContext context, RouteState state)`, theo go_router.
- Context là của widget `Router` (trên Navigator), lấy qua
  `parseRouteInformationWithDependencies`.
- Điều hướng khi router chưa gắn vào cây widget: `StateError`.
- Context unmounted giữa chừng: điều hướng bị bỏ như bị thay thế.
- Redirect đọc InheritedWidget kiểu đăng ký phụ thuộc (`MediaQuery.of`,
  `Theme.of`) thì khi giá trị đổi, Flutter gửi lại URL hiện tại cho delegate.
  URL trùng `currentConfiguration` được xử lý là "kiểm lại ngầm": chạy lại
  redirect của stack như `refresh()`, không dựng lại stack.
- Kiểm lại ngầm không bao giờ thay thế điều hướng đang chờ: nó được hoãn, gộp
  thành một lần, chạy sau khi điều hướng kết thúc. Nó không bật `isNavigating`.
- Hệ quả đã chấp nhận: nền tảng gửi lại đúng URL đang hiển thị cũng chỉ là
  kiểm lại; trang đích có thể lóe lên trước khi một lần kiểm lại ngầm chuyển
  đi; redirect phụ thuộc `MediaQuery` chạy mỗi khung hình khi kéo giãn cửa sổ.

## 5. Giới hạn đã biết và đã chấp nhận

- Phím Tab không đi được vào ô trái.
- Đoán ô theo tiêu điểm có thể gỡ nhầm hai trang (TalkBack, bàn phím); dùng
  `close(context)` cho nút tự viết.
- Khung của ô cần ràng buộc hữu hạn, không đặt dưới phép scale; bọc khung
  trong Opacity/Transform/Clip không ảnh hưởng tới trang.
- Bottom sheet phủ cả hai ô.
- Thay trang ở ô phải vẫn chạy hiệu ứng vào của trang mới phía trên trang cũ.
- Redirect của nhánh shell đang ẩn không được chạy lại khi refresh/kiểm lại.
- `==` giữa hai route ném `ArgumentError` nếu một bên có param kiểu lạ.

## 6. Hiện trạng

- `fvm flutter analyze`: sạch ở package và example.
- `fvm flutter test`: 199 test ở package, 19 ở example, không skip.
- Việc đã xong trong các phiên trước, theo thứ tự: router cơ bản, ShellRoute,
  predictive back, back cho route không page, hai ô, sửa lỗi thứ tự vẽ, sửa
  lớp phủ ô trái, params có kiểu, redirect nhận context, kiểm lại ngầm.

## 7. Việc còn dở

1. **Chờ kết quả thử tay.** Chủ dự án nhận chạy 45 ca trong
   `example/MANUAL_TESTS.md` (6 nhóm A–F) và gửi lại bảng kết quả. Chưa ca nào
   có kết quả. Ca nào FAIL thì tái hiện bằng test tạm rồi viết brief sửa.
2. Chưa ai xác nhận bằng mắt trên máy thật: predictive back của engine thật,
   canh theo bản lề máy gập, thứ tự đọc của TalkBack, hành vi thanh địa chỉ và
   tải lại trên web, Windows (hiệu ứng Zoom, chỉ suy ra từ code).
3. Script `tool/manual_test.sh` mới kiểm cú pháp; các lệnh chạy Android và web
   chưa được chạy thật.
4. Ý còn mở, chưa ai yêu cầu: đổi nội dung ô phải tức thì thay vì có hiệu ứng;
   chạy lại redirect của nhánh ẩn; test riêng cho guard `_silentToken`.

## 8. Bắt đầu một phiên mới

1. Đọc file này, rồi `README.md` nếu cần chi tiết API.
2. Chạy `fvm flutter analyze` và `fvm flutter test` ở package và example để
   chắc hiện trạng ở mục 6 còn đúng. Nếu số test khác, tin kết quả chạy.
3. Hỏi chủ dự án việc tiếp theo, hoặc xử lý bảng kết quả thử tay nếu họ gửi.
