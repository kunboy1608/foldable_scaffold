import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

class _Home extends BranchRoute {
  const _Home();

  @override
  String get path => '/home';

  @override
  Widget build(BuildContext context) => const Text('home');
}

class _Inbox extends BranchRoute {
  const _Inbox();

  @override
  String get path => '/inbox';

  @override
  Widget build(BuildContext context) => const Text('inbox');
}

class _Details extends FoldableRoute {
  const _Details({this.id});

  final String? id;

  @override
  String get path => '/details';

  @override
  Map<String, Object?> get query => {'id': id};

  @override
  Widget build(BuildContext context) => Text('details ${id ?? ''}');
}

class _SignIn extends FoldableRoute {
  const _SignIn();

  @override
  String get path => '/sign-in';

  @override
  Widget build(BuildContext context) => const Text('sign in');
}

FoldableRoute? _match(Uri uri) {
  return switch (uri.path) {
    '/home' => const _Home(),
    '/inbox' => const _Inbox(),
    '/details' => _Details(id: RouteQuery.fromUri(uri).string('id')),
    '/sign-in' => const _SignIn(),
    _ => null,
  };
}

FoldableRouter _router() => FoldableRouter(
  routes: [
    FoldableShellRoute(
      branches: const [_Home(), _Inbox()],
      builder: (context, controller, body, secondaryBody) => Scaffold(
        appBar: AppBar(title: Text('branch ${controller.currentIndex}')),
        body: Row(
          children: [
            Expanded(child: body),
            Expanded(child: secondaryBody ?? const SizedBox.shrink()),
          ],
        ),
      ),
    ),
    // A full-screen sibling of the shell.
    const _SignIn(),
  ],
  config: FoldableRouterConfig(
    matcher: _match,
    notFound: (uri) => _Details(id: uri.path),
  ),
);

/// Pumps [router] and captures a context below the app, so navigation that
/// needs a [BuildContext] can run without a delegate.
Future<BuildContext> _pump(WidgetTester tester, FoldableRouter router) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return ListenableBuilder(
            listenable: router,
            builder: (context, _) => router.buildShell(context),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('the shell route draws the current branch inside the shell', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    expect(find.text('home'), findsOneWidget);
    expect(find.text('branch 0'), findsOneWidget);
  });

  testWidgets('push and pop stay inside the shell', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    final context = await _pump(tester, router);

    router.open(context, const _Details(id: '1'));
    await tester.pumpAndSettle();
    expect(find.text('details 1'), findsOneWidget);
    // Still the shell around it.
    expect(find.text('branch 0'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('details 1'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a plain top-level route is shown full screen over the shell', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    final context = await _pump(tester, router);

    router.open(context, const _SignIn());
    await tester.pumpAndSettle();
    expect(find.text('sign in'), findsOneWidget);
    // The shell is not drawn.
    expect(find.text('branch 0'), findsNothing);

    // Back returns to the shell.
    router.back();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('branch 0'), findsOneWidget);
  });
}
