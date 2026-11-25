# Báo cáo thiết kế: tách foldable_core làm khung dùng chung

*Ngày: 24/11/2026 | Ngôn ngữ báo cáo: Tiếng Việt; tên API, code, dartdoc: Tiếng Anh*  
*Trạng thái: **Không sửa code**, chỉ đọc và đề xuất thiết kế.*  
*Mục tiêu: hai package `foldable_scaffold` và `foldable_router` hoạt động độc lập và cùng nhau, phần chung ở trong `foldable_core`.*

---

## 0. Lời cảnh báo về phạm vi và nguồn

- Đã đọc trực tiếp toàn bộ `lib/` của 3 package (`foldable_core`, `foldable_router`, `foldable_scaffold`), các file test quan trọng, `example/` của router và scaffold, pubspec, README, CHANGELOG, HANDOFF.md, CLAUDE.md.
- **Bỏ qua** `foldable_dev_tools` (hỏng từ trước). **Bỏ qua** lỗi test `foldable_router/example` ("Cycle in the parent chain") — lỗi cũ, không liên quan.
- Các nhận định về transition/page slide trong router dựa trên đọc `router_delegate.dart`, `foldable_panes.dart`, `page_transitions.dart` — **chưa chạy thử trên máy thật** (máy này không compile Swift/iOS). Nơi nào tôi chỉ suy đoán chứ chưa đọc code xác nhận, tôi đánh dấu rõ.
- Con số test trong CLAUDE.md (435 test scaffold, 232 router, 4 core) tôi không đếm lại.

---

## 1. Bảng điểm chung: thực tế hai bên trùng ở đâu

### 1.1. Trùng thật (cùng ngữ nghĩa, hai bên đều cần)

| # | Khái niệm | Nơi ở trong scaffold | Nơi ở trong router | Kết luận |
|---|-----------|----------------------|--------------------|----------|
| A | Danh tính pane (primary / secondary) | Slot `body` / `secondaryBody`; `PaneSlot.primary/divider/secondary` (`foldable_scaffold_layout.dart`) | `enum FoldablePane { single, primary, secondary }` (`foldable_panes.dart`); `FoldablePanes.primary / .secondary` là `PaneFrame` | **Trùng thật, cùng "khe trái / khe phải"**. Router gộp thêm giá trị `single` (chế độ, không phải slot). → vào **core** (enum + scope) |
| B | "Có được chia hai pane không" (chính sách breakpoint) | `FoldableBreakpoints.canSplit(scaffoldWidth, windowSize)` → `frame.canSplit`, publish qua `FoldableScaffoldScope.canSplit` | App tự viết lại trong `buildPanes`: `panes.constraints.maxWidth < 840` (`example/lib/routes.dart`); rồi publish qua `PaneMetrics.twoPane` | **Trùng thật, đang bị nhân đôi chính sách**. Router không có breakpoint riêng. → core: `FoldablePaneLayout.canSplit`, scaffold là nguồn duy nhất |
| C | Trạng thái hiển thị pane hiện tại (visible / split) | `paneLayout.primaryVisible / secondaryVisible` (target) + `PaneGeometry` (animated) + `FoldablePaneLayout` | `PaneMetrics.twoPane` (`ValueNotifier<bool>`) và `_RenderPaneSlot._resolvePane()` (position 0 → secondary khi stack ≥ 2) | **Trùng thật**. Router tính từ stack, scaffold tính từ hình học → phải tách rõ hai nguồn, nếu không sẽ có vòng phản hồi |
| D | Trục của pane (axis) | `Axis axis` (`FoldablePaneLayout.axis`, `PaneGeometry.axis`, `controller.axis`, `isStacked`) | Ngầm định **luôn ngang**: mọi ví dụ là `Row`, `PaneFrame` là left/right, `_resolvePane` chỉ có primary/secondary | **Trùng khái niệm, router chưa dùng đến.** Không đưa "trục" thành API router, nhưng `FoldablePaneLayout.axis` phải ở core để app (ai viết `buildShell`) biết nên `Row` hay `Column` |
| E | Tín hiệu "đang chuyển trang" | `FoldableScaffold.paneTransition` (`ValueListenable<bool>`) hoặc `FoldablePaneTransitionScope` → `_isTransitioning()` (`foldable_scaffold.dart:1885`) → đặt `duration: Duration.zero` (`:1546`) | **Không có tín hiệu công khai.** `isNavigating` là redirect, khác hoàn toàn. Transition nằm kín trong `_EntryPage` | **Trùng nhu cầu, chưa hề nối.** → core giữ scope này, router **phải là provider** |
| F | Hệ số animation | Đọc `FoldableMotion.of(context, paneAnimationDuration)` (`foldable_scaffold.dart:1111`) | Không đọc; duration page transition cố định | **Trùng nhu cầu (slow-mo dev tools), router chưa làm.** → core giữ `FoldableMotion`, router phải đọc |
| G | "Tôi đang ở pane nào" (page đọc) | Không có. Scaffold publish layout ở *trên* cả 2 pane | `PaneScope` (`InheritedNotifier<ValueNotifier<FoldablePane>>`) + `FoldableRouter.paneOf / close` | **Trùng thật** (page cần biết mình ở đâu, bất kể ai dựng nó). → core: `FoldablePaneScope` với `owner` để router vẫn tìm được entry cho `close()` |

