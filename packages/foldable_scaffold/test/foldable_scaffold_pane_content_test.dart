import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

const _breakpoints = FoldableBreakpoints(rail: 100000, split: 840);

void main() {
  testWidgets('paneContent receives the pane rectangles of the panes it lays '
      'out', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    FoldablePaneRects? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: ThemeData(platform: TargetPlatform.android),
            child: FoldableScaffold(
              breakpoints: _breakpoints,
              followFold: false,
              avoidCutouts: false,
              paneAnimationDuration: Duration.zero,
              body: const SizedBox.shrink(),
              secondaryBody: const SizedBox.shrink(),
              paneContent: (context, rects) {
                seen = rects;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect primary = tester.getRect(find.byKey(const Key('body_builder')));
    final Rect secondary = tester.getRect(
      find.byKey(const Key('secondary_body_builder')),
    );

    expect(seen, isNotNull);
    expect(seen!.isSplit, isTrue);
    expect(seen!.axis, Axis.horizontal);
    // Widths and heights match the panes the scaffold laid out.
    expect(seen!.primary!.width, primary.width);
    expect(seen!.primary!.height, primary.height);
    expect(seen!.secondary!.width, secondary.width);
    expect(seen!.secondary!.height, secondary.height);
    // The gap between the panes is the divider.
    expect(
      seen!.secondary!.left - seen!.primary!.right,
      secondary.left - primary.right,
    );
    // The primary pane starts at the start edge of the pane area.
    expect(seen!.primary!.left, 0);
  });

  testWidgets('a one-pane layout hides the secondary pane rect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    FoldablePaneRects? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: FoldableScaffold(
          breakpoints: _breakpoints,
          followFold: false,
          avoidCutouts: false,
          paneAnimationDuration: Duration.zero,
          body: const SizedBox.shrink(),
          secondaryBody: const SizedBox.shrink(),
          hasSecondaryBody: false,
          paneContent: (context, rects) {
            seen = rects;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(seen, isNotNull);
    expect(seen!.isSplit, isFalse);
    expect(seen!.primary, isNotNull);
    expect(seen!.secondary, isNull);
  });
}
