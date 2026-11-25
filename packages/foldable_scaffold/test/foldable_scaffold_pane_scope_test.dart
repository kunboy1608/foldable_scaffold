import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Records the [FoldablePane] published above it.
class _PaneProbe extends StatelessWidget {
  const _PaneProbe({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text('$label:${FoldablePaneScope.paneOf(context).name}');
  }
}

/// Counts how many times its [build] runs.
class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.label});

  final String label;

  static final Map<String, int> builds = <String, int>{};

  static void reset() => builds.clear();

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  Widget build(BuildContext context) {
    _BuildCounter.builds[widget.label] =
        (_BuildCounter.builds[widget.label] ?? 0) + 1;
    return Text(widget.label);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  FoldableBreakpoints? breakpoints,
  List<DisplayFeature> features = const [],
  bool hasSecondaryBody = true,
  Widget? body,
  Widget? secondaryBody,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = features;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      home: FoldableScaffold(
        breakpoints: breakpoints,
        hasSecondaryBody: hasSecondaryBody,
        body: body ?? const _PaneProbe(label: 'primary'),
        secondaryBody: secondaryBody ?? const _PaneProbe(label: 'secondary'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FoldablePaneScope', () {
    testWidgets('publishes primary and secondary for each pane', (
      tester,
    ) async {
      await _pump(tester, size: const Size(1400, 600));

      expect(find.text('primary:primary'), findsOneWidget);
      expect(find.text('secondary:secondary'), findsOneWidget);
    });

    testWidgets('a hidden pane still publishes its scope', (tester) async {
      // Narrow: secondary replaces primary; primary stays at width 0.
      await _pump(tester, size: const Size(800, 600));

      expect(
        tester
            .getSize(find.byKey(const Key('body_builder'), skipOffstage: false))
            .width,
        0,
      );
      expect(find.text('primary:primary', skipOffstage: false), findsOneWidget);
      expect(find.text('secondary:secondary'), findsOneWidget);

      // Wide with the secondary closed: secondary stays mounted at width 0.
      await _pump(tester, size: const Size(1400, 600), hasSecondaryBody: false);

      expect(
        tester
            .getSize(
              find.byKey(
                const Key('secondary_body_builder'),
                skipOffstage: false,
              ),
            )
            .width,
        0,
      );
      expect(find.text('primary:primary'), findsOneWidget);
      expect(
        find.text('secondary:secondary', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('FoldablePaneLayout', () {
    testWidgets('axis is vertical around a horizontal hinge', (tester) async {
      await _pump(
        tester,
        size: const Size(800, 1200),
        features: const [
          DisplayFeature(
            bounds: Rect.fromLTRB(0, 580, 800, 620),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );

      final layout = tester.widget<FoldablePaneLayout>(
        find.byType(FoldablePaneLayout),
      );
      expect(layout.axis, Axis.vertical);
      expect(layout.canSplit, isTrue);
      expect(layout.isSplit, isTrue);
    });

    testWidgets('canSplit follows FoldableBreakpoints', (tester) async {
      await _pump(
        tester,
        size: const Size(900, 800),
        breakpoints: const FoldableBreakpoints.desktop(split: 1200),
      );
      expect(
        tester
            .widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout))
            .canSplit,
        isFalse,
      );

      await _pump(
        tester,
        size: const Size(900, 800),
        breakpoints: const FoldableBreakpoints.desktop(split: 800),
      );
      expect(
        tester
            .widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout))
            .canSplit,
        isTrue,
      );
    });

    testWidgets('changing pose does not explode the pane build count', (
      tester,
    ) async {
      _BuildCounter.reset();
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: const FoldableScaffold(
            hasSecondaryBody: false,
            body: _BuildCounter(label: 'body'),
            secondaryBody: _BuildCounter(label: 'secondary'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buildsBefore = _BuildCounter.builds['body'] ?? 0;
      final secondaryBefore = _BuildCounter.builds['secondary'] ?? 0;

      // Flip the pose once: secondary opens (single-pane swap).
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: const FoldableScaffold(
            hasSecondaryBody: true,
            body: _BuildCounter(label: 'body'),
            secondaryBody: _BuildCounter(label: 'secondary'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bodyDelta = (_BuildCounter.builds['body'] ?? 0) - buildsBefore;
      final secondaryDelta =
          (_BuildCounter.builds['secondary'] ?? 0) - secondaryBefore;
      // A single pose change must not fan out into a rebuild storm (feedback
      // loop). A few frames for the pane animation are fine.
      expect(bodyDelta, lessThanOrEqualTo(4));
      expect(secondaryDelta, lessThanOrEqualTo(4));
    });
  });
}