### 1.2. Chỉ trùng tên / một bên cần (KHÔNG đưa vào core)

| Tên / khái niệm | Ở đâu | Vì sao không vào core |
|-----------------|-------|----------------------|
| `FoldablePaneLayout` (InheritedWidget của core) vs `FoldablePaneLayoutDelegate` (scaffold) vs `FoldablePanes` (router) | core / scaffold / router | Ba thứ khác nhau, chỉ giống chữ. Nên đổi delegate thành **private** (`_PaneLayoutDelegate`) để hết nhầm |
| `PaneMetrics`, `PaneFrame`, `PaneSlot`, `PaneEpoch`, `_RawPaneArea`, `_RenderPaneSlot`, `_RenderPaneFrame` (~1000 dòng render object) | router | Đây là giải pháp *đo đạc* cho mô hình "page vẽ đè lên khung app tự bố trí". Chỉ router cần. Nên xoá hẳn (xem mục 6.1) |
| `FoldableBreakpoints`, `FrameGeometry`, `PaneGeometry`, `FoldableFold`, `resolveCutouts`, `FoldableNavigationPlacement`, `FoldableVerticalBarScope`, divider/theme/controller | scaffold | Chỉ scaffold cần. Router không nên biết cutout / hinge / insideInset |
| `FoldableScaffoldController` (`secondaryWidth`, `setSecondaryWidth`, `resetDivider`, `isSplit`, `axis`) | scaffold | Cùng dữ liệu với layout nhưng là API điều khiển. Không vào core; app đọc qua `FoldableScaffold.of(context)` |
| `FoldableScaffoldScope` (`bool canSplit`) | core hiện tại | **Xoá**: trùng hoàn toàn với `FoldablePaneLayout.canSplit`; để cả hai thì app phải đọc 2 scope cho 1 câu hỏi |
| `FoldableNavigator` (được nhắc trong doc) | — | Class này **không tồn tại** trong `foldable_router` hiện tại. Doc phải viết lại theo tên thật, tránh dẫn người mới tìm class ma |

---

## 2. API đề xuất của `foldable_core`

Nguyên tắc: core chỉ chứa **ngôn ngữ chung + tín hiệu một chiều**, không chứa layout engine, không chứa render object, không phụ thuộc gì ngoài `flutter`.

### 2.1. `lib/src/foldable_pane.dart` — từ vựng

```dart
/// One of the two slots a two-pane layout gives its content, or the single
/// area a layout without a split gives it.
enum FoldablePane {
  /// The content is not assigned to a slot: it fills the whole pane area (a
  /// one-pane layout, a full-screen page above a shell, a dialog).
  single,

  /// The first slot: the body of a `FoldableScaffold`, the page below the top
  /// one in a two-pane shell tab.
  primary,

  /// The second slot: the secondary body of a `FoldableScaffold`, the top page
  /// of a two-pane shell tab.
  secondary;

  /// Whether this value names one of the two slots of a split layout.
  bool get isSlot => this != FoldablePane.single;
}
```

- Provider: không (thuần từ vựng).
- Consumer: router (`paneOf`, pane host), scaffold (`FoldablePaneScope`), app.
- Không có provider: không áp dụng.

### 2.2. `lib/src/foldable_pane_layout.dart` — shape của pane area

```dart
/// The two-pane layout of the closest `FoldableScaffold`.
///
/// Published by `FoldableScaffold` above its panes; read by the content of the
/// panes (a router that builds them, an app page) to know whether it is being
/// shown in one pane or two, and along which axis.
///
/// The values are the *target* layout: they do not change on every frame of
/// the pane animation. [canSplit] only depends on the geometry (width,
/// breakpoints, fold, insets) and whether the scaffold was given a secondary
/// body, never on what the content does, so reading it can never feed back
/// into the layout.
class FoldablePaneLayout extends InheritedWidget {
  const FoldablePaneLayout({
    required this.canSplit,
    required this.primaryVisible,
    required this.secondaryVisible,
    required this.axis,
    super.key,
    required super.child,
  });

  /// Whether the scaffold has room for two panes whatever the content: the
  /// layout is a split as soon as a secondary body exists.
  final bool canSplit;

  /// Whether the body pane is shown.
  final bool primaryVisible;

  /// Whether the secondary body pane is shown.
  final bool secondaryVisible;

  /// The axis the panes are laid out along once both are visible:
  /// [Axis.horizontal] side by side, [Axis.vertical] stacked around a
  /// horizontal hinge. Meaningless when [isSplit] is false.
  final Axis axis;

  /// Whether the two panes are shown together right now.
  bool get isSplit => primaryVisible && secondaryVisible;

  /// The pane a widget in the body slot is shown in, at target layout.
  FoldablePane get bodyPane => FoldablePane.primary;

  /// The closest layout, subscribing [context] to its changes.
  static FoldablePaneLayout of(BuildContext context);

  /// The closest layout, or null above any `FoldableScaffold`. Never
  /// subscribes, so it is safe in `initState`.
  static FoldablePaneLayout? maybeOf(BuildContext context);

  @override
  bool updateShouldNotify(FoldablePaneLayout oldWidget);
}
```

