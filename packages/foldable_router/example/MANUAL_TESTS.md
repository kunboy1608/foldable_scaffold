# Ca thử tay cho foldable_router

Đây là những thứ test tự động không chứng minh được: điểm ảnh trên engine
thật, cử chỉ back của Android, thanh địa chỉ của trình duyệt, bàn phím, xoay
máy, trình đọc màn hình.

Chạy app bằng `tool/manual_test.sh <target>` (từ thư mục `example/`). Mỗi nhóm
ghi target cần dùng. Thanh trạng thái ở đáy app luôn hiện `stack` và
`location`, hãy đối chiếu với cột "Mong đợi".

Cách báo lại: với mỗi ca ghi `OK`, `FAIL` (kèm điều bạn thấy) hoặc `SKIP` (không
có thiết bị). Ca nào FAIL mà quay được màn hình thì càng tốt.

---

## Nhóm A: example trên cửa sổ Linux

`tool/manual_test.sh linux`. Vào tab **Users**. Tab này hiển thị hai ô khi cửa
sổ rộng từ 840 trở lên.

| # | Thao tác | Mong đợi | Kết quả |
|---|---|---|---|
| A1 | Cửa sổ rộng, bấm **User 1**. Kéo cửa sổ hẹp lại dưới 840, rồi kéo rộng ra. Lặp lại 3 lần, có lần kéo chậm, có lần kéo nhanh. | Hẹp: chỉ thấy trang User 1. Rộng: danh sách bên trái, User 1 bên phải, lần nào cũng trở lại hai ô. Không có khung hình nào trống, lệch vị trí hay chồng trang. | Ok |
| A2 | Hai ô, đang xem User 1. Bấm lại dòng **User 1** vài lần. | Không có gì thay đổi: không nháy, không chuyển một ô, ô phải không chạy lại hiệu ứng. | Ok |
| A3 | Hai ô, đang xem User 1. Bấm **User 42**. Lặp lại qua lại giữa 1, 7, 42. | Ô phải: User mới hiện lên phía trên User cũ (có hiệu ứng). Ô trái: đứng yên hoàn toàn, không bị phủ mờ, không nhạt đi; chỉ dòng được chọn đổi màu và có gợn sóng chỗ bấm. Không lúc nào thấy chữ "Chọn một người dùng". | Ok |
| A4 | Hai ô, đang xem User 7. Bấm mũi tên back trên thanh tiêu đề của ô phải. | Ô phải về "Chọn một người dùng", ô trái giữ nguyên. `stack` còn `[shell] > /users`. | Ok |
| A5 | Hai ô, đang xem User 7. Bấm **pop()** trong ô phải; mở lại User 7 rồi bấm **open(HomeRoute())**. | pop: như A4. open Home: sang tab Home. Quay lại tab Users thì stack của tab Users vẫn như lúc rời đi. | Ok |
| A6 | Hai ô, đang xem User 7. Kéo cửa sổ thật chậm qua lại quanh mốc 840. | Chuyển một ô ↔ hai ô dứt khoát tại mốc, không rung giật, không lỗi đỏ trên màn hình hay trong terminal. | Ok |
| A7 | Một ô (cửa sổ hẹp). Mở User 1 từ danh sách, rồi back. | Hiệu ứng chuyển trang và avatar bay (Hero) giống app Flutter bình thường. | Ok |

## Nhóm B: example trên Android thật (ưu tiên máy gập hoặc tablet)

`tool/manual_test.sh android`. Bật điều hướng bằng cử chỉ. Cần Android 14 trở
lên để thấy predictive back.

Tác giả thử trên Samsung Galaxy ZFold 8 (F971U)

