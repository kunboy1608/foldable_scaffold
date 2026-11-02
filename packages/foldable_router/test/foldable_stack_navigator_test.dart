import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

FoldablePage<void> _page(String name) {
  return FoldablePage<void>(
    name: '/$name',
    child: Center(child: Text(name)),
  );
}

/// A page with a back button in its app bar.
FoldablePage<void> _backPage(String name) {
  return FoldablePage<void>(
    name: '/$name',
    child: Scaffold(
      appBar: AppBar(leading: const FoldableBackButton(), title: Text(name)),
      body: Text(name),
    ),
  );
}

Widget _app(FoldableNavigatorController controller) {
  return MaterialApp(home: FoldableNavigator.stack(controller: controller));
}

void main() {
  testWidgets('shows only the top page', (tester) async {
    final controller = FoldableNavigatorController.single([
      _page('body'),
      _page('detail'),
    ]);

    await tester.pumpWidget(_app(controller));

    expect(find.text('detail'), findsOneWidget);
    // The page below is not mounted at all, not even offstage.
    expect(find.text('body', skipOffstage: false), findsNothing);
  });

  testWidgets('push and pop replace the top page', (tester) async {
    final controller = FoldableNavigatorController.single([_page('body')]);

    await tester.pumpWidget(_app(controller));
    expect(find.text('body'), findsOneWidget);

    controller.push(_page('detail'));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
    expect(find.text('body', skipOffstage: false), findsNothing);

    controller.pop();
    await tester.pumpAndSettle();

    expect(find.text('body'), findsOneWidget);
    expect(find.text('detail', skipOffstage: false), findsNothing);
  });

  testWidgets('does not mount the other branches', (tester) async {
    final controller = FoldableNavigatorController(
      branches: [
        [_page('first tab')],
        [_page('second tab'), _page('second tab detail')],
      ],
    );

    await tester.pumpWidget(_app(controller));
    expect(find.text('first tab'), findsOneWidget);
    expect(find.text('second tab', skipOffstage: false), findsNothing);
    expect(find.text('second tab detail', skipOffstage: false), findsNothing);

    controller.goBranch(1);
    await tester.pump();

    expect(find.text('second tab detail'), findsOneWidget);
    expect(find.text('first tab', skipOffstage: false), findsNothing);
  });

  testWidgets('the back button pops the page it belongs to', (tester) async {
    final controller = FoldableNavigatorController.single([
      _backPage('body'),
      _backPage('detail'),
    ]);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(controller.pages.length, 1);
    expect(find.text('body'), findsWidgets);
    expect(find.text('detail', skipOffstage: false), findsNothing);
  });

  testWidgets('swiping from the left edge pops the top page', (tester) async {
    final controller = FoldableNavigatorController.single([
      _page('body'),
      _page('detail'),
    ]);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    final swipe = await tester.startGesture(const Offset(8, 300));
    await swipe.moveBy(const Offset(40, 0));
    await tester.pump();
    await swipe.moveBy(const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 300));

    // The top page follows the finger and is still on screen.
    expect(
      FoldableNavigator.isTransitioning(tester.element(find.text('detail'))),
      isTrue,
    );
    expect(find.text('detail'), findsOneWidget);

    await swipe.up();
    await tester.pumpAndSettle();

    expect(controller.pages.length, 1);
    expect(find.text('body'), findsOneWidget);
    expect(find.text('detail', skipOffstage: false), findsNothing);
  });

  testWidgets('a push slides the new top page in', (tester) async {
    final controller = FoldableNavigatorController.single([_page('body')]);

    await tester.pumpWidget(_app(controller));
    controller.push(_page('detail'));
    await tester.pump();

    expect(
      FoldableNavigator.isTransitioning(tester.element(find.text('detail'))),
      isTrue,
    );
    final slides = tester
        .widgetList<SlideTransition>(
          find.ancestor(
            of: find.text('detail'),
            matching: find.byType(SlideTransition),
          ),
        )
        .map((slide) => slide.position.value);
    // The new page starts just outside the right edge.
    expect(slides, contains(const Offset(1, 0)));

    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    expect(find.text('body', skipOffstage: false), findsNothing);
  });

  testWidgets('an AppBar without leading shows a back button by itself', (
    tester,
  ) async {
    final controller = FoldableNavigatorController.single([
      FoldablePage<void>(
        name: '/body',
        child: Scaffold(appBar: AppBar(title: const Text('body'))),
      ),
    ]);

    await tester.pumpWidget(_app(controller));
    expect(find.byType(BackButton), findsNothing);

    controller.push(
      FoldablePage<void>(
        name: '/detail',
        child: Scaffold(appBar: AppBar(title: const Text('detail'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(controller.pages.length, 1);
    expect(find.byType(BackButton), findsNothing);
  });
}
