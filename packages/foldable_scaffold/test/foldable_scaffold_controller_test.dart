import 'dart:io' show File;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

Finder get _divider => find.byKey(const Key('pane_divider'));

double _secondaryWidth(WidgetTester tester) => tester
    .getSize(
      find.byKey(const Key('secondary_body_builder'), skipOffstage: false),
    )
    .width;

DisplayFeature _flatFold(double x, double height) => DisplayFeature(
  bounds: Rect.fromLTRB(x, 0, x, height),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

/// Pumps a [FoldableScaffold], and reports the controller its body sees.
Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 600),
  FoldableScaffoldController? controller,
  String? restorationId,
  bool secondary = true,
  List<double> snapWidths = const [],
  List<DisplayFeature> features = const [],
  ValueChanged<FoldableScaffoldController>? onController,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = features;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      restorationScopeId: 'app',
      theme: ThemeData(platform: TargetPlatform.linux),
      home: FoldableScaffold(
        controller: controller,
        restorationId: restorationId,
        snapWidths: snapWidths,
        bodyBuilder: (context, constraints) {
          onController?.call(FoldableScaffold.of(context));
          return const Text('body');
        },
        secondaryBody: secondary ? const Text('secondary') : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('what the controller reads', () {
    testWidgets('the width of the secondary pane in a split layout', (
      tester,
    ) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);

      await _pump(tester, controller: controller);

      expect(controller.isSplit, isTrue);
      expect(controller.isDraggingDivider, isFalse);
      expect(controller.secondaryWidth, closeTo(700, 0.01));
    });

    testWidgets('null while there is one pane', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);

      await _pump(tester, controller: controller, size: const Size(800, 600));

      expect(controller.isSplit, isFalse);
      expect(controller.secondaryWidth, isNull);
    });

    testWidgets('the drag of the divider', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);

      final gesture = await tester.startGesture(tester.getCenter(_divider));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();

      expect(controller.isDraggingDivider, isTrue);
      expect(controller.secondaryWidth, closeTo(740, 0.01));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.isDraggingDivider, isFalse);
    });
  });

  group('setSecondaryWidth', () {
    testWidgets('moves the divider like a drag', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);

      controller.setSecondaryWidth(400);
      await tester.pumpAndSettle();

      expect(_secondaryWidth(tester), closeTo(400, 0.01));
      expect(controller.secondaryWidth, closeTo(400, 0.01));
    });

    testWidgets('clamps to the range of the divider', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);

      controller.setSecondaryWidth(10);
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(200, 0.01));

      controller.setSecondaryWidth(5000);
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(1176, 0.01));
    });

    testWidgets('snaps only when asked to', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller, snapWidths: const [360]);

      controller.setSecondaryWidth(370);
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(370, 0.01));

      controller.setSecondaryWidth(370, snap: true);
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(360, 0.01));
    });

    testWidgets('does nothing with one pane', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller, size: const Size(800, 600));

      controller.setSecondaryWidth(300);
      await tester.pumpAndSettle();

      expect(controller.secondaryWidth, isNull);
      // The secondary body still fills the one pane.
      expect(_secondaryWidth(tester), closeTo(800, 0.01));
    });
  });

  group('resetDivider', () {
    testWidgets('puts the divider back in the middle', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);

      controller.setSecondaryWidth(400);
      await tester.pumpAndSettle();
      controller.resetDivider();
      await tester.pumpAndSettle();

      expect(_secondaryWidth(tester), closeTo(700, 0.01));
    });

    testWidgets('puts the divider back on a flat fold', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        controller: controller,
        features: [_flatFold(900, 600)],
      );
      expect(_secondaryWidth(tester), closeTo(488, 0.01));

      controller.setSecondaryWidth(400);
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(400, 0.01));

      controller.resetDivider();
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(488, 0.01));
    });
  });

  group('FoldableScaffold.of', () {
    testWidgets('finds the controller that was passed', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      FoldableScaffoldController? seen;

      await _pump(
        tester,
        controller: controller,
        onController: (found) => seen = found,
      );

      expect(seen, same(controller));
    });

    testWidgets('finds the controller the scaffold made', (tester) async {
      FoldableScaffoldController? seen;

      await _pump(tester, onController: (found) => seen = found);

      expect(seen, isNotNull);
      expect(seen!.isSplit, isTrue);
      expect(seen!.secondaryWidth, closeTo(700, 0.01));
    });

    testWidgets('asserts when there is no scaffold above', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(FoldableScaffold.maybeOf(context), isNull);
              expect(() => FoldableScaffold.of(context), throwsAssertionError);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('who owns the controller', () {
    testWidgets('a controller that was passed is not disposed', (tester) async {
      final controller = FoldableScaffoldController();

      await _pump(tester, controller: controller);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(ChangeNotifier.debugAssertNotDisposed(controller), isTrue);
      controller.dispose();
    });

    testWidgets('the controller of the scaffold is disposed with it', (
      tester,
    ) async {
      FoldableScaffoldController? automatic;
      await _pump(tester, onController: (found) => automatic = found);
      expect(automatic, isNotNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(
        () => ChangeNotifier.debugAssertNotDisposed(automatic!),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('state restoration', () {
    testWidgets('keeps the position of the divider', (tester) async {
      await _pump(tester, restorationId: 'mail');

      await tester.drag(_divider, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(900, 0.01));

      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      expect(_secondaryWidth(tester), closeTo(900, 0.01));
    });

    testWidgets('restores that the divider was placed by the user', (
      tester,
    ) async {
      await _pump(
        tester,
        restorationId: 'mail',
        features: [_flatFold(900, 600)],
      );
      expect(_secondaryWidth(tester), closeTo(488, 0.01));

      await tester.drag(_divider, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(588, 0.01));

      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      // Not back on the crease: the user's divider is restored.
      expect(_secondaryWidth(tester), closeTo(588, 0.01));
    });

    testWidgets('does nothing without a restorationId', (tester) async {
      await _pump(tester);

      await tester.drag(_divider, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(_secondaryWidth(tester), closeTo(900, 0.01));

      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      expect(_secondaryWidth(tester), closeTo(700, 0.01));
    });
  });

  group('notifications', () {
    testWidgets('come for the first layout and each real change only', (
      tester,
    ) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);

      await _pump(tester, controller: controller);
      expect(notified, 1);

      // Nothing moves: pumping again tells nobody.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(notified, 1);

      // Dragging changes isDraggingDivider and the width.
      final gesture = await tester.startGesture(tester.getCenter(_divider));
      await tester.pump();
      expect(controller.isDraggingDivider, isTrue);
      expect(notified, 2);
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(notified, 3);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.isDraggingDivider, isFalse);
      final afterDrag = notified;
      expect(afterDrag, greaterThan(3));

      await tester.pump();
      await tester.pumpAndSettle();
      expect(notified, afterDrag);
    });

    testWidgets('a controller that replaces another is brought up to date', (
      tester,
    ) async {
      final first = FoldableScaffoldController();
      final second = FoldableScaffoldController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget app(FoldableScaffoldController controller) => MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: FoldableScaffold(
          controller: controller,
          body: const Text('body'),
          secondaryBody: const Text('secondary'),
        ),
      );

      tester.view.physicalSize = const Size(1400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(first));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(second));
      await tester.pumpAndSettle();

      expect(second.isSplit, isTrue);
      expect(second.secondaryWidth, closeTo(700, 0.01));
      second.setSecondaryWidth(500);
      await tester.pumpAndSettle();
      expect(second.secondaryWidth, closeTo(500, 0.01));
    });
  });

  test('attach, detach and update are @internal', () {
    final source = File(
      'lib/src/foldable_scaffold_controller.dart',
    ).readAsStringSync();
    for (final member in ['attach(', 'detach(', 'update({']) {
      expect(source, contains('@internal\n  void $member'));
    }
  });
}
