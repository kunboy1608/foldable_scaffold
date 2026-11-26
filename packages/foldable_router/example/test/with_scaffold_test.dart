import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_router_example/session.dart';
import 'package:foldable_router_example/with_scaffold.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

const _narrow = Size(400, 900);
const _wide = Size(1400, 900);
const _iphoneDuo = Size(951, 669);

class _FakeSource implements FoldablePlatformSource {
  _FakeSource(this.state);

  FoldablePlatformState state;
  final _controller = StreamController<FoldablePlatformState>.broadcast();

  @override
  Future<FoldablePlatformState> getState() => Future.value(state);

  @override
  Stream<FoldablePlatformState> get stateChanges => _controller.stream;

  void push(FoldablePlatformState next) {
    state = next;
    _controller.add(next);
  }
}

Future<FoldableRouter> _pumpApp(
  WidgetTester tester, {
  required Size size,
  FoldablePlatformSource? platformSource,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = createRouter();
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router.routerConfig,
      builder: platformSource == null
          ? null
          : (BuildContext context, Widget? child) =>
                FoldablePlatformScope(source: platformSource, child: child!),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

FoldablePaneRects? _rectsOf(WidgetTester tester) {
  final scopes = tester.widgetList<FoldablePaneRectsScope>(
    find.byType(FoldablePaneRectsScope),
  );
  return scopes.isNotEmpty ? scopes.first.rects : null;
}

void main() {
  setUp(session.reset);

  testWidgets('narrow window: one pane, no secondary', (tester) async {
    await _pumpApp(tester, size: _narrow);
    expect(_rectsOf(tester)?.isSplit, isFalse);
    expect(_rectsOf(tester)?.secondary, isNull);
    expect(_rectsOf(tester)?.primary, isNotNull);
  });

  testWidgets('wide window + a secondary page: split, two panes', (
    tester,
  ) async {
    final router = await _pumpApp(tester, size: _wide);
    // At the branch root there is no second page, so one pane.
    expect(_rectsOf(tester)?.isSplit, isFalse);

    await router.open(const UserRoute(id: '7'));
    await tester.pumpAndSettle();

    expect(_rectsOf(tester)?.isSplit, isTrue);
    expect(_rectsOf(tester)?.primary, isNotNull);
    expect(_rectsOf(tester)?.secondary, isNotNull);
    expect(_rectsOf(tester)?.axis, Axis.horizontal);
    // The divider gap exists between the two panes.
    expect(
      _rectsOf(tester)!.secondary!.left - _rectsOf(tester)!.primary!.right,
      greaterThan(0),
    );
  });

  testWidgets('push shows the top page in the secondary pane; back closes it', (
    tester,
  ) async {
    final router = await _pumpApp(tester, size: _wide);
    expect(_rectsOf(tester)?.secondary, isNull);

    await router.open(const UserRoute(id: '7'));
    await tester.pumpAndSettle();
    expect(router.stack.last, const UserRoute(id: '7'));
    expect(_rectsOf(tester)?.secondary, isNotNull);
    expect(find.text('User 7 detail'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(router.stack.last, const UsersRoute());
    expect(_rectsOf(tester)?.secondary, isNull);
    expect(find.text('User 7 detail'), findsNothing);
  });

  testWidgets('changing the breakpoint re-lays the panes; stack unchanged', (
    tester,
  ) async {
    final router = await _pumpApp(tester, size: _narrow);
    await router.open(const UserRoute(id: '7'));
    await tester.pumpAndSettle();
    // Narrow: one pane, the detail fills it.
    expect(_rectsOf(tester)?.isSplit, isFalse);

    tester.view.physicalSize = _wide;
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();

    // Wide: the same stack now shows two panes, with no app change.
    expect(_rectsOf(tester)?.isSplit, isTrue);
    expect(router.stack.last, const UserRoute(id: '7'));
  });

  testWidgets(
    'iPhone Duo landscape: rail lives inside the 84 px strip',
    (tester) async {
      final source = _FakeSource(
        FoldablePlatformState(
          viewSize: _iphoneDuo,
          verticalBarEdge: FoldableNavigationEdge.end,
        ),
      );
      tester.view.padding = const FakeViewPadding(right: 84, bottom: 35);
      tester.view.viewPadding = const FakeViewPadding(right: 84, bottom: 35);
      await _pumpApp(tester, size: _iphoneDuo, platformSource: source);

      final rails = tester.widgetList<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(rails, isNotEmpty);
      final railRect = tester.getRect(find.byType(NavigationRail).first);
      // The strip starts at 951 - 84 = 867.
      expect(railRect.left, greaterThanOrEqualTo(867));
      expect(railRect.right, lessThanOrEqualTo(951));
      expect(railRect.width, 84);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}),
  );
}
