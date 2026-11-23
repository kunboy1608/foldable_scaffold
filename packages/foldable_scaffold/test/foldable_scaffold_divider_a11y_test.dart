import 'dart:ui'
    show
        DisplayFeature,
        DisplayFeatureState,
        DisplayFeatureType,
        SemanticsAction;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

Finder get _divider => find.byKey(const Key('pane_divider'));

/// Pumps a [FoldableScaffold] in a window of [size] and waits for the panes.
Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 600),
  bool rtl = false,
  bool secondary = true,
  List<DisplayFeature> features = const [],
  List<double> snapWidths = const [],
  double dividerKeyboardStep = 16.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = features;
  addTearDown(tester.view.reset);

  final scaffold = FoldableScaffold(
    dividerKeyboardStep: dividerKeyboardStep,
    snapWidths: snapWidths,
    body: const Text('body'),
    secondaryBody: secondary ? const Text('secondary') : null,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      home: rtl
          ? Directionality(textDirection: TextDirection.rtl, child: scaffold)
          : scaffold,
    ),
  );
  await tester.pumpAndSettle();
}

double _secondaryWidth(WidgetTester tester) => tester
    .getSize(
      find.byKey(const Key('secondary_body_builder'), skipOffstage: false),
    )
    .width;

/// The focus node of the divider, found by its debug label so the focus
/// widgets of the app around it are not counted.
Finder get _dividerFocus => find.byWidgetPredicate(
  (widget) =>
      widget is Focus &&
      widget.focusNode?.debugLabel == 'FoldableScaffold divider',
);

Future<void> _focusDivider(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  group('the keyboard', () {
    testWidgets('Tab reaches the divider and shows the focus', (tester) async {
      await _pump(tester);

      expect(_dividerFocus, findsOneWidget);
      expect(tester.widget<Focus>(_dividerFocus).focusNode!.hasFocus, isFalse);

      await _focusDivider(tester);

      expect(tester.widget<Focus>(_dividerFocus).focusNode!.hasFocus, isTrue);
      // The default handle takes its active look when focused.
      final handle = find.descendant(
        of: _divider,
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(handle), const Size(12, 50));
      expect(
        (tester.widget<AnimatedContainer>(handle).decoration! as BoxDecoration)
            .color,
        ThemeData(platform: TargetPlatform.linux).colorScheme.primary,
      );
    });

    testWidgets('the arrow keys move the divider in LTR', (tester) async {
      await _pump(tester);
      await _focusDivider(tester);
      expect(_secondaryWidth(tester), closeTo(700, 0.01));

      // Left grows the secondary pane, right shrinks it.
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_secondaryWidth(tester), closeTo(716, 0.01));

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_secondaryWidth(tester), closeTo(700, 0.01));

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_secondaryWidth(tester), closeTo(684, 0.01));
    });

    testWidgets('Shift makes a step four times longer', (tester) async {
      await _pump(tester);
      await _focusDivider(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(_secondaryWidth(tester), closeTo(764, 0.01));
    });

    testWidgets('the step is dividerKeyboardStep wide', (tester) async {
      await _pump(tester, dividerKeyboardStep: 40);
      await _focusDivider(tester);

      await _press(tester, LogicalKeyboardKey.arrowLeft);

      expect(_secondaryWidth(tester), closeTo(740, 0.01));
    });

    testWidgets('Home and End put the divider at the edges', (tester) async {
      await _pump(tester);
      await _focusDivider(tester);

      await _press(tester, LogicalKeyboardKey.end);
      expect(_secondaryWidth(tester), closeTo(1176, 0.01));

      await _press(tester, LogicalKeyboardKey.home);
      expect(_secondaryWidth(tester), closeTo(200, 0.01));
    });

    testWidgets('the keyboard stops at the edges', (tester) async {
      await _pump(tester);
      await _focusDivider(tester);

      await _press(tester, LogicalKeyboardKey.end);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_secondaryWidth(tester), closeTo(1176, 0.01));

      await _press(tester, LogicalKeyboardKey.home);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_secondaryWidth(tester), closeTo(200, 0.01));
    });

    testWidgets('in RTL the keys follow the mouse', (tester) async {
      await _pump(tester, rtl: true);
      await _focusDivider(tester);
      expect(_secondaryWidth(tester), closeTo(700, 0.01));

      // In RTL the secondary pane is on the left: moving right grows it, as
      // dragging to the right does.
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_secondaryWidth(tester), closeTo(716, 0.01));

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_secondaryWidth(tester), closeTo(700, 0.01));
    });

    testWidgets('End snaps, the arrow keys do not', (tester) async {
      await _pump(tester, snapWidths: const [1170.0, 710.0]);
      await _focusDivider(tester);

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_secondaryWidth(tester), closeTo(716, 0.01));

      await _press(tester, LogicalKeyboardKey.end);
      expect(_secondaryWidth(tester), closeTo(1170, 0.01));
    });
  });

  group('the screen reader', () {
    testWidgets('reads the divider as a slider', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester);

        final node = tester.getSemantics(_divider);
        final data = node.getSemanticsData();
        expect(data.label, 'Resize panes');
        expect(data.value, '51%');
        expect(data.increasedValue, '52%');
        expect(data.decreasedValue, '50%');
        expect(data.hasAction(SemanticsAction.increase), isTrue);
        expect(data.hasAction(SemanticsAction.decrease), isTrue);
        expect(data.flagsCollection.isSlider, isTrue);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('resizes the panes with increase and decrease', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester);
        final label = find.semantics.byLabel('Resize panes');

        tester.semantics.performAction(label, SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(_secondaryWidth(tester), closeTo(716, 0.01));

        tester.semantics.performAction(label, SemanticsAction.decrease);
        await tester.pumpAndSettle();
        expect(_secondaryWidth(tester), closeTo(700, 0.01));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('the label can be changed', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(1400, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.linux),
            home: const FoldableScaffold(
              dividerSemanticLabel: 'Redimensionner',
              body: Text('body'),
              secondaryBody: Text('secondary'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(_divider).getSemanticsData().label,
          'Redimensionner',
        );
      } finally {
        semantics.dispose();
      }
    });
  });

  group('where there is no handle', () {
    testWidgets('around a hinge: no focus and no semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          features: [
            DisplayFeature(
              bounds: const Rect.fromLTRB(680, 0, 720, 600),
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureFlat,
            ),
          ],
        );

        expect(tester.getSize(_divider).width, 40);
        expect(_dividerFocus, findsNothing);
        expect(find.bySemanticsLabel('Resize panes'), findsNothing);

        await _focusDivider(tester);
        expect(find.bySemanticsLabel('Resize panes'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('in a one-pane layout: no focus and no semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester, size: const Size(800, 600));

        expect(tester.getSize(_divider).width, 0);
        expect(_dividerFocus, findsNothing);
        expect(find.bySemanticsLabel('Resize panes'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('without a secondary body: no focus and no semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester, secondary: false);

        expect(tester.getSize(_divider).width, 0);
        expect(_dividerFocus, findsNothing);
        expect(find.bySemanticsLabel('Resize panes'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });
  });
}
