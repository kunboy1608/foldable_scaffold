import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:foldable_scaffold/src/foldable_scaffold_layout.dart';
import 'package:material_ui/material_ui.dart';

double _bodyWidth(WidgetTester tester) => tester
    .getSize(find.byKey(const Key('body_builder'), skipOffstage: false))
    .width;

void main() {
  group('PaneGeometry equality', () {
    test('two geometries with the same extents and axis are equal', () {
      const a = PaneGeometry(
        primaryExtent: 1,
        dividerExtent: 2,
        secondaryExtent: 3,
      );
      const b = PaneGeometry(
        primaryExtent: 1,
        dividerExtent: 2,
        secondaryExtent: 3,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('the axis and each extent take part in equality', () {
      const base = PaneGeometry(
        primaryExtent: 1,
        dividerExtent: 2,
        secondaryExtent: 3,
      );
      expect(
        base,
        isNot(
          const PaneGeometry(
            primaryExtent: 1,
            dividerExtent: 2,
            secondaryExtent: 3,
            axis: Axis.vertical,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const PaneGeometry(
            primaryExtent: 9,
            dividerExtent: 2,
            secondaryExtent: 3,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const PaneGeometry(
            primaryExtent: 1,
            dividerExtent: 9,
            secondaryExtent: 3,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const PaneGeometry(
            primaryExtent: 1,
            dividerExtent: 2,
            secondaryExtent: 9,
          ),
        ),
      );
    });

    test('PaneGeometryTween is equal when its end geometry is equal', () {
      const end = PaneGeometry(
        primaryExtent: 1,
        dividerExtent: 2,
        secondaryExtent: 3,
      );
      final a = PaneGeometryTween(end: end);
      final b = PaneGeometryTween(end: end);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  testWidgets('rebuilding the scaffold mid-animation does not restart it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final hasSecondary = ValueNotifier<bool>(false);
    final rebuildTick = ValueNotifier<int>(0);
    addTearDown(hasSecondary.dispose);
    addTearDown(rebuildTick.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: ValueListenableBuilder<bool>(
          valueListenable: hasSecondary,
          builder: (context, hs, _) => ListenableBuilder(
            listenable: rebuildTick,
            builder: (context, _) => FoldableScaffold(
              paneAnimationDuration: const Duration(milliseconds: 300),
              hasSecondaryBody: hs,
              body: const Text('body'),
              secondaryBody: const Text('secondary'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final start = _bodyWidth(tester);
    hasSecondary.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final mid = _bodyWidth(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(start), reason: 'the pane animation is running');

    // The parent rebuilds with the very same geometry while the animation
    // runs (a push/pop of the router does this). The tween must not restart.
    rebuildTick.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    final atEnd = _bodyWidth(tester);
    await tester.pumpAndSettle();
    final settled = _bodyWidth(tester);
    expect(
      atEnd,
      closeTo(settled, 0.5),
      reason: 'the pane animation restarted on a redundant rebuild',
    );
  });
}
