import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

// What the router tells the platform about back ("the framework handles
// back": `SystemNavigator.setFrameworkHandlesBack`).
//
// On Android a `false` followed by a `true` unregisters and registers the
// back callback of the app again, which moves it above the callback of the
// on-screen keyboard: the key that hides the keyboard then pops a page.
// So while a page can be popped, the router must never send `false`, not
// even for one frame.

class HomeRoute extends FoldableRoute {
  const HomeRoute();

  @override
  String get path => '/';

  @override
  Widget build(BuildContext context) => const Text('home');
}

/// Its redirect reads MediaQuery, so the `Router` rebuilds (and hands the
/// Navigator a new `pages` list) whenever the keyboard insets change.
class SizedRoute extends FoldableRoute {
  const SizedRoute();

  @override
  String get path => '/sized';

  @override
  FoldableRoute? get parent => const HomeRoute();

  @override
  FoldableRoute? redirect(BuildContext context, RouteState state) {
    MediaQuery.of(context);
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('sized');
}

class NoteRoute extends FoldableRoute {
  const NoteRoute();

  @override
  String get path => '/note';

  @override
  Widget build(BuildContext context) => const Text('note');
}

void main() {
  final List<bool> sent = <bool>[];

  setUp(() {
    sent.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            sent.add(call.arguments as bool);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<FoldableRouter> pumpRouter(WidgetTester tester) async {
    // WidgetsApp only forwards the value while the app is resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final router = FoldableRouter(
      initial: const HomeRoute(),
      routes: {
        '/sized': (params) => const SizedRoute(),
        '/note': (params) => const NoteRoute(),
      },
      notFoundBuilder: (context, uri) => const Text('not found'),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.routerConfig));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the keyboard opening and closing never reports "cannot pop" '
      'while a page can be popped', (tester) async {
    final router = await pumpRouter(tester);
    addTearDown(tester.view.resetViewInsets);
    unawaited(router.open(const SizedRoute()));
    await tester.pumpAndSettle();
    // The future of a push completes when the page is popped.
    unawaited(router.push<void>(const NoteRoute()));
    await tester.pumpAndSettle();
    expect(router.stack.map((r) => r.uri.toString()), ['/', '/sized', '/note']);
    expect(sent.last, isTrue);

    sent.clear();
    for (final double inset in <double>[100, 200, 300, 200, 100, 0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(router.stack.map((r) => r.uri.toString()), ['/', '/sized', '/note']);
    // The Router did rebuild: something was reported again.
    expect(sent, isNotEmpty);
    expect(sent, everyElement(isTrue));
  });

  testWidgets('pushing above a page that can already be popped never '
      'reports "cannot pop"', (tester) async {
    final router = await pumpRouter(tester);
    unawaited(router.open(const SizedRoute()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(sent.last, isTrue);

    sent.clear();
    // The future of a push completes when the page is popped.
    unawaited(router.push<void>(const NoteRoute()));
    await tester.pumpAndSettle();

    expect(sent, everyElement(isTrue));
  });

  testWidgets('going back to a single page reports "cannot pop"', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    expect(sent.last, isFalse);
    unawaited(router.open(const SizedRoute()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(sent.last, isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(router.stack.map((r) => r.uri.toString()), ['/']);
    expect(sent.last, isFalse);
  });
}
