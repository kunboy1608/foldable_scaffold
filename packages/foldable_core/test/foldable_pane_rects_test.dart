import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_core/foldable_core.dart';

void main() {
  group('FoldablePaneRects', () {
    const split = FoldablePaneRects(
      primary: Rect.fromLTWH(0, 0, 200, 400),
      secondary: Rect.fromLTWH(201, 0, 300, 400),
      axis: Axis.horizontal,
    );

    test('isSplit is true only when both panes are shown', () {
      expect(split.isSplit, isTrue);
      expect(split.primaryVisible, isTrue);
      expect(split.secondaryVisible, isTrue);
      const single = FoldablePaneRects(
        primary: Rect.fromLTWH(0, 0, 500, 400),
        secondary: null,
        axis: Axis.horizontal,
      );
      expect(single.isSplit, isFalse);
      expect(single.secondaryVisible, isFalse);
    });

    test('null primary is not the same as Rect.zero', () {
      const hidden = FoldablePaneRects(
        primary: null,
        secondary: Rect.zero,
        axis: Axis.horizontal,
      );
      expect(hidden.primaryVisible, isFalse);
      // Rect.zero is a shown (if degenerate) rect, not a hidden pane.
      expect(hidden.secondaryVisible, isTrue);
    });

    test('equality and hashCode depend on the rects and the axis', () {
      const copy = FoldablePaneRects(
        primary: Rect.fromLTWH(0, 0, 200, 400),
        secondary: Rect.fromLTWH(201, 0, 300, 400),
        axis: Axis.horizontal,
      );
      expect(split, copy);
      expect(split.hashCode, copy.hashCode);
      expect(
        split,
        isNot(
          const FoldablePaneRects(
            primary: Rect.fromLTWH(0, 0, 200, 400),
            secondary: Rect.fromLTWH(201, 0, 300, 400),
            axis: Axis.vertical,
          ),
        ),
      );
    });
  });

  group('FoldablePaneRectsScope', () {
    const first = FoldablePaneRects(
      primary: Rect.fromLTWH(0, 0, 10, 10),
      secondary: null,
      axis: Axis.horizontal,
    );
    const second = FoldablePaneRects(
      primary: Rect.fromLTWH(0, 0, 10, 10),
      secondary: Rect.fromLTWH(11, 0, 10, 10),
      axis: Axis.horizontal,
    );

    Widget wrap(FoldablePaneRects rects, Widget child) =>
        FoldablePaneRectsScope(rects: rects, child: child);

    testWidgets('maybeOf subscribes the caller to changes', (tester) async {
      var dependentBuilds = 0;
      FoldablePaneRects? value;
      Widget dependent() => Builder(
        builder: (context) {
          dependentBuilds++;
          value = FoldablePaneRectsScope.rectsOf(context);
          return const SizedBox();
        },
      );
      final d = dependent();
      await tester.pumpWidget(wrap(first, d));
      expect(value, first);
      final base = dependentBuilds;

      await tester.pumpWidget(wrap(first, d));
      expect(dependentBuilds, base, reason: 'equal rects do not rebuild');

      await tester.pumpWidget(wrap(second, d));
      expect(dependentBuilds, base + 1);
      expect(value, second);
    });

    testWidgets('read does not subscribe the caller', (tester) async {
      var builds = 0;
      FoldablePaneRects? value;
      Widget dependent() => Builder(
        builder: (context) {
          builds++;
          value = FoldablePaneRectsScope.read(context)?.rects;
          return const SizedBox();
        },
      );
      final d = dependent();
      await tester.pumpWidget(wrap(first, d));
      expect(value, first);
      final base = builds;
      await tester.pumpWidget(wrap(second, d));
      expect(builds, base, reason: 'read does not subscribe');
    });
  });
}
