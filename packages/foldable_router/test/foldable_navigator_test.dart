import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
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

/// The names of the pages that show a back button.
List<String> _pagesWithBackButton(WidgetTester tester) {
  return find
      .byType(BackButton, skipOffstage: false)
      .evaluate()
      .map((element) => FoldableNavigator.pageOf(element)?.name ?? '')
      .toList();
}

/// How far the slide carrying [text] has moved from its resting place.
///
/// Pass [offstage] to also find pages of hidden panes.
Offset _slideOf(WidgetTester tester, String text, {bool offstage = false}) {
  final slide = tester.widget<SlideTransition>(
    find
        .ancestor(
          of: find.text(text, skipOffstage: !offstage),
          matching: find.byType(SlideTransition, skipOffstage: false),
        )
        .first,
  );
  return slide.position.value;
}

Widget _app(
  FoldableNavigatorController controller, {
  required bool primary,
  bool split = false,
}) {
  return MaterialApp(
    home: FoldableScaffoldScope(
      canSplit: split,
      child: FoldablePaneLayout(
        primaryVisible: primary || split,
        secondaryVisible: !primary || split,
        child: FoldableNavigator(
          controller: controller,
          builder: (context, body, secondary) => Column(
            children: [
              Expanded(child: body),
              if (secondary != null) Expanded(child: secondary),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A narrow app with one pane: the body while the branch has one page, the
/// top page otherwise, like a phone.
Widget _singlePaneApp(FoldableNavigatorController controller) {
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final hasSecondary = controller.pages.length > 1;
      return MaterialApp(
        home: FoldableScaffoldScope(
          canSplit: false,
          child: FoldablePaneLayout(
            primaryVisible: !hasSecondary,
            secondaryVisible: hasSecondary,
            child: FoldableNavigator(
              controller: controller,
              builder: (context, body, secondary) => Column(
                children: [
                  Expanded(child: body),
                  if (secondary != null) Expanded(child: secondary),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A real [FoldableScaffold] in a narrow window: the scaffold itself decides
/// which pane is shown.
Widget _phoneApp(FoldableNavigatorController controller) {
  return MaterialApp(
    home: FoldableNavigator(
      controller: controller,
      builder: (context, body, secondary) => FoldableScaffold(
        bodyBuilder: (_, _) => body,
        secondaryBodyBuilder: (_, _) => secondary,
      ),
    ),
  );
}

void main() {
  testWidgets('a pane slides only when its own page changes', (tester) async {
    final body = _page('body');
    final controller = FoldableNavigatorController.single([body, _page('top')]);

    // The primary pane is the one on screen, so the body is what the user
    // sees and a change of the top page must leave it alone.
    await tester.pumpWidget(_app(controller, primary: true));
    expect(find.text('body'), findsOneWidget);

    controller.setPages([body, _page('next')]);
    await tester.pump();

    expect(_slideOf(tester, 'body'), Offset.zero);

    // A change of the body itself does slide.
    controller.setPages([_page('other'), _page('last')]);
    await tester.pump();

    expect(_slideOf(tester, 'other'), isNot(Offset.zero));
  });

  testWidgets('opening the secondary body on a wide layout does not slide', (
    tester,
  ) async {
    final body = _page('body');
    final controller = FoldableNavigatorController.single([body]);

    await tester.pumpWidget(_app(controller, primary: true, split: true));
    expect(find.text('body'), findsOneWidget);

    controller.push(_page('detail'));
    await tester.pump();

    // Two panes fit, so the detail just appears while the scaffold opens the
    // secondary pane.
    expect(
      FoldableNavigator.isTransitioning(tester.element(find.text('body'))),
      isFalse,
    );
    expect(_slideOf(tester, 'body'), Offset.zero);
    expect(_slideOf(tester, 'detail', offstage: true), Offset.zero);
    expect(find.text('body', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a push on a single pane slides both pages', (tester) async {
    final controller = FoldableNavigatorController.single([_page('body')]);

    await tester.pumpWidget(_singlePaneApp(controller));
    expect(find.text('body'), findsOneWidget);

    controller.push(_page('detail'));
    await tester.pump();

    // The visible pane slides from the body page to the pushed one.
    expect(
      FoldableNavigator.isTransitioning(tester.element(find.text('detail'))),
      isTrue,
    );
    // The new page starts just outside the right edge.
    expect(_slideOf(tester, 'detail'), const Offset(1, 0));

    await tester.pump(const Duration(milliseconds: 150));
    // The body page only gives way a third, like a Cupertino page push.
    final bodyOffset = _slideOf(tester, 'body');
    expect(bodyOffset.dx, lessThan(0));
    expect(bodyOffset.dx, greaterThan(-1));

    await tester.pumpAndSettle();
    expect(_slideOf(tester, 'detail'), Offset.zero);
    expect(_slideOf(tester, 'body'), Offset.zero);
  });

  testWidgets('a pop on a single pane slides back', (tester) async {
    final controller = FoldableNavigatorController.single([
      _page('body'),
      _page('detail'),
    ]);

    await tester.pumpWidget(_singlePaneApp(controller));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    controller.pop();
    await tester.pump();
    expect(
      FoldableNavigator.isTransitioning(tester.element(find.text('body'))),
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(_slideOf(tester, 'detail').dx, greaterThan(0));
    expect(_slideOf(tester, 'body').dx, lessThan(0));

    await tester.pumpAndSettle();
    expect(_slideOf(tester, 'body'), Offset.zero);
    expect(find.text('detail'), findsNothing);
  });

  testWidgets('split view slides each pane whose page changed', (tester) async {
    final first = _page('first');
    final second = _page('second');
    final controller = FoldableNavigatorController.single([first, second]);

    // Both panes visible: the body shows 'first', the secondary 'second'.
    await tester.pumpWidget(_app(controller, primary: true, split: true));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);

    controller.push(_page('third'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // 'second' slides into the body pane and 'third' into the secondary one.
    expect(_slideOf(tester, 'first'), isNot(Offset.zero));
    expect(_slideOf(tester, 'second'), isNot(Offset.zero));
    expect(_slideOf(tester, 'third'), isNot(Offset.zero));

    await tester.pumpAndSettle();
    expect(_slideOf(tester, 'second'), Offset.zero);
    expect(_slideOf(tester, 'third'), Offset.zero);
  });

  testWidgets('swiping from the left edge pops the page', (tester) async {
    final controller = FoldableNavigatorController.single([
      _page('body'),
      _page('detail'),
    ]);

    await tester.pumpWidget(_phoneApp(controller));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    final swipe = await tester.startGesture(const Offset(8, 300));
    await swipe.moveBy(const Offset(40, 0));
    await tester.pump();
    await swipe.moveBy(const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 300));

    // The top page follows the finger and the one below comes back with it.
    expect(_slideOf(tester, 'detail').dx, greaterThan(0));
    expect(_slideOf(tester, 'detail').dx, lessThan(1));
    expect(_slideOf(tester, 'body').dx, lessThan(0));
    expect(
      FoldableNavigator.isTransitioning(tester.element(find.text('detail'))),
      isTrue,
    );

    await swipe.up();
    await tester.pumpAndSettle();

    expect(controller.pages.length, 1);
    expect(_slideOf(tester, 'body'), Offset.zero);
    expect(find.text('detail'), findsNothing);
  });

  testWidgets('a short swipe from the edge snaps back', (tester) async {
    final controller = FoldableNavigatorController.single([
      _page('body'),
      _page('detail'),
    ]);

    await tester.pumpWidget(_phoneApp(controller));
    await tester.pumpAndSettle();

    final swipe = await tester.startGesture(const Offset(8, 300));
    await swipe.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await swipe.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_slideOf(tester, 'detail').dx, greaterThan(0));

    await swipe.up();
    await tester.pumpAndSettle();

    // Released before half the width: nothing is popped and the page is back.
    expect(controller.pages.length, 2);
    expect(_slideOf(tester, 'detail'), Offset.zero);
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('popping to one page shows the body pane at once', (
    tester,
  ) async {
    final controller = FoldableNavigatorController.single([
      _page('body'),
      _page('detail'),
    ]);

    await tester.pumpWidget(_phoneApp(controller));
    await tester.pumpAndSettle();

    double paneWidth(Key key) =>
        tester.getSize(find.byKey(key, skipOffstage: false)).width;

    expect(paneWidth(const Key('body_builder')), 0);
    expect(paneWidth(const Key('secondary_body_builder')), 800);

    controller.pop();
    await tester.pump();

    // The pane switches at the start of the slide, so there is no pane
    // resize (and no blank pane) left to see once the slide ends.
    expect(paneWidth(const Key('body_builder')), 800);
    expect(paneWidth(const Key('secondary_body_builder')), 0);

    await tester.pumpAndSettle();
    expect(paneWidth(const Key('body_builder')), 800);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('a swipe back pops one page at a time', (tester) async {
    final controller = FoldableNavigatorController.single([
      _page('first'),
      _page('second'),
      _page('third'),
    ]);

    await tester.pumpWidget(_phoneApp(controller));
    await tester.pumpAndSettle();
    expect(find.text('third'), findsOneWidget);

    final swipe = await tester.startGesture(const Offset(8, 300));
    await swipe.moveBy(const Offset(40, 0));
    await tester.pump();
    await swipe.moveBy(const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 300));

    // 'third' slides out and 'second' slides in, like a normal pop.
    expect(_slideOf(tester, 'third').dx, greaterThan(0));
    expect(_slideOf(tester, 'second').dx, lessThan(0));

    await swipe.up();
    await tester.pumpAndSettle();

    expect(controller.pages.length, 2);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('third'), findsNothing);
  });

  testWidgets('a swipe that does not start at the edge does nothing', (
    tester,
  ) async {
    final controller = FoldableNavigatorController.single([
      _page('body'),
      _page('detail'),
    ]);

    await tester.pumpWidget(_singlePaneApp(controller));
    await tester.pumpAndSettle();

    final swipe = await tester.startGesture(const Offset(300, 300));
    await swipe.moveBy(const Offset(300, 0));
    await tester.pump();
    await swipe.up();
    await tester.pumpAndSettle();

    expect(controller.pages.length, 2);
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('swiping does not pop in a split layout', (tester) async {
    final controller = FoldableNavigatorController.single([
      _page('body'),
      _page('detail'),
    ]);

    await tester.pumpWidget(_app(controller, primary: true, split: true));
    await tester.pumpAndSettle();

    final swipe = await tester.startGesture(const Offset(8, 300));
    await swipe.moveBy(const Offset(40, 0));
    await tester.pump();
    await swipe.moveBy(const Offset(500, 0));
    await tester.pump();
    await swipe.up();
    await tester.pumpAndSettle();

    expect(controller.pages.length, 2);
  });

  testWidgets('the back button shows in both panes while the stack can pop', (
    tester,
  ) async {
    final controller = FoldableNavigatorController.single([_backPage('first')]);

    // One page: nothing to pop, so no back button anywhere.
    await tester.pumpWidget(_app(controller, primary: true, split: true));
    expect(_pagesWithBackButton(tester), isEmpty);

    controller.push(_backPage('second'));
    await tester.pump();
    await tester.pumpAndSettle();

    // The body and the secondary body both show it now.
    expect(_pagesWithBackButton(tester), containsAll(['/first', '/second']));
  });

  testWidgets('the back button of the body pops the top page', (tester) async {
    final controller = FoldableNavigatorController.single([
      _backPage('first'),
      _backPage('second'),
    ]);

    await tester.pumpWidget(_app(controller, primary: true, split: true));
    await tester.pumpAndSettle();

    // The back button of the body page removes the top page of the branch.
    final bodyButton = find
        .descendant(
          of: find.ancestor(
            of: find.text('first'),
            matching: find.byType(Scaffold),
          ),
          matching: find.byType(BackButton),
        )
        .first;
    await tester.tap(bodyButton);
    await tester.pumpAndSettle();

    expect(controller.pages.length, 1);
    expect(find.text('second'), findsNothing);
  });
}
