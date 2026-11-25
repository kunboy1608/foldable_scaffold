import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

const _breakpoints = FoldableBreakpoints(rail: 100000, split: 840);

void main() {
  testWidgets(
    'paneContent rects keep in sync with both pane slots in LTR/RTL',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: FoldableScaffold(
                breakpoints: _breakpoints,
                followFold: false,
                avoidCutouts: false,
                paneAnimationDuration: Duration.zero,
                hasSecondaryBody: true,
                paneContent: (_, rects) => Stack(
                  children: [
                    if (rects.primary case final primary?)
                      Positioned.fromRect(
                        rect: primary,
                        child: const SizedBox.expand(key: Key('rect-primary')),
                      ),
                    if (rects.secondary case final secondary?)
                      Positioned.fromRect(
                        rect: secondary,
                        child: const SizedBox.expand(
                          key: Key('rect-secondary'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byKey(const Key('rect-primary'))),
          tester.getRect(find.byKey(const Key('body_builder'))),
        );
        expect(
          tester.getRect(find.byKey(const Key('rect-secondary'))),
          tester.getRect(find.byKey(const Key('secondary_body_builder'))),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
  test('paneContent cannot be combined with body pane content', () {
    expect(
      () => FoldableScaffold(
        body: const SizedBox(),
        paneContent: (_, _) => const SizedBox(),
      ),
      throwsAssertionError,
    );
    expect(
      () => FoldableScaffold(
        body: const SizedBox(),
        secondaryBody: const SizedBox(),
        paneContent: (_, _) => const SizedBox(),
      ),
      throwsAssertionError,
    );
    expect(
      () => FoldableScaffold(paneContent: (_, _) => const SizedBox()),
      returnsNormally,
    );
  });
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
              hasSecondaryBody: true,
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
