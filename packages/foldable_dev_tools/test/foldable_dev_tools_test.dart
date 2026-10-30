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
}