- **Provider:** `FoldableScaffold` (luôn, một lần quanh cả 2 pane; thay cho `FoldablePaneLayout` + `FoldableScaffoldScope` cũ).
- **Consumer:** router (pane host quyết định single/split), app page, test.
- **Khi không có provider:** `maybeOf` → `null`. Router rơi về hành vi độc lập (single pane, hoặc đường `buildPanes` legacy); page phải tự coi mình ở `FoldablePane.single`.

### 2.3. `lib/src/foldable_pane_scope.dart` — "tôi đang ở slot nào"

```dart
/// The slot the calling widget is drawn in.
///
/// Published by whoever owns the slot: `FoldableScaffold` around the content of
/// each of its panes, `foldable_router` around each page when it draws the
/// pages itself (a shell tab without a `FoldableScaffold`).
class FoldablePaneScope extends InheritedWidget {
  const FoldablePaneScope({
    required this.pane,
    this.owner,
    super.key,
    required super.child,
  });

  /// The slot the subtree is shown in.
  final FoldablePane pane;

  /// Private to the package that published the scope. `foldable_router` puts
  /// the stack entry of the page here, so that `FoldableRouter.close` can find
  /// it; core never reads it and an app should leave it null.
  final Object? owner;

  /// The closest scope, subscribing [context].
  static FoldablePaneScope? maybeOf(BuildContext context);

  /// The closest scope, without subscribing (safe in `initState`, callbacks).
  static FoldablePaneScope? read(BuildContext context);

  /// The pane of the closest scope, or [FoldablePane.single] when there is
  /// none. Subscribes [context].
  static FoldablePane paneOf(BuildContext context);

  @override
  bool updateShouldNotify(FoldablePaneScope oldWidget) =>
      pane != oldWidget.pane || owner != oldWidget.owner;
}
```

- **Provider:** scaffold (mỗi pane một scope, `owner: null`) **và** router (mỗi page, `owner: entry`).
- **Consumer:** page qua `FoldableRouter.paneOf` (router chuyển tiếp sang core) hoặc trực tiếp.
- **Khi không có provider:** `paneOf` → `single`; đó chính là hành vi hôm nay của `FoldableRouter.paneOf` khi không có `PaneScope`.

### 2.4. `lib/src/foldable_pane_transition.dart` — tín hiệu "page đang trượt"

```dart
/// Counts the page transitions in flight, so several overlapping animations do
/// not make the signal flicker to false in between.
///
/// Created by the package that animates the pages (`foldable_router`), which
/// calls [begin] when a page transition starts and [end] when it completes.
class FoldablePaneTransitions extends ChangeNotifier
    implements ValueListenable<bool> {
  int _count = 0;

  /// Whether at least one page transition is running.
  @override
  bool get value => _count > 0;

  /// Marks one transition as started.
  void begin() { _count++; if (_count == 1) notifyListeners(); }

  /// Marks one transition as finished.
  void end() {
    if (_count > 0) {
      _count--;
      if (_count == 0) notifyListeners();
    }
  }
}

/// Whether pages are sliding right now, so `FoldableScaffold` switches the
/// visible pane instantly instead of animating the pane resize on top of the
/// slide.
///
/// Provided by `foldable_router` around the page of a shell (the
/// `FoldableShellRoute.buildShell` subtree), read by `FoldableScaffold`.
/// `FoldableScaffold.paneTransition` overrides it.
class FoldablePaneTransitionScope
    extends InheritedNotifier<ValueListenable<bool>> {
  const FoldablePaneTransitionScope({
    required ValueListenable<bool> transitions,
    super.key,
    required super.child,
  }) : super(notifier: transitions);

  /// The closest transition signal, or null.
  static ValueListenable<bool>? of(BuildContext context);

  /// Whether a transition is running in the closest scope; false when there
  /// is none.
  static bool isTransitioningOf(BuildContext context);

  /// Like [of] without subscribing the caller.
  static ValueListenable<bool>? read(BuildContext context);
}
```

- **Provider:** router (một instance `FoldablePaneTransitions` cho mỗi shell page; scope đặt **trên** trang shell, tức là trên `FoldableScaffold` mà app dựng trong `buildShell`).
- **Consumer:** scaffold (`_isTransitioning`).
- **Khi không có provider:** scaffold dùng `widget.paneTransition` nếu có, ngược lại animate bình thường (hành vi hiện tại). Router không quan tâm.