| # | Thao tác | Mong đợi | Kết quả |
|---|---|---|---|
| B1 | Màn hình hẹp (điện thoại hoặc máy gập đang gập). Tab Users, mở User 1. Vuốt back từ mép, **giữ ngón tay** rồi kéo qua lại, sau đó thả về để hủy. | Trong lúc giữ: thấy trang danh sách lộ ra phía sau, trang User co lại theo ngón tay. Hủy: trở về User 1 nguyên vẹn, `stack` không đổi. | Ok |
| B2 | Như B1 nhưng vuốt hết để xác nhận. | Về danh sách, hiệu ứng liền mạch, không giật ở khung cuối. | Ok |
| B3 | Màn hình rộng (mở máy gập, tablet, hoặc xoay ngang nếu rộng từ 840dp). Mở User 1 (hai ô). Vuốt back, giữ rồi hủy; sau đó vuốt lại và xác nhận. | Chỉ ô phải phản ứng với cử chỉ. Ô trái đứng yên suốt. Xác nhận: ô phải về "Chọn một người dùng". | Ok |
| B4 | Hai ô. Bấm lần lượt User 1, 7, 42. | Trang mới đi vào **từ trong ô phải**, không quét qua ô trái hay đường kẻ chia. Ô trái không bị phủ. | Ok |
| B5 | Máy gập: đang xem User 7 ở hai ô, gập máy lại, rồi mở ra. Lặp lại 3 lần. | Gập: một ô, thấy User 7. Mở: hai ô, vẫn User 7. `stack` không đổi, không có khung hình trống. | Ok |
| B6 | Máy gập, hai ô. Nhìn vị trí đường kẻ chia so với bản lề. | Chỉ cần ghi lại: đường kẻ nằm ở đâu so với bản lề (example chia 2:3, không cố ý canh theo bản lề). | Bên trái bản lề |
| B7 | Đang ở gốc tab Users (không mở user nào). Vuốt back. Rồi thử ở gốc tab Home. | Ghi lại điều xảy ra ở từng chỗ (về tab Home, hay thoát app) và có hiện hiệu ứng "về màn hình chính" của hệ thống không. | Có hiệu ứng về màn hình chính của hệ thống|
| B8 | Bật TalkBack. Tab Users, hai ô, đang xem User 7. Vuốt phải liên tục để duyệt hết màn hình. | Ghi lại thứ tự đọc: ô trái trước hay ô phải trước, có phần tử nào bị đọc hai lần hoặc bị bỏ qua không. | Ban đầu chỉ đọc phần stack và location ở bên dưới. Nếu chọn user hoặc chuyển qua tab user đang có user nào được chọn thì sẽ đọc user đó lên, nếu không có user nào được chọn thì chỉ đọc "ủe thôi" |
| B9 | TalkBack bật, hai ô. Đưa tiêu điểm vào nút back của ô phải, chạm hai lần. | Chỉ ô phải đóng. Nếu cả hai ô cùng đóng thì ghi FAIL (đây là giới hạn đã biết của cách đoán ô theo tiêu điểm). | Tôi không biết test bước này. Tôi chấp nhận bỏ qua cái này |

## Nhóm C: example trên web

`tool/manual_test.sh web`, mở `http://localhost:8080`.

| # | Thao tác | Mong đợi | Kết quả |
|---|---|---|---|
| C1 | Tab Users, bấm User 7. Nhìn thanh địa chỉ. | `/users/detail?id=7`. | Ok |
| C2 | Đang ở C1, bấm nút tải lại của trình duyệt. | App khởi động lại và về đúng User 7 trong tab Users; `stack` là `[shell] > /users > /users/detail?id=7`. | Ok |
| C3 | Đi Home → Users → User 1 → User 42. Bấm Back của trình duyệt nhiều lần, rồi Forward. | Mỗi lần Back/Forward, trang hiển thị và `location` khớp với thanh địa chỉ. Ghi lại nếu có bước nào bị bỏ qua hoặc lặp. | Ok |
| C4 | Gõ `http://localhost:8080/users/detail` (thiếu `id`) rồi Enter. | Trang "Not found" với đúng URL đó. Bấm "Go home" thì về Home. | Ok |
| C5 | Gõ `http://localhost:8080/khong-co`. | Trang "Not found". | Ok |
| C6 | Tab Home, bấm **push<String>(ColorPickerRoute())**. Bấm vào thanh địa chỉ và nhấn Enter mà không sửa gì. | Ghi lại: trang chọn màu còn đó không, `stack` có đổi không. (Nếu trình duyệt tải lại cả trang thì app khởi động lại, đó là bình thường.) |Trang chọn mày còn đó nhưng stack đã thay đổi. Từ "stack: [shell] > / > /pick-color" thành "stack: /pick-color"|
| C7 | Cửa sổ trình duyệt rộng, tab Users, mở User 1. Kéo cửa sổ hẹp lại rồi rộng ra. | Như A1. Thanh địa chỉ không đổi trong lúc kéo. | Ok |



