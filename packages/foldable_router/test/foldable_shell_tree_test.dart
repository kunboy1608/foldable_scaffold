import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A shell builder that shows which shell it is and both panes.
FoldableShellBuilder _shell(String name) {
  return (context, controller, body, secondaryBody) => Column(
    children: [
      Text(name),
      Expanded(child: body),
      if (secondaryBody != null) Expanded(child: secondaryBody),
    ],
  );
}

NormalRoute _page(String path, String label, {List<FoldableRoute> routes = const []}) {
  return NormalRoute(
    path: path,
    builder: (context) => Text(label),
    routes: routes,
  );
}

void main() {
  late FoldableShellRoute mainShell;
  late FoldableShellRoute statisticShell;

  FoldableRouter build() {
    mainShell = FoldableShellRoute(
      branches: [
        _page(
          '/home',
          'home',
          routes: [
            _page(
              'calendar',
              'calendar',
              routes: [_page('event/:id', 'event')],
            ),
            _page('news', 'news', routes: [_page(':id', 'news item')]),
          ],
        ),
        _page('/document', 'document'),
        _page('/profile', 'profile'),
      ],
      builder: _shell('main shell'),
    );
    statisticShell = FoldableShellRoute(
      branches: [
        _page(
          '/profit',
          'profit',
          routes: [_page('/profit/recipe', 'profit recipe')],
        ),
        _page('/expense', 'expense'),
      ],
      builder: _shell('statistic shell'),
    );
    return FoldableRouter(
      routes: [mainShell, statisticShell],
      config: FoldableRouterConfig(
        notFound: (uri) => _page(uri.path.isEmpty ? '/' : uri.path, 'not found'),
      ),
    );
  }

  Future<BuildContext> pump(WidgetTester tester, FoldableRouter router) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return ListenableBuilder(
              listenable: router,
              builder: (context, _) => router.buildShell(context),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.rootContextOf = () => context;
    return context;
  }

  testWidgets('a deep link rebuilds the whole ancestor stack', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    await pump(tester, router);

    router.openUri(Uri.parse('/home/calendar/event/7'));
    await tester.pumpAndSettle();

    expect(router.shell, mainShell);
    expect(router.currentIndex, 0);
    // home > calendar > event
    expect(router.pages, hasLength(3));
    // Only the top two pages are on screen: calendar in the body, event in the
    // secondary body. Home stays mounted offstage under them.
    expect(find.text('calendar'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
    expect(find.text('main shell'), findsOneWidget);
  });

  testWidgets('a deep link activates the right shell and branch', (
    tester,
  ) async {
    final router = build();
    addTearDown(router.dispose);
    await pump(tester, router);

    router.openUri(Uri.parse('/profit/recipe'));
    await tester.pumpAndSettle();

    expect(router.shell, statisticShell);
    expect(router.currentIndex, 0);
    expect(router.pages, hasLength(2));
    expect(find.text('statistic shell'), findsOneWidget);
    expect(find.text('main shell'), findsNothing);
    expect(find.text('profit recipe'), findsOneWidget);
  });

  testWidgets('showShell switches shell and keeps the other one state', (
    tester,
  ) async {
    final router = build();
    addTearDown(router.dispose);
    await pump(tester, router);

    router.openUri(Uri.parse('/home'));
    await tester.pumpAndSettle();
    router.push(_page('/home/details', 'details'));
    await tester.pumpAndSettle();
    expect(router.pages, hasLength(2));

    router.showShell(statisticShell);
    await tester.pumpAndSettle();
    expect(router.shell, statisticShell);
    expect(find.text('profit'), findsOneWidget);

    router.showShell(mainShell);
    await tester.pumpAndSettle();
    expect(router.shell, mainShell);
    // The pushed page on the home tab is still there.
    expect(router.pages, hasLength(2));
    expect(find.text('details'), findsOneWidget);
  });

  testWidgets('a NormalRoute pushes and pops in the branch', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    await pump(tester, router);

    router.openUri(Uri.parse('/home'));
    await tester.pumpAndSettle();
    expect(router.pages, hasLength(1));

    router.push(_page('/home/details', 'details'));
    await tester.pumpAndSettle();
    expect(router.pages, hasLength(2));
    expect(find.text('details'), findsOneWidget);

    expect(router.pop(), isTrue);
    await tester.pumpAndSettle();
    expect(router.pages, hasLength(1));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the startup path / shows the first branch of the first shell', (
    tester,
  ) async {
    final router = build();
    addTearDown(router.dispose);
    await pump(tester, router);

    router.openUri(Uri.parse('/'));
    await tester.pumpAndSettle();

    expect(router.shell, mainShell);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a deep link names each page with its full path', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    await pump(tester, router);

    router.openUri(Uri.parse('/home/calendar/event/7'));
    await tester.pumpAndSettle();

    expect(router.pages.map((page) => page.name), [
      '/home',
      '/home/calendar',
      '/home/calendar/event/:id',
    ]);
  });

  testWidgets('saveState and restoreState keep every shell', (tester) async {
    final first = build();
    addTearDown(first.dispose);
    await pump(tester, first);

    first.openUri(Uri.parse('/profit/recipe'));
    await tester.pumpAndSettle();
    final saved = first.saveState();
    expect(saved['shell'], 1);

    final second = build();
    addTearDown(second.dispose);
    second.restoreState(saved);

    expect(second.currentUri.toString(), '/profit/recipe');
    expect(second.pages.map((page) => page.name), ['/profit', '/profit/recipe']);
  });
}