### 2.5. `lib/src/foldable_motion.dart` — giữ nguyên

`FoldableMotion` (scale duration) đã đúng dạng: provider = app / dev_tools, consumer = scaffold **và router** (router hiện chưa đọc — sửa ở bước 2). Không đổi API, chỉ sửa dartdoc cho đúng sự thật.

### 2.6. Barrel `foldable_core.dart`

```dart
library;
export 'src/foldable_motion.dart' show FoldableMotion;
export 'src/foldable_pane.dart' show FoldablePane;
export 'src/foldable_pane_layout.dart' show FoldablePaneLayout;
export 'src/foldable_pane_scope.dart' show FoldablePaneScope;
export 'src/foldable_pane_transition.dart'
    show FoldablePaneTransitions, FoldablePaneTransitionScope;
```

**Xoá:** `src/foldable_scaffold_scope.dart`.  
**Tổng cộng core: 5 file, ~4 lớp + 1 enum, 0 dependency ngoài flutter.**

### 2.7. Ma trận provider / consumer

| Core item | Provider | Consumer | Độc lập khi không có provider |
|-----------|----------|----------|-------------------------------|
| `FoldablePane` (enum) | — | cả hai | n/a |
| `FoldablePaneLayout` | scaffold (bắt buộc khi có scaffold) | router, page, app | Router: coi như single pane (hoặc đường `buildPanes` legacy). Scaffold: không bị ảnh hưởng |
| `FoldablePaneScope` | scaffold (mỗi pane) + router (mỗi page) | page, `FoldableRouter.paneOf / close` | `paneOf` → `single`; `close()` no-op (đúng hành vi hiện tại) |
| `FoldablePaneTransitions` + `...Scope` | router | scaffold | Scaffold animate như cũ; không crash, chỉ có thể "giật" khi push — chấp nhận được khi app chỉ dùng scaffold |
| `FoldableMotion` | app / dev_tools | scaffold + router | Duration giữ nguyên |

---

## 3. Thay đổi cần có

### 3.1. Router

#### 3.1.1. API mới: `FoldablePaneTree` (router-only, không vào core)

```dart
/// The two pane slots of the current tab, as widgets the app drops into a
/// `FoldableScaffold` (or lays out itself).
///
/// [primary] is the page below the top one of the tab's stack, or the only
/// page; [secondary] is the top page when the stack has two pages or more.
/// Both stay mounted when the other is hidden, so a page keeps its state while
/// it only changes slot.
@immutable
class FoldablePaneTree {
  /// Whether the tab's stack has at least two pages, i.e. whether there is
  /// something to show in [secondary].
  final bool hasSecondary;

  /// The page of the primary slot. Never null.
  final Widget primary;

  /// The page of the secondary slot. Always built (pages stay alive), the app
  /// shows it only when [hasSecondary] is true — `FoldableScaffold` takes
  /// `hasSecondaryBody: panes.hasSecondary`.
  final Widget secondary;

  /// Closes the top page of the tab, so the secondary slot empties:
  /// `router.pop()` for the current branch. Use it for
  /// `FoldableScaffold.onSecondBodyClose`.
  final VoidCallback? closeSecondary;
}
```

và thêm vào shell state:

```dart
class FoldableShellState {
  final Widget child;                                  // giữ nguyên: cả vùng tab
  final int currentIndex;
  final Future<void> Function(int index) goBranch;

  /// The two panes of the current tab, for `FoldableScaffold`.
  final FoldablePaneTree panes;                        // MỚI
}
```

#### 3.1.2. Sửa file cụ thể

| File | Thay đổi |
|------|----------|
| `pubspec.yaml` | thêm `foldable_core: ^0.2.0-dev.1`; bump version thành `0.3.0-dev.1` |
| `lib/src/foldable_panes.dart` | **Xoá** `enum FoldablePane` (dùng của core, re-export); **thay** `PaneScope` bằng `FoldablePaneScope(pane: ..., owner: entry)`; `_resolvePane` trả `FoldablePane` của core |
| `lib/src/foldable_pane_tree.dart` (mới) | `FoldablePaneTree` như trên + widget host nội bộ (`_PaneHost`) đọc `FoldablePaneLayout.maybeOf` |
| `lib/src/foldable_shell_route.dart` | `FoldableShellState.panes`; `buildPanes` → **deprecated / removed** (xem Q1) |
| `lib/src/router_delegate.dart` | (a) dựng `FoldablePaneTree` cho branch hiện tại, gán vào `FoldableShellState`; (b) wrap trang shell bằng `FoldablePaneTransitionScope(transitions: _transitions)`; (c) gọi `_transitions.begin() / end()` trong `_EntryPage` transition lifecycle; (d) mỗi page bọc `FoldablePaneScope(owner: entry)` ở cả chế độ có / không scaffold; (e) nhánh placeholder (`BranchArea`, `_PaneArea`, `PaneSlot`) chỉ còn dùng cho legacy |
| `lib/src/page_transitions.dart` | duration qua `FoldableMotion.of(context, ...)` |
| `lib/foldable_router.dart` | export `FoldablePane` (từ core) + `FoldablePaneTree`; bỏ export `FoldablePanes` nếu xoá `buildPanes` |

