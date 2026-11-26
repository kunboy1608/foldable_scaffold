# Checklist thử tay trên thiết bị cho `foldable_router`

Checklist này dành cho những thứ test tự động không chứng minh được: tư thế
gập thật, điểm ảnh thật, dải hệ thống và phần bị cắt (cutout), cử chỉ vật lý,
thanh địa chỉ trình duyệt, thời điểm xoay máy và dữ liệu nền tảng.

Chạy entrypoint của scaffold bằng `flutter run lib/with_scaffold.dart`, và app
router thường bằng entrypoint example quen thuộc. Ghi kết quả mỗi ca là
`PASS`, `FAIL` hoặc `SKIP`.

Với mỗi ca thất bại, ghi lại:

- Mẫu thiết bị, phiên bản OS, entrypoint của app và chế độ build.
- Pose (inner landscape, inner portrait, half-open dọc, half-open ngang, màn
  hình ngoài bên trái/phải camera, gập, tablet, cửa sổ desktop), kèm kích thước
  cửa sổ và hướng.
- Các bước chính xác, điều bạn thấy, `stack` và `location` app đang hiển thị.
- Số đo rect primary/secondary, vị trí divider và inset hệ thống.
- Ảnh chụp màn hình hoặc video quay màn hình.
- Trong scaffold example, mở dialog **Platform data** và bấm **Copy**, rồi đính
  kèm nội dung đã copy (nội dung này chứa số đo pose/inset gốc).

## iPhone Duo

Thử mọi mục ở inner landscape, inner portrait, half-open dọc, half-open ngang,
và trên màn hình ngoài ở cả hai phía camera. Xoay máy trong lúc app đang chạy ở
những bước có yêu cầu.

- [ ] **Hình học, rail và dải hệ thống.** Mở Users rồi mở một trang chi tiết. Ở
  mọi pose, xác nhận khi nào một pane khi nào hai pane, và navigation rail nằm
  trong dải hệ thống 84 point của iPhone Duo, không đè lên nội dung trang. Nếu
  sai, ghi rect, divider, inset, pose và nội dung Platform data.
- [ ] **Xoay máy.** Xoay từ inner portrait sang landscape và ngược lại trong lúc
  đang push, rồi chuyển giữa màn hình trong và từng màn hình ngoài. Stack và
  location giữ nguyên; không có ô trống, chồng trang hay nháy. Ghi lại từng lần
  đổi pose bằng ảnh chụp.
- [ ] **Push/pop khi đang kéo divider.** Ở chế độ hai pane, kéo divider và không
  nhấc tay, push rồi pop vài trang, sau đó đổi tab giữa lúc push. Mong đợi:
  animation của pane không giật lại từ đầu, tab được chọn đúng với cái đã bấm, và
  không crash. Quay video kèm mốc thời gian và stack sau mỗi thao tác.
- [ ] **Rời shell giữa lúc transition.** Bắt đầu một lần push rồi mở ngay một
  route ngoài shell (lặp lại trong lúc xoay máy). Mong đợi: shell được retire
  không có exception hay màn hình đỏ. Ghi log và Platform data.
- [ ] **State và Hero.** Nhập text vào một field và cuộn một danh sách, chuyển
  trang sang slot còn lại, đổi tab rồi quay lại. Text và vị trí cuộn phải còn
  nguyên. Ở chế độ split, Hero phải bị tắt; ở một pane, Hero bay bình thường. Ghi
  slot của trang, rect và ảnh chụp.
- [ ] **Back và predictive back.** Khi một tab đang hiển thị, thử nút back trên
  toolbar, back hệ thống và vuốt back, giữ rồi hủy giữa chừng. Tab ẩn không được
  bị pop; hủy thì không đổi gì; hoàn tất thì chỉ pop trang trên cùng đang hiển
  thị. Ghi loại cử chỉ, pose, stack và video.

## Android gập và tablet

- [ ] **Gập và mở.** Chạy trên một máy gập và một tablet ở portrait và landscape.
  Khi gập/hẹp hiển thị một pane; khi mở/rộng chỉ hiển thị hai pane khi cả hai
  hình chữ nhật đều có diện tích. Ghi kích thước cửa sổ, rect, divider, pose và
  Platform data.
- [ ] **Tư thế half-open.** Giữ half-open dọc và ngang, rồi đổi posture khi một
  trang đang hiển thị. Các trang vẫn ở đúng slot, không chồng lên nhau và không
  có khung hình trống. Ghi posture, biên của hinge và rect.
- [ ] **Thử nghiệm điều hướng.** Trong lúc resize hoặc kéo divider, push/pop liên
  tục và đổi tab giữa lúc push. Animation giữ liên tục. Rời shell giữa lúc
  transition và xác nhận không crash. Ghi video, log và stack.
- [ ] **Back và state.** Thử back hệ thống và predictive back, kể cả khi có một
  tab ẩn (tab ẩn không được bị pop). Sau khi nhập text và cuộn, đổi slot và đổi
  tab; state phải còn nguyên. Xác nhận Hero tắt khi split và bật khi một pane. Ghi
  offset, pose và ảnh chụp.

## Web/desktop kéo cửa sổ

- [ ] **Vượt ngưỡng breakpoint.** Kéo cửa sổ chậm và nhanh qua ngưỡng một
  pane/hai pane, kể cả trong lúc push hoặc pop. Layout chỉ đổi chế độ một lần,
  không có rect cũ, không chồng trang, không giật lại animation. Ghi kích thước
  cửa sổ/CSS, rect và video quay màn hình.
- [ ] **Thử nghiệm tab và shell.** Push, pop và đổi tab liên tục trong lúc kéo,
  rồi rời shell giữa lúc transition. URL, stack, tab được chọn và state của
  trang giữ nhất quán, không có lỗi console. Ghi browser/OS, URL, output console
  và ảnh chụp.
- [ ] **Back và Hero.** Thử Back/Forward của trình duyệt và back bằng
  bàn phím/toolbar. Tab ẩn không bị pop. Hero bay khi một pane và bị tắt khi
  split. Ghi URL, kích thước cửa sổ và ảnh chụp.

## Những gì test tự động chưa phủ

Test tự động không thể xác lập điểm ảnh và cử chỉ đặc thù theo engine trên máy
gập thật, tư thế gập/che khuất, dải hệ thống và cutout của iPhone Duo, thời điểm
xoay máy, hành vi predictive back vật lý, thanh địa chỉ trình duyệt và thay đổi
viewport CSS, hành vi bàn phím/IME thật, thứ tự focus trợ năng, hiện tượng ì
(thermal/performance jank), hay dữ liệu kênh nền tảng. Hãy coi đây là rủi ro
thủ công kể cả khi mọi cổng tự động đều đạt.
