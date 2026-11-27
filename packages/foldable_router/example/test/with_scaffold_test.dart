import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:foldable_router/foldable_router.dart';

import 'package:foldable_router_example/session.dart';
import 'package:foldable_router_example/pages/home_page.dart';
import 'package:foldable_router_example/pages/users_pages.dart';
import 'package:foldable_router_example/with_scaffold.dart';

const Size _wide = Size(1200, 800);
const Size _narrow = Size(500, 800);

late FoldableRouter router;

/// Redirects of the example wait on timers (`session.restore` 1 s,
/// `session.check` 800 ms): pump the fake clock past them while the
/// navigation is pending, then settle the page transitions.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> openRoute(WidgetTester tester, FoldableRoute route) async {
  final Future<void> future = router.open(route);
  await settle(tester);
  await future;
}

Future<void> pumpApp(WidgetTester tester, {required Size size}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  router = createRouter();
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router.routerConfig,
      builder: (context, child) => SizedBox.fromSize(size: size, child: child!),
    ),
  );
  // The Home branch restore (pendingBuilder) runs on first launch.
  await settle(tester);
}

FoldablePaneLayout paneLayoutOf(WidgetTester tester) =>
    tester.widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout).first);

void main() {
  setUp(session.reset);
  tearDown(session.reset);

  testWidgets('màn rộng: danh sách Users và chi tiết cùng hiện (hai pane)', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: _wide);
    await openRoute(tester, const UsersRoute());

    // Chưa chọn ai: pane phải hiện gợi ý trống.
    expect(paneLayoutOf(tester).secondaryVisible, isTrue);
    expect(find.byKey(const Key('no-user-selected')), findsOneWidget);

    await openRoute(tester, const UserRoute(id: '7'));

    expect(find.text('User 7'), findsWidgets);
    expect(find.text('User 1'), findsOneWidget);
    expect(paneLayoutOf(tester).secondaryVisible, isTrue);
  });

  testWidgets('màn hẹp: chi tiết toàn màn hình, pop quay lại danh sách', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: _narrow);
    await openRoute(tester, const UsersRoute());

    await openRoute(tester, const UserRoute(id: '7'));

    expect(find.text('User 7'), findsWidgets);
    expect(router.stack.last is UserRoute, isTrue);

    // Một pane: chi tiết là trang trên cùng; back (nút hệ thống) pop một trang.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.stack.last is UsersRoute, isTrue);
    expect(find.text('User 1'), findsOneWidget);
  });

  testWidgets('guard Profile: chưa đăng nhập thì chuyển sang Login', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: _wide);

    await openRoute(tester, const ProfileRoute());

    expect(router.stack.last is LoginRoute, isTrue);
    expect(find.text('You need to log in to see /profile'), findsOneWidget);

    // Đăng nhập rồi vào Profile (guard chạy lại, giờ cho vào).
    await tester.tap(find.byKey(const Key('login')));
    await settle(tester);
    expect(router.stack.last is ProfileRoute, isTrue);
    expect(find.text('Only visible when logged in.'), findsOneWidget);
  });

  testWidgets('chuyển chi nhánh giữ stack của chi nhánh cũ', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: _wide);
    await openRoute(tester, const UsersRoute());
    await openRoute(tester, const UserRoute(id: '42'));
    expect(find.text('User 42'), findsWidgets);

    // Sang Profile (guard đưa tới Login) rồi quay lại Users: tab Users
    // không hiển thị nhưng stack của nó vẫn còn.
    await openRoute(tester, const ProfileRoute());
    expect(router.stack.last is LoginRoute, isTrue);

    await router.open(const UsersRoute());
    await tester.pumpAndSettle();
    expect(router.stack.last is UsersRoute, isTrue);
    expect(find.text('User 1'), findsOneWidget);
  });

  testWidgets('push/pop trang toàn màn hình trên shell: ColorPicker', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: _wide);
    await openRoute(tester, const UsersRoute());

    // Nút trên app bar của scaffold: push ColorPickerRoute toàn màn hình.
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    expect(router.stack.last is ColorPickerRoute, isTrue);
    expect(find.text('Pick a colour'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    // Quay lại đúng branch đang mở, trên shell.
    expect(router.stack.last is UsersRoute, isTrue);
    expect(find.text('User 1'), findsOneWidget);
  });

  for (final (name, size, bar) in [
    ('hẹp', _narrow, NavigationBar),
    ('rộng', _wide, NavigationRail),
  ]) {
    testWidgets('màn $name: tab nào cũng có navigation', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, size: size);
      expect(find.byType(bar), findsOneWidget);

      await openRoute(tester, const UsersRoute());
      expect(find.byType(bar), findsOneWidget);

      session.login();
      await openRoute(tester, const SettingsRoute());
      expect(router.stack.last is SettingsRoute, isTrue);
      expect(find.byType(bar), findsOneWidget);
      // Tab Profile luôn một pane: chỉ trang trên cùng hiện.
      expect(paneLayoutOf(tester).primaryVisible, isFalse);
      expect(find.text('Settings (protected by parent)'), findsOneWidget);

      // Chọn tab bằng navigation của scaffold.
      await tester.tap(find.text('Home').last);
      await settle(tester);
      expect(router.stack.last is HomeRoute, isTrue);
      expect(find.byType(bar), findsOneWidget);
    });
  }

  testWidgets('màn hẹp: tab Users chưa chọn ai vẫn hiện danh sách', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: _narrow);
    await openRoute(tester, const UsersRoute());

    expect(find.text('User 1'), findsOneWidget);
    expect(find.byKey(const Key('no-user-selected')), findsNothing);
  });

  testWidgets(
    'kéo cửa sổ hẹp lại rồi rộng ra: navigation luôn hiện, không bị trang đè',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(1280, 720));

      // Kéo dần qua nhiều khung, như khi kéo cửa sổ thật.
      Future<void> resize(double from, double to) async {
        for (var i = 1; i <= 20; i++) {
          tester.view.physicalSize = Size(from + (to - from) * i / 20, 720);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
      }

      void expectNavigationClear(Type navigation, Type page) {
        final Rect nav = tester.getRect(find.byType(navigation));
        final Rect content = tester.getRect(find.byType(page));
        expect(nav.overlaps(content), isFalse, reason: '$page đè $navigation');
      }

      expectNavigationClear(NavigationRail, HomePage);
      await resize(1280, 400);
      expectNavigationClear(NavigationBar, HomePage);
      await resize(400, 1280);
      expectNavigationClear(NavigationRail, HomePage);

      await openRoute(tester, const UserRoute(id: '7'));
      expectNavigationClear(NavigationRail, UsersPage);
      expectNavigationClear(NavigationRail, UserPage);

      // Thu nhỏ khi đang mở User 7: danh sách trượt ra (không bị bóp tới
      // vài pixel), chi tiết chiếm cả vùng, bottom bar ở dưới.
      await resize(1280, 400);
      expectNavigationClear(NavigationBar, UserPage);
      expect(find.byType(UsersPage), findsNothing);
      await resize(400, 1280);
      expectNavigationClear(NavigationRail, UsersPage);
      expectNavigationClear(NavigationRail, UserPage);

      // Navigation bấm được sau tất cả các lần đổi kích thước.
      await tester.tap(find.text('Home').last);
      await settle(tester);
      expect(router.stack.last is HomeRoute, isTrue);
    },
  );

  testWidgets(
    'nút trong trang (dùng chung với main.dart) giữ shell của app này',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(1280, 720));
      expect(find.byType(NavigationRail), findsOneWidget);

      // Nút của HomePage: open(UserRoute(id: '7')).
      await tester.tap(find.text("open(UserRoute(id: '7'))"));
      await settle(tester);
      expect(router.stack.first, const ScaffoldShellRoute());
      expect(router.stack.last, const UserRoute(id: '7'));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // Một dòng của UsersPage: open(UserRoute(id: '42')).
      await tester.tap(find.text('User 42').first);
      await settle(tester);
      expect(router.stack.first, const ScaffoldShellRoute());
      expect(router.stack.last, const UserRoute(id: '42'));
      expect(find.byType(NavigationRail), findsOneWidget);
    },
  );

  for (final (name, size) in [('hẹp', _narrow), ('rộng', _wide)]) {
    testWidgets('màn $name: bàn phím ảo không che ô nhập ở đáy trang', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, size: size);
      await openRoute(tester, const UserRoute(id: '7'));

      final Finder note = find.byKey(const Key('user-note'));
      await tester.tap(note);
      await tester.pump();

      // Bàn phím hiện lên: cửa sổ còn size.height - 300 phía trên nó.
      const double keyboard = 300;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(note).bottom,
        lessThanOrEqualTo(size.height - keyboard),
      );
      // Trang không trừ bàn phím lần nữa: scaffold đã thu vùng pane.
      expect(MediaQuery.viewInsetsOf(tester.element(note)).bottom, 0);
      expect(
        tester.getRect(find.byType(UserPage)).bottom,
        lessThanOrEqualTo(size.height - keyboard),
      );
      if (size == _wide) {
        // Hai pane: danh sách bên trái cũng thu lại, không bị đè.
        expect(
          tester.getRect(find.byType(UsersPage)).bottom,
          lessThanOrEqualTo(size.height - keyboard),
        );
      }

      // Bàn phím ẩn: trang trở lại chiều cao cũ.
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(UserPage)).bottom,
        greaterThan(size.height - keyboard),
      );
    });
  }

  testWidgets(
    'hai pane trên máy gập: bàn phím hiện dần, ô nhập giữ focus và đi lên đều',
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
    (WidgetTester tester) async {
      // Màn trong của một máy gập mở phẳng, đường gập ở giữa.
      const Size size = Size(884, 1104);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      tester.view.displayFeatures = const [
        DisplayFeature(
          bounds: Rect.fromLTRB(442, 0, 442, 1104),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
      ];
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 48);
      addTearDown(tester.view.reset);
      router = createRouter();
      await tester.pumpWidget(WithScaffoldApp(router: router));
      await settle(tester);
      await openRoute(tester, const UserRoute(id: '7'));
      expect(paneLayoutOf(tester).primaryVisible, isTrue);
      expect(paneLayoutOf(tester).secondaryVisible, isTrue);

      final Finder note = find.byKey(const Key('user-note'));
      EditableTextState field() => tester.state<EditableTextState>(
        find.descendant(of: note, matching: find.byType(EditableText)),
      );
      await tester.tapAt(tester.getRect(note).centerLeft + const Offset(20, 0));
      await tester.pump();
      final EditableTextState first = field();
      expect(first.widget.focusNode.hasFocus, isTrue);
      final double top = tester.getRect(note).top;

      // Bàn phím trượt lên qua nhiều khung, như trên máy thật.
      for (var i = 1; i <= 10; i++) {
        tester.view.viewInsets = FakeViewPadding(bottom: 35.0 * i);
        await tester.pump(const Duration(milliseconds: 16));
        // Không dựng lại trang (mất focus làm bàn phím tụt xuống), và ô
        // nhập đi lên đúng bằng phần bàn phím đã chiếm, không giật.
        expect(identical(field(), first), isTrue, reason: 'khung $i');
        expect(first.widget.focusNode.hasFocus, isTrue, reason: 'khung $i');
        expect(tester.getRect(note).top, top - 35.0 * i, reason: 'khung $i');
      }
      await tester.pumpAndSettle();
      expect(first.widget.focusNode.hasFocus, isTrue);
    },
  );
}