Hành vi khi app **chỉ dùng router** (không scaffold): `FoldablePaneTree` vẫn dùng được — app tự `Row([Expanded(primary), VerticalDivider, Expanded(secondary)])` trong `buildShell`, tự `MediaQuery.sizeOf` để quyết định; `FoldablePaneScope` do router publish nên `paneOf` vẫn đúng; `FoldablePaneLayout` vắng mặt → router coi như single (`hasSecondary` vẫn theo stack, app tự quyết có show hay không).

### 3.2. Scaffold

| File | Thay đổi |
|------|----------|
| `pubspec.yaml` | `foldable_core: ^0.2.0-dev.1`, bump version |
| `lib/src/foldable_scaffold.dart` | (a) tại `:1186` thay `FoldableScaffoldScope(canSplit:)` bằng `FoldablePaneLayout(canSplit: frame.canSplit, primaryVisible: paneLayout.primaryVisible, secondaryVisible: paneLayout.secondaryVisible, axis: paneLayout.geometry.axis)`. Vì `primaryVisible / secondaryVisible` được tính trong `_buildPanes` (dưới `LayoutBuilder`), dời scope xuống đúng chỗ đó (ngay trên `_PaneLayoutDelegate` cũ ở `:1710`) và **xoá** scope cũ; `canSplit` lấy từ `frame` nên phải truyền xuống qua `_buildPanesContent` (đã có `frame` trong tham số). (b) bọc `_buildPane(child: _body())` bằng `FoldablePaneScope(pane: FoldablePane.primary)` và tương tự `secondary` — pane bị ẩn vẫn phải có scope để page đọc đúng pane khi nó quay lại. (c) `_isTransitioning` giữ nguyên (đọc scope core). (d) đổi `FoldablePaneLayoutDelegate` → `_PaneLayoutDelegate` (private) để khỏi trùng tên với InheritedWidget mới. |
| `lib/foldable_scaffold.dart` | giữ `export 'package:foldable_core/foldable_core.dart'` (tiện cho app chỉ-dùng-scaffold không phải thêm dependency; không phá ràng buộc vì core là dependency hợp lệ) — hoặc chỉ export đúng 5 tên core để API gọn |
| `lib/src/foldable_scaffold_layout.dart` | chỉ đổi tên delegate (public → private); logic không đổi |
| Test | mọi `find.byType(FoldableScaffoldScope)` → `FoldablePaneLayout`: `foldable_scaffold_test.dart` (~8 chỗ), `foldable_scaffold_horizontal_fold_test.dart` (~6 chỗ); `example/lib/main.dart:580-581` dùng `FoldablePaneLayout.maybeOf(context)?.canSplit` |
| Test mới | `test/foldable_scaffold_pane_scope_test.dart`: pane primary / secondary publish `FoldablePaneScope` đúng, pane ẩn vẫn publish; `test/foldable_scaffold_transition_scope_test.dart`: `FoldablePaneTransitionScope(transitions: FoldablePaneTransitions()..begin())` làm `snapPanes` chạy (không có width trung gian khi đổi pane) |

Scaffold **không** cần biết router: chỉ đọc `FoldablePaneTransitionScope` (đã có), publish `FoldablePaneLayout` + `FoldablePaneScope`, và dùng enum core.

---

## 4. Code mẫu dùng chung (~28 dòng, tầng app)

Không cần "lớp keo" mới: toàn bộ glue nằm trong `buildShell` của app (app phụ thuộc cả hai package — hợp lệ; hai package không biết nhau).

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

class MailShellRoute extends FoldableShellRoute {
  const MailShellRoute();

