import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// Labels of the [_Probe]s that were built, in order, one per `initState`.
final List<String> _built = [];

/// Remembers that it was created, so a test can tell a screen that was never
/// built from one that was built and then kept.
class _Probe extends StatefulWidget {
  const _Probe(this.label);

  final String label;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _built.add(widget.label);
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

class _TabRoute extends FoldableRoute {
  const _TabRoute(this.name);

  final String name;

  @override
  String get path => '/$name';

  @override
  Widget build(BuildContext context) => _Probe(name);
}

FoldableRouter _router({required bool lazy}) {
  final router = FoldableRouter(
    roots: const [_TabRoute('home'), _TabRoute('inbox'), _TabRoute('profile')],
    config: FoldableRouterConfig(
      matcher: (uri) => null,
      notFound: (uri) => const _TabRoute('missing'),
      lazyBranches: lazy,
    ),
  );
  addTearDown(router.dispose);
  return router;
}

Widget _app(FoldableNavigatorController controller) {
  return MaterialApp(
    home: FoldableNavigator(
      controller: controller,
      builder: (context, body, secondary) => body,
    ),
  );
}

void main() {
  setUp(_built.clear);

  testWidgets('a branch is not built until it is shown', (tester) async {
    final router = _router(lazy: true);

    await tester.pumpWidget(_app(router.controller));

    expect(_built, ['home']);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('inbox', skipOffstage: false), findsNothing);
    expect(find.text('profile', skipOffstage: false), findsNothing);

    router.controller.openBranch(1);
    await tester.pump();

    expect(_built, ['home', 'inbox']);
    expect(find.text('inbox'), findsOneWidget);
    // The branch that was not shown yet is still not built.
    expect(find.text('profile', skipOffstage: false), findsNothing);
  });

  testWidgets('a branch that was shown is kept when another one is shown', (
    tester,
  ) async {
    final router = _router(lazy: true);
    await tester.pumpWidget(_app(router.controller));

    router.controller.openBranch(1);
    await tester.pump();
    router.controller.openBranch(0);
    await tester.pump();

    // Still mounted, offstage, and not built a second time.
    expect(find.text('inbox'), findsNothing);
    expect(find.text('inbox', skipOffstage: false), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
    expect(_built, ['home', 'inbox']);

    router.controller.openBranch(1);
    await tester.pump();

    expect(find.text('inbox'), findsOneWidget);
    expect(_built, ['home', 'inbox']);
  });

  testWidgets('only the branches after the first are wrapped', (tester) async {
    final router = _router(lazy: true);

    await tester.pumpWidget(_app(router.controller));

    expect(find.byType(LazyBranch, skipOffstage: false), findsNWidgets(2));
  });

  testWidgets('without lazyBranches every branch is built at startup', (
    tester,
  ) async {
    final router = _router(lazy: false);

    await tester.pumpWidget(_app(router.controller));

    expect(_built, unorderedEquals(['home', 'inbox', 'profile']));
    expect(find.byType(LazyBranch, skipOffstage: false), findsNothing);
  });

  testWidgets('LazyBranch builds its child when its own branch is shown', (
    tester,
  ) async {
    final controller = FoldableNavigatorController(
      branches: [
        [const FoldablePage<void>(child: _Probe('a'))],
        [
          const FoldablePage<void>(
            child: LazyBranch(branch: 1, child: _Probe('b')),
          ),
        ],
        [
          const FoldablePage<void>(
            child: LazyBranch(branch: 2, child: _Probe('c')),
          ),
        ],
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    expect(_built, ['a']);

    // Showing branch 2 builds only branch 2.
    controller.openBranch(2);
    await tester.pump();

    expect(_built, ['a', 'c']);
    expect(find.text('b', skipOffstage: false), findsNothing);
  });
}
