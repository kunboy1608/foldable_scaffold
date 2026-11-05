import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

FoldablePage<void> _page(
  String name, {
  FoldablePageTransition? transition,
  bool canPop = true,
}) {
  return FoldablePage<void>(
    name: '/$name',
    transition: transition,
    canPop: canPop,
    child: Center(child: Text(name)),
  );
}

enum _Kind { stack, split }

/// A navigator of [kind]. The split navigator sits in a one-pane layout, like
/// a phone, unless [canSplit] says there is room for two panes.
Widget _navigator(
  _Kind kind,
  FoldableNavigatorController controller, {
  Duration duration = const Duration(milliseconds: 300),
  bool canSplit = false,
}) {
  if (kind == _Kind.stack) {
    return FoldableNavigator.stack(
      controller: controller,
      transitionDuration: duration,
    );
  }
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final hasSecondary = controller.pages.length > 1;
      return FoldableScaffoldScope(
        canSplit: canSplit,
        child: FoldablePaneLayout(
          primaryVisible: canSplit || !hasSecondary,
          secondaryVisible: canSplit || hasSecondary,
          child: FoldableNavigator(
            controller: controller,
            transitionDuration: duration,
            builder: (context, body, secondary) => Column(
              children: [
                Expanded(child: body),
                if (secondary != null) Expanded(child: secondary),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _app(
  _Kind kind,
  FoldableNavigatorController controller, {
  Duration duration = const Duration(milliseconds: 300),
  bool canSplit = false,
}) {
  return MaterialApp(
    home: _navigator(kind, controller, duration: duration, canSplit: canSplit),
  );
}

/// Sends a message of the Android back gesture channel to the app and returns
/// the answer of `startBackGesture`: whether any observer claimed the gesture.
Future<bool?> _send(
  WidgetTester tester,
  String method, [
  Map<String, Object?>? arguments,
]) async {
  bool? answer;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (data) {
      if (data == null) return;
      final result = const StandardMethodCodec().decodeEnvelope(data);
      if (result is bool) answer = result;
    },
  );
  return answer;
}

Map<String, Object?> _event(
  double progress, {
  int edge = 0,
  List<double>? touch = const [5, 300],
}) => {'touchOffset': touch, 'progress': progress, 'swipeEdge': edge};

Future<bool?> _start(
  WidgetTester tester, {
  double progress = 0,
  int edge = 0,
  List<double>? touch = const [5, 300],
}) => _send(
  tester,
  'startBackGesture',
  _event(progress, edge: edge, touch: touch),
);

Future<void> _update(WidgetTester tester, double progress) async {
  await _send(tester, 'updateBackGestureProgress', _event(progress));
  await tester.pump();
}

Future<void> _commit(WidgetTester tester) async {
  await _send(tester, 'commitBackGesture');
  await tester.pump();
}

Future<void> _cancel(WidgetTester tester) async {
  await _send(tester, 'cancelBackGesture');
  await tester.pump();
}

/// The slide of the closest [SlideTransition] around the page called [name].
Offset _slideOf(WidgetTester tester, String name) {
  final slide = tester.widget<SlideTransition>(
    find
        .ancestor(
          of: find.text(name, skipOffstage: false),
          matching: find.byType(SlideTransition, skipOffstage: false),
        )
        .first,
  );
  return slide.position.value;
}

bool _transitioning(WidgetTester tester, String name) =>
    FoldableNavigator.isTransitioning(tester.element(find.text(name)));

FoldableNavigatorController _threePages() =>
    FoldableNavigatorController.single([_page('a'), _page('b'), _page('c')]);

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  for (final kind in _Kind.values) {
    group('${kind.name} navigator', () {
      testWidgets('the page follows the progress of the gesture', (
        tester,
      ) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await _start(tester), isTrue);
        await tester.pump();
        expect(_transitioning(tester, 'c'), isTrue);
        expect(_slideOf(tester, 'c'), Offset.zero);

        await _update(tester, 0.3);
        expect(_slideOf(tester, 'c').dx, closeTo(0.3, 1e-9));
        // The page below comes back with it.
        expect(_slideOf(tester, 'b').dx, closeTo(-0.7 / 3, 1e-9));

        await _update(tester, 0.6);
        expect(_slideOf(tester, 'c').dx, closeTo(0.6, 1e-9));

        // Nothing was popped while the finger is down.
        expect(controller.pages, hasLength(3));
        await _cancel(tester);
        await tester.pumpAndSettle();
      }, variant: android);

      testWidgets('commit pops exactly one page and finishes the slide', (
        tester,
      ) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await _start(tester), isTrue);
        await _update(tester, 0.4);
        await _commit(tester);

        expect(controller.pages, hasLength(2));
        // The slide runs on from where the finger left it.
        expect(_transitioning(tester, 'c'), isTrue);
        expect(_slideOf(tester, 'c').dx, closeTo(0.4, 0.2));

        await tester.pumpAndSettle();
        expect(controller.pages, hasLength(2));
        expect(find.text('b'), findsOneWidget);
        expect(find.text('c', skipOffstage: false), findsNothing);
        expect(_slideOf(tester, 'b'), Offset.zero);

        // The next gesture works again.
        expect(await _start(tester), isTrue);
        await _commit(tester);
        await tester.pumpAndSettle();
        expect(controller.pages, hasLength(1));
        expect(find.text('a'), findsOneWidget);
      }, variant: android);

      testWidgets('cancel puts the page back and pops nothing', (tester) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await _start(tester), isTrue);
        await _update(tester, 0.5);
        await _cancel(tester);
        // The system keeps reporting progress while it animates back.
        await _update(tester, 0.2);
        expect(_slideOf(tester, 'c').dx, closeTo(0.5, 0.2));
        await tester.pumpAndSettle();

        expect(controller.pages, hasLength(3));
        expect(_slideOf(tester, 'c'), Offset.zero);
        expect(_transitioning(tester, 'c'), isFalse);
        expect(find.text('c'), findsOneWidget);

        // A commit that arrives after the cancel does nothing.
        await _commit(tester);
        await tester.pumpAndSettle();
        expect(controller.pages, hasLength(3));
      }, variant: android);

      testWidgets('a fade page falls back to the instant system back', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([
          _page('a'),
          _page('b', transition: FoldablePageTransition.fade),
        ]);
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await _start(tester), isFalse);
        await _update(tester, 0.5);
        expect(_transitioning(tester, 'b'), isFalse);
        expect(controller.pages, hasLength(2));

        await _commit(tester);
        await tester.pumpAndSettle();
        expect(controller.pages, hasLength(1));
        expect(find.text('a'), findsOneWidget);
      }, variant: android);

      testWidgets('handlePopRoute still pops one page', (tester) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        expect(controller.pages, hasLength(2));
        expect(find.text('b'), findsOneWidget);
      }, variant: android);

      testWidgets('a button press is not a gesture', (tester) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        // The system sends no touch point for the back button.
        expect(await _start(tester, touch: null), isFalse);
        await _commit(tester);
        await tester.pumpAndSettle();

        expect(controller.pages, hasLength(2));
      }, variant: android);

      testWidgets('a gesture from the right edge is not followed', (
        tester,
      ) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await _start(tester, edge: 1, touch: [795, 300]), isFalse);
        await _commit(tester);
        await tester.pumpAndSettle();

        expect(controller.pages, hasLength(2));
      }, variant: android);

      testWidgets('a single page is left to the enclosing route', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([_page('a')]);
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await _start(tester), isFalse);
        expect(_transitioning(tester, 'a'), isFalse);
      }, variant: android);

      testWidgets('a page that cannot pop is not followed', (tester) async {
        final controller = FoldableNavigatorController.single([
          _page('a'),
          _page('b', canPop: false),
        ]);
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await _start(tester), isFalse);
        await _commit(tester);
        await tester.pumpAndSettle();
        expect(controller.pages, hasLength(2));
      }, variant: android);

      testWidgets('no slide, no gesture', (tester) async {
        final controller = _threePages();
        await tester.pumpWidget(
          _app(kind, controller, duration: Duration.zero),
        );
        await tester.pumpAndSettle();

        expect(await _start(tester), isFalse);
        await _commit(tester);
        await tester.pumpAndSettle();
        expect(controller.pages, hasLength(2));
      }, variant: android);

      testWidgets('a swipe from the edge in progress keeps the gesture', (
        tester,
      ) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        final swipe = await tester.startGesture(const Offset(8, 300));
        await swipe.moveBy(const Offset(40, 0));
        await tester.pump();
        await swipe.moveBy(const Offset(100, 0));
        await tester.pump();
        expect(_transitioning(tester, 'c'), isTrue);

        expect(await _start(tester), isFalse);

        await swipe.up();
        await tester.pumpAndSettle();
        // Short of half the width: the swipe snapped back.
        expect(controller.pages, hasLength(3));
      }, variant: android);

      testWidgets('a dialog on top gets the back first', (tester) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        final context = tester.element(find.text('c'));
        unawaited(
          showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(content: Text('dialog')),
          ),
        );
        await tester.pumpAndSettle();

        expect(await _start(tester), isNot(isTrue));
        expect(_transitioning(tester, 'c'), isFalse);
        await _commit(tester);
        await tester.pumpAndSettle();

        // The dialog went away, the pages stayed.
        expect(find.text('dialog'), findsNothing);
        expect(controller.pages, hasLength(3));
      }, variant: android);

      testWidgets('the gesture is ignored when the stack changes under it', (
        tester,
      ) async {
        final controller = _threePages();
        await tester.pumpWidget(_app(kind, controller));
        await tester.pumpAndSettle();

        expect(await _start(tester), isTrue);
        await _update(tester, 0.3);
        controller.pop();
        await tester.pump();
        await _update(tester, 0.6);
        await _commit(tester);
        await tester.pumpAndSettle();

        // Only the pop from code happened.
        expect(controller.pages, hasLength(2));
        expect(find.text('b'), findsOneWidget);
      }, variant: android);

      testWidgets(
        'other platforms ignore the gesture',
        (tester) async {
          final controller = _threePages();
          await tester.pumpWidget(_app(kind, controller));
          await tester.pumpAndSettle();

          expect(await _start(tester), isFalse);
          await _update(tester, 0.5);
          expect(_transitioning(tester, 'c'), isFalse);
          expect(_slideOf(tester, 'c'), Offset.zero);

          // The binding pops like for a plain system back.
          await _commit(tester);
          await tester.pumpAndSettle();
          expect(controller.pages, hasLength(2));
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.iOS,
          TargetPlatform.macOS,
          TargetPlatform.linux,
          TargetPlatform.windows,
          TargetPlatform.fuchsia,
        }),
      );
    });
  }

  testWidgets('the split navigator in a two-pane layout is not followed', (
    tester,
  ) async {
    final controller = _threePages();
    await tester.pumpWidget(_app(_Kind.split, controller, canSplit: true));
    await tester.pumpAndSettle();

    expect(await _start(tester), isFalse);
    await _commit(tester);
    await tester.pumpAndSettle();

    expect(controller.pages, hasLength(2));
  }, variant: android);

  group('inside a route', () {
    // A second route of the app's Navigator, whose default Android transition
    // listens to the same gestures.
    Future<void> pushNavigator(
      WidgetTester tester,
      FoldableNavigatorController controller,
      _Kind kind,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _navigator(kind, controller),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    for (final kind in _Kind.values) {
      testWidgets('${kind.name}: one gesture pops one page, not the route', (
        tester,
      ) async {
        final controller = _threePages();
        await pushNavigator(tester, controller, kind);

        expect(await _start(tester), isTrue);
        await _update(tester, 0.5);
        await _commit(tester);
        await tester.pumpAndSettle();

        expect(controller.pages, hasLength(2));
        expect(find.text('b'), findsOneWidget);
        expect(find.text('open', skipOffstage: false), findsOneWidget);
        // The route is still there: it was not popped as well.
        expect(Navigator.of(tester.element(find.text('b'))).canPop(), true);
        expect(find.text('open'), findsNothing);
      }, variant: android);

      testWidgets(
        '${kind.name}: cancel leaves both the pages and the route',
        (tester) async {
          final controller = _threePages();
          await pushNavigator(tester, controller, kind);

          expect(await _start(tester), isTrue);
          await _update(tester, 0.5);
          await _cancel(tester);
          await tester.pumpAndSettle();

          expect(controller.pages, hasLength(3));
          expect(find.text('c'), findsOneWidget);
          expect(find.text('open'), findsNothing);
        },
        variant: android,
      );

      testWidgets(
        '${kind.name}: the last page leaves the gesture to the route',
        (tester) async {
          final controller = FoldableNavigatorController.single([_page('a')]);
          await pushNavigator(tester, controller, kind);

          // The route's own predictive transition takes it.
          expect(await _start(tester), isTrue);
          expect(controller.pages, hasLength(1));
          await _update(tester, 0.5);
          await _commit(tester);
          await tester.pumpAndSettle();

          expect(find.text('open'), findsOneWidget);
          expect(find.text('a'), findsNothing);
        },
        variant: android,
      );
    }
  });

  testWidgets('under the router delegate one gesture pops one page', (
    tester,
  ) async {
    final router = FoldableRouter(
      roots: const [_Route('/a')],
      config: FoldableRouterConfig(
        matcher: (uri) => _Route(uri.path == '/' ? '/a' : uri.path),
        notFound: (uri) => _Route(uri.path),
      ),
    );
    addTearDown(router.dispose);
    final delegate = FoldableRouterDelegate(
      router: router,
      navigatorKey: GlobalKey<NavigatorState>(),
      builder: (context) =>
          FoldableNavigator.stack(controller: router.controller),
    );
    addTearDown(delegate.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: const FoldableRouteInformationParser(),
      ),
    );
    router.push(const _Route('/b'));
    router.push(const _Route('/c'));
    await tester.pumpAndSettle();
    expect(router.controller.pages, hasLength(3));
    expect(find.text('screen /c'), findsOneWidget);

    expect(await _start(tester), isTrue);
    await _update(tester, 0.5);
    expect(_slideOf(tester, 'screen /c').dx, closeTo(0.5, 1e-9));
    await _commit(tester);
    await tester.pumpAndSettle();

    expect(router.controller.pages, hasLength(2));
    expect(find.text('screen /b'), findsOneWidget);

    // A plain back still pops one page, once.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.controller.pages, hasLength(1));
    expect(find.text('screen /a'), findsOneWidget);
  }, variant: android);
}

class _Route extends FoldableRoute {
  const _Route(this.path);

  @override
  final String path;

  @override
  Widget build(BuildContext context) => Text('screen $location');
}
