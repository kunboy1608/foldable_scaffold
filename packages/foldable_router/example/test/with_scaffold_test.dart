import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:foldable_router/foldable_router.dart';

import 'package:foldable_router_example/session.dart';
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
}
