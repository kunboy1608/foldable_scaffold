import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_dev_tools/foldable_dev_tools.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('pane reports only notify when they change', () {
    final controller = FoldableDevToolsController();
    var updates = 0;
    controller.addListener(() => updates++);

    const pane = FoldablePaneInfo(
      primaryVisible: true,
      secondaryVisible: false,
      canSplit: false,
      width: 800,
      height: 600,
    );
    controller.reportPane(pane);
    controller.reportPane(pane);
    expect(updates, 1);
    expect(controller.pane, same(pane));
  });

  test('navigation events are kept, bounded at 100', () {
    final controller = FoldableDevToolsController();
    for (var i = 0; i < 105; i++) {
      controller.onNavigation(
        FoldableNavigationEvent(
          kind: FoldableNavigationKind.push,
          uri: Uri.parse('/page/$i'),
          branch: 0,
          depth: i,
        ),
      );
    }
    expect(controller.events, hasLength(100));
    expect(controller.events.last.uri.toString(), '/page/104');

    controller.clearEvents();
    expect(controller.events, isEmpty);
  });

  testWidgets('works above the navigator, without an Overlay', (tester) async {
    // MaterialApp.builder is outside the Navigator's Overlay: the overlay must
    // not need one, or its buttons break as soon as a Tooltip shows.
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FoldableDevTools(child: child ?? const SizedBox.shrink()),
        home: const SizedBox.shrink(),
      ),
    );

    await tester.longPress(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // The tooltip finds the chrome's Overlay, and the button still works.
    expect(tester.takeException(), isNull);
    expect(find.text('Foldable dev tools'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Viewport'), findsOneWidget);
  });

  testWidgets('the chrome lets taps reach the app', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FoldableDevTools(child: child ?? const SizedBox.shrink()),
        home: Center(
          child: FilledButton(
            onPressed: () => taps++,
            child: const Text('tap'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tap'));
    expect(taps, 1);
  });

  testWidgets('opens the panel and simulates a screen size', (tester) async {
    final controller = FoldableDevToolsController();
    addTearDown(controller.dispose);
    var size = Size.zero;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FoldableDevTools(
          controller: controller,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) {
            size = MediaQuery.sizeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // Real window size while no viewport is simulated.
    expect(size, const Size(800, 600));

    controller.viewport = FoldableViewport.phone;
    await tester.pumpAndSettle();
    expect(size, const Size(360, 600));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Foldable dev tools'), findsOneWidget);
    expect(find.text('Viewport'), findsOneWidget);
    expect(find.text('Phone'), findsWidgets);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Foldable dev tools'), findsNothing);
  });

  group('hinge', () {
    /// Pumps the app and returns what its MediaQuery says about the display.
    Future<List<DisplayFeature> Function()> pumpApp(
      WidgetTester tester,
      FoldableDevToolsController controller,
    ) async {
      var features = <DisplayFeature>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => FoldableDevTools(
            controller: controller,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) {
              features = MediaQuery.displayFeaturesOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return () => features;
    }

    testWidgets('is reported to the app as a hinge', (tester) async {
      final controller = FoldableDevToolsController();
      addTearDown(controller.dispose);
      final features = await pumpApp(tester, controller);
      expect(features(), isEmpty);

      controller
        ..showHinge = true
        ..hingeThickness = 40;
      await tester.pumpAndSettle();

      // The default window is 800 x 600; the hinge is in the middle.
      final feature = features().single;
      expect(feature.type, DisplayFeatureType.hinge);
      expect(feature.state, DisplayFeatureState.postureFlat);
      expect(feature.bounds, const Rect.fromLTRB(380, 0, 420, 600));
    });

    testWidgets('is reported inside a simulated viewport', (tester) async {
      final controller = FoldableDevToolsController()
        ..viewport = FoldableViewport.foldableOpen
        ..showHinge = true
        ..hingePosition = 0.25;
      addTearDown(controller.dispose);
      final features = await pumpApp(tester, controller);

      // The viewport is 717 wide and as tall as the window.
      final feature = features().single;
      expect(feature.bounds.left, closeTo(717 * 0.25 - 12, 0.01));
      expect(feature.bounds.width, 24);
      expect(feature.bounds.height, 600);
    });

    testWidgets('a fold has no width, and can be half open', (tester) async {
      final controller = FoldableDevToolsController()
        ..showHinge = true
        ..hingeMode = FoldableHingeMode.foldFlat;
      addTearDown(controller.dispose);
      final features = await pumpApp(tester, controller);

      var feature = features().single;
      expect(feature.type, DisplayFeatureType.fold);
      expect(feature.state, DisplayFeatureState.postureFlat);
      expect(feature.bounds, const Rect.fromLTRB(400, 0, 400, 600));

      controller.hingeMode = FoldableHingeMode.foldHalfOpen;
      await tester.pumpAndSettle();
      feature = features().single;
      expect(feature.type, DisplayFeatureType.fold);
      expect(feature.state, DisplayFeatureState.postureHalfOpened);
    });

    testWidgets('hiding it takes it away from the app', (tester) async {
      final controller = FoldableDevToolsController()..showHinge = true;
      addTearDown(controller.dispose);
      final features = await pumpApp(tester, controller);
      expect(features(), hasLength(1));

      controller.showHinge = false;
      await tester.pumpAndSettle();

      expect(features(), isEmpty);
    });

    testWidgets('the panel switches the kind of hinge', (tester) async {
      // Tall enough to build the whole panel.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = FoldableDevToolsController()
        ..isOpen = true
        ..showHinge = true;
      addTearDown(controller.dispose);
      await pumpApp(tester, controller);

      await tester.tap(find.text('Fold, half open'));
      await tester.pumpAndSettle();

      expect(controller.hingeMode, FoldableHingeMode.foldHalfOpen);
    });
  });
}