  @override
  List<FoldableShellChildRoute> get branches =>
      const [InboxRoute(), DraftsRoute(), ProfileRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) {
    final panes = shell.panes;
    return FoldableScaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: panes.primary,                    // page below the top of the stack
      secondaryBody: panes.secondary,         // top page of the stack
      hasSecondaryBody: panes.hasSecondary,   // stack length >= 2
      onSecondBodyClose: (_, __) => panes.closeSecondary(), // back closes the top page
      navigationBuilder: (context, placement, constraints, padding) =>
          placement.isSide
              ? NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: shell.goBranch,
                  labelType: NavigationRailLabelType.all,
                  destinations: [for (final b in branches) railItem(b)],
                )
              : NavigationBar(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: shell.goBranch,
                  destinations: [for (final b in branches) barItem(b)],
                ),
    );
  }
}
```

Điều gì xảy ra với đoạn này (không cần dòng nào thêm):

- `FoldableScaffold` tự quyết split theo `FoldableBreakpoints` + fold + iPhone Duo strip; divider kéo được; pane secondary hiển thị top page.
- Push `UserRoute` trong branch → `panes.hasSecondary` true → scaffold mở secondary; transition của router bật `FoldablePaneTransitions` → scaffold **snap** (không resize pane trong lúc trượt).
- Back (system / gesture) → `canPop: !hasSecondaryBody` đang false → `closeSecondary()` → `router.pop()`.
- Pane nào chật cũng không sao: pane ẩn vẫn sống, giữ state stack / scroll / text nhập.
- Chỉ dùng router: bỏ `FoldableScaffold`, `buildShell` trả `Row` / `Column` với `panes.primary / secondary` (không cần core). Chỉ dùng scaffold: code cũ không đổi ngoài tên scope.

---

## 5. Rủi ro và cách xử lý

### 5.1. Hai nguồn chân lý về "khi nào 2 pane" (rủi ro cao nhất)

Hiện app phải tự so `panes.constraints.maxWidth < 840`; scaffold có `FoldableBreakpoints`. Nếu sau này cả hai đều quyết, chúng sẽ lệch nhau (scaffold split, router vẫn 1 page; hoặc ngược lại).

**Xử lý:** Luật cứng: `FoldablePaneLayout.canSplit` là **nguồn duy nhất**; router / host chỉ *đọc*, không có breakpoint riêng.  
**Test:** đổi `FoldableBreakpoints(split: 840)` ở scaffold và khẳng định router theo đúng, không cần sửa app.

### 5.2. Vòng phản hồi layout

Chuỗi nguy hiểm: `canSplit` (hình học) → router show / hide secondary → app truyền `hasSecondaryBody` → `secondaryVisible` → `canSplit`…

**Xử lý:** `canSplit` chỉ phụ thuộc hình học (width / window / breakpoints / fold / insets) **và** "có widget secondaryBody" — không phụ thuộc router. `hasSecondaryBody` lấy từ `stack.length >= 2` (dữ liệu stack), không lấy từ layout.  
**Test:** viết test "builds at most N lần cho một lần đổi pose" (đếm build bằng một `StatefulWidget` wrapper) để bắt vòng lặp.

### 5.3. Khung placeholder của router đo bằng layout vs pane của scaffold animate

Pane của scaffold chạy `TweenAnimationBuilder<PaneGeometry>` (250ms, `fastOutSlowIn`), mỗi frame width pane đổi → nếu router vẫn dùng `PaneFrame` / `_RawPaneArea` (đo rect mỗi lần subtree layout, có cơ chế "mark slots cần layout"), page sẽ chạy theo pane đang animate, cộng thêm transition của page → đúng kiểu giật mục tiêu muốn tránh. Cơ chế `paneTransition` chỉ cứu phần *đổi pane đơn*, không cứu phần *resize khi xoay / gập*.

**Xử lý:** **Không dùng measurement khi có scaffold.** Pane host = widget con thật trong slot, layout do scaffold quyết, page tự nhiên co giãn. Chỉ giữ `PaneFrame` cho app không dùng scaffold (legacy) hoặc xoá hẳn.

### 5.4. Ai sở hữu vị trí divider (state)

Divider là state của scaffold (`_ratioSecondaryBody`, restore qua `restorationId`); router không được ghi vào. Nhưng app có thể muốn tỉ lệ list / detail mặc định (1:2) → dùng `FoldableScaffoldController.setSecondaryWidth` trong `addPostFrameCallback` hoặc thêm tham số `initialSecondaryRatio`. Đừng để router điều khiển divider.

### 5.5. Hero và page transition bị cắt trong pane

Hôm nay `PanePageView` tắt Hero khi 2 pane (`HeroMode(enabled: !twoPane)`), và `PaneSlot(clip: true)` để transition không tràn pane. Với host model: scaffold đã có `ClipRect` quanh cả vùng pane, nên clip tự có; nhưng Hero **vẫn phải tắt trong split** (page dưới vẫn hiện → bay Hero sẽ nhân đôi), và phải bật lại ở single. Nơi quyết định: router host, đọc `FoldablePaneLayout.isSplit`.

### 5.6. Cupertino / full-screen transition giả định toàn màn hình

Page trượt trong pane hẹp: nếu transition dùng `CupertinoPageTransition` (parallax theo chiều ngang toàn màn hình) nhìn sẽ sai. Đề xuất: trong split, dùng fade / shared-axis nhẹ ("minor" transition) thay cho slide toàn màn hình; chỉ dùng slide khi single pane. Đây là thay đổi hành vi, cần PM duyệt.

### 5.7. `FoldablePaneScope.owner` là "lỗ" type-safety trong core

Đặt `Object?` để không phải import router type. Rủi ro: app tự set bừa. Giảm nhẹ: `@internal` trên field + assert khi `owner != null` thì do router publish (không kiểm được) → chấp nhận, ghi rõ trong dartdoc.  
**Khuyến nghị thay thế:** định nghĩa `abstract interface class FoldablePaneOwner {}` trong core, router implement — sạch hơn, tôi khuyến nghị cách này nếu không ngại thêm 1 interface.

### 5.8. Nhiều `FoldablePaneLayout` lồng nhau

Page trong pane có thể chứa một `FoldableScaffold` khác (vd. mail list-detail lồng trong shell). Host của router đọc "nearest" — nếu host nằm trong slot thì nearest là scaffold ngoài (an toàn), nhưng nếu sau này ai bọc shell bằng scaffold phụ thì lệch.  
**Giảm nhẹ:** test 2 scaffold lồng nhau; doc "chỉ scaffold ngoài cùng được dùng với shell".

### 5.9. Xoá `buildPanes` là breaking lớn

Toàn bộ `PaneFrame` / `PaneMetrics` / `_PaneArea` / `PaneSlot` / `PaneEpoch` (~1000 dòng + 6 file test: `pane_layout_test`, `pane_pixels_test`, `two_pane_test`, `shell_route_test`, …) bị đụng. Nếu chọn giữ legacy, chi phí gấp đôi (2 mô hình phải chạy đúng, 2 bộ test).

### 5.10. Scaffold re-export core

`foldable_scaffold.dart` đang `export package:foldable_core/...`. Giữ để app chỉ-dùng-scaffold không phải thêm dependency, nhưng khi kết hợp, app import cả hai thì có thể có xung đột tên nếu router export trùng (router sẽ export `FoldablePane` từ core — không xung đột vì cùng declaration). An toàn.

### 5.11. `FoldableNavigator` trong doc cũ

Dartdoc của core và scaffold README nhắc `FoldableNavigator` — class này **không tồn tại** trong `foldable_router` hiện tại (chỉ có `FoldableShellRoute` / nhiều `Navigator` nội bộ). Toàn bộ doc phải viết lại theo tên thật, tránh người mới đi tìm class ma.

---

## 6. Câu hỏi cần bạn / PM quyết (kèm khuyến nghị)

| # | Câu hỏi | Phương án | Khuyến nghị |
|---|---------|-----------|--------------|
| Q1 | Giữ `FoldableShellRoute.buildPanes` (page vẽ đè lên khung đo được) hay thay bằng `FoldableShellState.panes` (host widget thật)? | (a) Thay hẳn, xoá ~1000 dòng render object + 6 test; (b) giữ cả hai, `buildPanes` = legacy; (c) giữ `buildPanes`, chỉ thêm host | **(a)** — đơn giản hơn, mới có divider / hinge / iPhone Duo thật, hết rủi ro 5.3; pre-release nên phá vỡ được. (b) chỉ khi đã có app thật dùng `buildPanes` |
| Q2 | Ai quyết "2 pane"? | (a) chỉ scaffold (`FoldablePaneLayout.canSplit`); (b) router có `splitWidth` riêng; (c) app tự quyết | **(a)**. (c) chỉ là đường dự phòng khi không có scaffold |
| Q3 | Khi single pane + stack ≥ 2, hiện gì? | (a) top page (secondary) thay chỗ body — hành vi scaffold hiện tại; (b) giữ body và coi stack là "chi tiết" ẩn | **(a)**, đúng mô hình list→detail của Apple; giữ `focusOnPrimaryBody` cho app muốn (b) |
| Q4 | Tỉ lệ divider mặc định trong shell (list / detail)? | (a) 1:1 như hiện tại; (b) app set qua controller; (c) thêm `initialSecondaryRatio` | **(c)** + cho `controller` override; đừng để router can thiệp |
| Q5 | Transition khi split: slide toàn pane hay fade / minor? | (a) slide trong pane (clip); (b) fade / shared-axis khi split, slide khi single | **(b)** — (a) trông nặng và dễ lộ biên pane hẹp; cần bạn xác nhận vì đổi cảm giác UX |
| Q6 | Router có đọc `FoldableMotion` (slow-mo) cho page transition? | (a) có; (b) không | **(a)** — dev_tools đã provide, không đọc thì slow-mo nửa vời |
| Q7 | Core có thêm `FoldablePaneOwner` interface (thay `Object? owner`)? | (a) có; (b) `Object?` | **(a)** nếu bạn không ngại thêm type; ngược lại (b) với `@internal` |
| Q8 | Router có nên cung cấp sẵn widget `FoldableShellNavigation` (rail / bar từ `branches`) để app khỏi viết `navigationBuilder`? | (a) có, sau này; (b) app tự viết | **(b)** trước mắt (đúng triết lý "shell chỉ là frame"), (a) như tiện ích ở 0.4 |

---

## 7. Kế hoạch triển khai (theo thứ tự, mỗi bước tự xanh)

### Bước 1 — core (không ai bị ảnh hưởng ngoài scaffold, vì router chưa dùng)

**Sửa:** `foldable_core/pubspec.yaml` (0.2.0-dev.1), `lib/foldable_core.dart`, `src/foldable_pane_layout.dart`, `src/foldable_pane_transition.dart`, `src/foldable_motion.dart` (doc), `README.md`, `CHANGELOG.md`.  
**Thêm:** `src/foldable_pane.dart`, `src/foldable_pane_scope.dart`.  
**Xoá:** `src/foldable_scaffold_scope.dart`.  
**Test:** `test/foldable_core_test.dart` (viết lại), `foldable_pane_layout_test.dart`, `foldable_pane_scope_test.dart`, `foldable_pane_transition_test.dart` (ref-count của `FoldablePaneTransitions`, không flicker, `updateShouldNotify`).  
**Cổng:** `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos`, `flutter test`, `dart doc --dry-run` (0 warning).

### Bước 2 — scaffold theo core mới (làm trước router để có provider thật)

**Sửa:** `lib/src/foldable_scaffold.dart` (publish layout + scope mỗi pane, đổi tên delegate), `lib/foldable_scaffold.dart` (export), mọi test dùng `FoldableScaffoldScope`, `example/lib/main.dart`.  
**Test mới:** `test/foldable_scaffold_pane_scope_test.dart`, `test/foldable_scaffold_transition_scope_test.dart`, cập nhật `foldable_scaffold_horizontal_fold_test.dart` (assert `FoldablePaneLayout.axis == vertical`), `foldable_scaffold_layout_axis_test.dart`.  
**Cổng:** như bước 1 (+ `example/test/fold_demo_test.dart`).

### Bước 3 — router: core + pane host

**Sửa:** `pubspec.yaml` (+core, 0.3.0-dev.1), `lib/src/foldable_panes.dart` (bỏ enum, `FoldablePaneScope`), `lib/src/foldable_shell_route.dart` (`panes`), `lib/src/router_delegate.dart` (host, scope, transition counter, `FoldableMotion`), `lib/src/page_transitions.dart`, `lib/foldable_router.dart`.  
**Thêm:** `lib/src/foldable_pane_tree.dart`.  
**Test:** viết lại `test/two_pane_test.dart`, `test/pane_layout_test.dart`; xoá `test/pane_pixels_test.dart` nếu bỏ đo đạc; thêm `test/pane_tree_test.dart` (primary = stack[1], secondary = stack[0], `closeSecondary` pop đúng branch, page giữ state khi đổi slot), `test/transition_signal_test.dart` (begin / end, chồng nhau không nhấp nháy), `test/pane_of_test.dart` (đọc scope core, fallback `single`).  
**Cổng:** `flutter test` router; chấp nhận `example/test/app_test.dart` vẫn fail "Cycle in the parent chain" (lỗi cũ).

### Bước 4 — tích hợp + ví dụ

Thêm `packages/foldable_router/example/lib/with_scaffold.dart` (entrypoint thứ hai, example được phép phụ thuộc `foldable_scaffold`) + `pubspec.yaml` của example.  
**Test tích hợp:** `example/test/with_scaffold_test.dart` — (1) hẹp → 1 pane; (2) rộng → split, divider tồn tại; (3) push → secondary có top page, transition không resize pane (assert width không trung gian); (4) back → `hasSecondary` false; (5) iPhone Duo inner landscape (`FakeViewPadding` + `displayFeatures` + `FoldableVerticalBarScope`) → rail trong dải 84; (6) đổi pose khi đang transition không nhảy; (7) kéo divider trong split → page co theo, không giật; (8) đếm build ≤ 2 mỗi lần đổi pose (chống vòng lặp 5.2); (9) Hero tắt khi split.  
**Cập nhật:** `docs/HANDOFF.md` (router), `CLAUDE.md` (scaffold), 3 `README.md`, 3 `CHANGELOG.md`.

### Bước 5 — dọn dẹp / verify

- `melos bootstrap` + chạy toàn bộ: scaffold 435 → sẽ tăng; core ~4 → ~15; router 232 → thay đổi lớn (ghi lại con số thật).
- Rà `dart doc --dry-run` cho cả 3 (dartdoc đang nhắc `FoldableNavigator` không tồn tại — phải hết).

---

## Kết luận một câu

Core chỉ cần **enum `FoldablePane` + 3 inherited widget (`FoldablePaneLayout`, `FoldablePaneScope`, `FoldablePaneTransitionScope` kèm `FoldablePaneTransitions`) + `FoldableMotion`**; scaffold là provider của layout / scope, router là provider của transition / scope-page; phần "đo khung" hiện tại của router nên bị thay bằng **pane host widget** để scaffold tự bố trí — đó là điều kiện để hai package dùng chung mà không giật và vẫn chạy độc lập.
