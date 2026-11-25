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

  group('FoldablePaneRects.sideBySide', () {
    const size = Size(600, 400);

    test('splits by secondaryExtent, divider in between (LTR)', () {
      final rects = FoldablePaneRects.sideBySide(
        size,
        secondaryExtent: 200,
        dividerExtent: 4,
      );
      expect(rects.axis, Axis.horizontal);
      expect(rects.primary, const Rect.fromLTWH(0, 0, 396, 400));
      expect(rects.secondary, const Rect.fromLTWH(400, 0, 200, 400));
      expect(rects.isSplit, isTrue);
    });

    test('splits by secondaryFraction', () {
      final rects = FoldablePaneRects.sideBySide(size, secondaryFraction: 0.25);
      expect(rects.secondary!.width, 150);
      expect(rects.primary!.width, 450);
    });

    test('fraction applies to the width left after the divider', () {
      final rects = FoldablePaneRects.sideBySide(
        size,
        secondaryFraction: 0.5,
        dividerExtent: 8,
      );
      expect(rects.primary!.width, 296);
      expect(rects.secondary!.width, 296);
      expect(rects.secondary!.left, 304);
    });

    test('RTL puts the primary pane on the right', () {
      final rects = FoldablePaneRects.sideBySide(
        size,
        secondaryExtent: 200,
        dividerExtent: 4,
        textDirection: TextDirection.rtl,
      );
      expect(rects.secondary, const Rect.fromLTWH(0, 0, 200, 400));
      expect(rects.primary, const Rect.fromLTWH(204, 0, 396, 400));
    });

    test(
      'a zero secondaryExtent hides the secondary pane (null, no split)',
      () {
        final rects = FoldablePaneRects.sideBySide(size, secondaryExtent: 0);
        expect(rects.secondary, isNull);
        expect(rects.secondaryVisible, isFalse);
        expect(rects.isSplit, isFalse);
        // A single pane fills the whole area: no divider gap is left behind.
        expect(rects.primary, const Rect.fromLTWH(0, 0, 600, 400));
      },
    );

    test('a zero secondaryFraction hides the secondary pane in RTL too', () {
      final rects = FoldablePaneRects.sideBySide(
        size,
        secondaryFraction: 0,
        dividerExtent: 4,
        textDirection: TextDirection.rtl,
      );
      expect(rects.secondary, isNull);
      expect(rects.isSplit, isFalse);
      expect(rects.primary, const Rect.fromLTWH(0, 0, 600, 400));
    });

    test('a narrow size that leaves the primary no room hides it (null)', () {
      final rects = FoldablePaneRects.sideBySide(
        const Size(100, 400),
        secondaryExtent: 100,
      );
      expect(rects.primary, isNull);
      expect(rects.primaryVisible, isFalse);
      expect(rects.isSplit, isFalse);
      expect(rects.secondary, const Rect.fromLTWH(0, 0, 100, 400));
    });

    test('a zero-size area hides both panes', () {
      final rects = FoldablePaneRects.sideBySide(
        Size.zero,
        secondaryFraction: 0.5,
      );
      expect(rects.primary, isNull);
      expect(rects.secondary, isNull);
      expect(rects.isSplit, isFalse);
    });
  });

  group('FoldablePaneRects.stacked', () {
    const size = Size(400, 800);

    test('stacks primary above secondary with the divider between', () {
      final rects = FoldablePaneRects.stacked(
        size,
        secondaryExtent: 300,
        dividerExtent: 6,
      );
      expect(rects.axis, Axis.vertical);
      expect(rects.primary, const Rect.fromLTWH(0, 0, 400, 494));
      expect(rects.secondary, const Rect.fromLTWH(0, 500, 400, 300));
      expect(rects.isSplit, isTrue);
    });

    test('stacks by secondaryFraction', () {
      final rects = FoldablePaneRects.stacked(size, secondaryFraction: 0.5);
      expect(rects.primary!.height, 400);
      expect(rects.secondary!.height, 400);
      expect(rects.secondary!.top, 400);
    });

    test('a zero secondaryExtent hides the stacked secondary pane (null)', () {
      final rects = FoldablePaneRects.stacked(size, secondaryExtent: 0);
      expect(rects.secondary, isNull);
      expect(rects.isSplit, isFalse);
      expect(rects.primary, const Rect.fromLTWH(0, 0, 400, 800));
    });

    test('a narrow height that leaves the primary no room hides it (null)', () {
      final rects = FoldablePaneRects.stacked(
        const Size(400, 100),
        secondaryFraction: 1,
      );
      expect(rects.primary, isNull);
      expect(rects.secondary, const Rect.fromLTWH(0, 0, 400, 100));
      expect(rects.isSplit, isFalse);
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