## Nhóm D: lab trên cửa sổ Linux

`tool/manual_test.sh lab-linux`. Đây là một app riêng để thử params có kiểu và
redirect đọc `BuildContext`. Thanh trạng thái có thêm kích thước cửa sổ và
nhật ký các lần redirect chạy.

| # | Thao tác | Mong đợi | Kết quả |
|---|---|---|---|
| D1 | Bấm **open(TypedRoute)**. | Trang liệt kê `count = 42` (int), `ratio = 1.5` (double), `flag = true` (bool), `at = 2026-01-02 03:04:05.000` (DateTime, giờ máy, `isUtc = false`), `note` có dấu tiếng Việt và ký tự `&`. Dòng `uri` chứa đủ 5 tham số, trong đó `at` đã đổi sang UTC và kết thúc bằng `Z`. | Ok |
| D2 | Ở trang Typed, bấm **open with other values**. | `count = -7`, `ratio = 0.30000000000000004`, `flag = false`, `at = 1999-12-31 23:59:59.000Z`, `note = null`, và `uri` không có `note`. | Ok |
| D3 | Về Home. Bấm **open(SlowRoute)**. Trong 4 giây chờ (thanh tiến trình đang chạy), kéo đổi kích thước cửa sổ vài lần. | Hết 4 giây vẫn vào trang Slow. `stack`: `/ > /slow`. Điều hướng KHÔNG bị mất. | Ok |
| D4 | Về Home. Bấm **push(SlowRoute)**, đổi kích thước trong lúc chờ. | Như D3: vào trang Slow, `stack`: `/ > /slow`. | Ok |
| D5 | Đang ở trang Slow (sau D3). Kéo đổi kích thước cửa sổ liên tục vài giây. | Trang Slow giữ nguyên, `stack` không đổi, thanh tiến trình KHÔNG nháy. Nhật ký có thêm các dòng `Slow.redirect started`. Giao diện không khựng rõ rệt. | Ok |
| D6 | Cửa sổ rộng hơn 700. Home → **open(WideOnlyRoute)** → **push(NoteRoute)**. Gõ chữ vào ô, bấm **Counter + 1** vài lần. Kéo đổi kích thước nhưng luôn giữ rộng hơn 700. | `stack`: `/ > /wide > /note` không đổi. Chữ đã gõ và bộ đếm giữ nguyên. Nhật ký thêm dòng `WideOnly.redirect ... allowed`. | Ok |
| D7 | Tiếp D6: kéo cửa sổ hẹp xuống dưới 700. | Tự về Home (`stack`: `/`) mà không cần bấm gì. Nhật ký có dòng `go Home`. | Ok |
| D8 | Cửa sổ hẹp hơn 700. Bấm **open(WideOnlyRoute)**. | Ở lại Home, nhật ký có dòng `go Home`. | Ok |

## Nhóm E: lab trên web

`tool/manual_test.sh lab-web`, mở `http://localhost:8081`.

