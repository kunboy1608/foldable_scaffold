import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

import 'rects_test_harness.dart';

const _wide = Size(1200, 800);

class _CountPage extends StatefulWidget {
  const _CountPage({required this.label, this.next});
  final String label;
  final FoldableRoute? next;
  @override
  State<_CountPage> createState() => _CountPageState();
}

class _CountPageState extends State<_CountPage> {
  int count = 0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('content-${widget.label}'),
      onTap: () => setState(() => count++),
      child: Container(
        color: widget.label == 'detail' ? Colors.blue : Colors.green,
        child: Column(
          children: [
            Text(widget.label),
            TextButton(
              key: Key('inc-${widget.label}'),
              onPressed: () => setState(() => count++),
              child: const Text('+'),
            ),
            if (widget.next != null)
              TextButton(
                key: Key('push-${widget.label}'),
                onPressed: () => FoldableRouter.of(context).open(widget.next!),
                child: const Text('push'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataShell extends FoldableShellRoute {
  const _DataShell();
  @override
  List<FoldableShellChildRoute> get branches => const [_Root()];
  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      ValueListenableBuilder<bool>(
        valueListenable: _split,
        builder: (BuildContext context, bool enabled, Widget? child) =>
            RectsTestHarness(enabled: enabled, child: shell.child),
      );
}

final ValueNotifier<bool> _split = ValueNotifier<bool>(true);

class _Root extends FoldableShellChildRoute {
  const _Root();
  @override
  String get segment => 'root';
  @override
  FoldableShellParent get parent => const _DataShell();
  @override
  Widget build(BuildContext context) =>
      const _CountPage(label: 'root', next: _Detail());
}

class _Detail extends FoldableShellChildRoute {
  const _Detail();
  @override
  String get segment => 'detail';
  @override
  FoldableShellParent get parent => const _Root();
  @override
  Widget build(BuildContext context) => const _CountPage(label: 'detail');
}

Future<void> _tapAt(WidgetTester tester, Offset position) async {
  final gesture = await tester.startGesture(position);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<FoldableRouter> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = FoldableRouter(
    initial: const _DataShell(),
    routes: const {},
    notFoundBuilder: (BuildContext context, Uri uri) => const SizedBox(),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('push-root')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'hit-test is limited to each pane rectangle',
    (tester) async {
      _split.value = true;
      await _pump(tester, _wide);
      await _openDetail(tester);

      final rootRect = tester.getRect(find.byKey(const Key('content-root')));
      final detailRect = tester.getRect(
        find.byKey(const Key('content-detail')),
      );
      final rootState = tester.state<_CountPageState>(
        find.byType(_CountPage).first,
      );
      final detailState = tester.state<_CountPageState>(
        find.byType(_CountPage).last,
      );

      // Tapping inside the secondary pane rectangle hits the detail page only.
      await _tapAt(tester, detailRect.center);
      expect(detailState.count, 1);
      expect(rootState.count, 0);

      // Tapping in the divider gap between the two panes hits no page.
      final dividerX = (rootRect.right + detailRect.left) / 2;
      await _tapAt(tester, Offset(dividerX, rootRect.center.dy));
      expect(detailState.count, 1);
      expect(rootState.count, 0);

      // Tapping inside the primary pane rectangle hits the root page only.
      await _tapAt(tester, rootRect.center);
      expect(rootState.count, 1);
      expect(detailState.count, 1);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets('a page rectangle matches the scope and follows pose changes', (
    tester,
  ) async {
    _split.value = true;
    final router = await _pump(tester, _wide);
    await _openDetail(tester);

    final scope = tester.firstElement(find.byType(FoldablePaneRectsScope));
    final published = (scope.widget as FoldablePaneRectsScope).rects;

    final detailRect = tester.getRect(find.byKey(const Key('content-detail')));
    final rootRect = tester.getRect(find.byKey(const Key('content-root')));
    expect(detailRect, published.secondary);
    expect(rootRect, published.primary);

    // Switch to one pane: detail goes back on top of the single pane.
    _split.value = false;
    await tester.pumpAndSettle();
    final scope1 = tester.firstElement(find.byType(FoldablePaneRectsScope));
    final published1 = (scope1.widget as FoldablePaneRectsScope).rects;
    expect(published1.secondary, isNull);
    expect(
      tester.getRect(find.byKey(const Key('content-detail'))),
      published1.primary,
    );
    expect(router.stack.last, const _Detail());
  });

  testWidgets('a page that overflows its pane is clipped to that pane', (
    tester,
  ) async {
    _split.value = true;
    await _pump(tester, _wide);
    await _openDetail(tester);

    final scope = tester.firstElement(find.byType(FoldablePaneRectsScope));
    final published = (scope.widget as FoldablePaneRectsScope).rects;

    final detailRect = tester.getRect(find.byType(_CountPage).last);
    // The detail page layout is constrained to the secondary rectangle.
    expect(detailRect.width, published.secondary!.width);
    expect(detailRect.height, published.secondary!.height);
    // It does not paint into the divider gap.
    final dividerX = published.secondary!.left - 12;
    expect(
      tester.getRect(find.byKey(const Key('content-root'))).right,
      lessThanOrEqualTo(dividerX),
    );
  });
}