| # | Gõ vào thanh địa chỉ | Mong đợi | Kết quả |
|---|---|---|---|
| E1 | `/typed?count=5&ratio=2&flag=false&at=2026-03-04T05:06:07Z` | Trang Typed: `count = 5` (int), `ratio = 2.0` hoặc `2` (double), `flag = false`, `at = 2026-03-04 05:06:07.000Z` với `isUtc = true`, `note = null`. | ratio = 2 nhưng là int|
| E2 | `/typed?count=5&ratio=2&flag=false&at=2026-03-04T12:00:00%2B07:00` | `at = 2026-03-04 05:00:00.000Z` (đã đổi về UTC). | Ok |
| E3 | `/typed?count=abc&ratio=2&flag=false&at=2026-03-04` | "Not found". | Ok |
| E4 | `/typed?count=1.5&ratio=2&flag=false&at=2026-03-04` | "Not found" (`count` phải là số nguyên). | Ok |
| E5 | `/typed?count=1&ratio=2&flag=yes&at=2026-03-04` | "Not found" (`flag` chỉ nhận `true`/`false`). | Ok |
| E6 | `/typed?count=1&ratio=2&flag=true` | "Not found" (thiếu `at`). | Ok |
| E7 | `/typed?count=1&ratio=NaN&flag=true&at=2026-03-04` | "Not found". | Ok |
| E8 | Bấm **open(TypedRoute)** ở Home, rồi tải lại trang. | Sau khi tải lại vẫn là trang Typed với `count`, `ratio`, `flag`, `note` như D1 (`note` còn nguyên dấu tiếng Việt và ký tự `&`). Riêng `at` giờ hiện theo UTC, kết thúc bằng `Z`, `isUtc = true`, và là cùng thời điểm với 03:04:05 ngày 2026-01-02 giờ máy bạn. | Ok |
| E9 | Home → **open(SlowRoute)**, trong lúc chờ đổi kích thước cửa sổ trình duyệt. | Như D3. Thanh địa chỉ đổi sang `/slow` khi vào trang. | Ok |

## Nhóm F: lab trên Android thật

`tool/manual_test.sh lab-android`.

| # | Thao tác | Mong đợi | Kết quả |
|---|---|---|---|
| F1 | **open(SlowRoute)**, chờ vào trang Slow. Bấm **push(NoteRoute)**. Chạm vào ô nhập để bàn phím bật lên, gõ vài chữ, ẩn bàn phím, bật lại. | `stack`: `/ > /slow > /note` không đổi. Chữ đã gõ còn nguyên, ô nhập không mất tiêu điểm, thanh tiến trình không nháy. Nhật ký có thêm dòng `Slow.redirect started` mỗi lần bàn phím bật/tắt. | Ok |
| F2 | Tiếp F1: bấm **Counter + 1** vài lần rồi xoay máy ngang, xoay lại dọc. | `stack` không đổi, chữ và bộ đếm giữ nguyên. | Ok|
| F3 | Về Home. Bấm **open(SlowRoute)** và xoay máy ngay trong 4 giây chờ. | Vẫn vào trang Slow. | Ok |
| F4 | Về Home. Bấm **push(SlowRoute)**, trong lúc chờ kéo thanh thông báo xuống rồi đẩy lên, hoặc chuyển sang app khác rồi quay lại. | Vẫn vào trang Slow, `stack`: `/ > /slow`. | Ok |
| F5 | Máy gập: đang ở `/ > /slow > /note` có chữ trong ô, gập/mở máy. | `stack`, chữ và bộ đếm giữ nguyên. | Ok |
| F6 | Ca đối chứng cho F1. Chạy `tool/manual_test.sh plain-android` (app chỉ dùng `Navigator` của Flutter, không có foldable_router). Bấm **Navigator.push(note page)**, chạm vào ô nhập, gõ vài chữ, rồi ẩn bàn phím bằng đúng nút ẩn bàn phím đã dùng ở F1. | Chỉ cần ghi lại: trang Note còn hay bị đóng. Thanh trạng thái hiện `pages on the Navigator` (2 là còn, 1 là đã đóng) và `pops so far`. Trang cũng bị đóng ở đây: việc mất trang ở F1 là do Flutter hoặc bàn phím của máy. Trang còn nguyên: do router. | Ok |

---

## Thiết bị test

Thiết bị và phiên bản hệ điều hành đã dùng:
- Android: Samsung Galaxy ZFold 8 (SM F971U)
- Linux: Ubuntu 26.04 LTS
- Browser: Edge Version 156.0.4314.58 (Official build) (x86_64)
