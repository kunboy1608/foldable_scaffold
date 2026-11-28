// foldable_router draws the pages of a tab above the layout returned by
// buildPanes. With a FoldableScaffold using extendBody, the frames of the panes
// reach under the navigation, and so do the pages: the navigation must still
// be painted over them and get the taps.
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_router_example/pages/home_page.dart';
import 'package:foldable_router_example/routes.dart';
import 'package:foldable_router_example/session.dart';
import 'package:foldable_router_example/with_scaffold.dart' as with_scaffold;
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

final GlobalKey _navigationKey = GlobalKey();

const _labels = ['Home', 'Users', 'Profile'];

/// The shell of `with_scaffold.dart`, with extendBody.
class _ExtendBodyShell extends FoldableShellRoute {
  const _ExtendBodyShell();

  @override
  List<FoldableShellChildRoute> get branches => const [
    HomeRoute(),
    UsersRoute(),
    ProfileRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Material(child: shell.child);

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    final shell = panes.shell;
    return FoldableScaffold(
      key: ValueKey<int>(panes.branchIndex),
      navigationKey: _navigationKey,
      extendBody: true,
      breakpoints: const FoldableBreakpoints(split: double.infinity),
      navigationBuilder: (context, placement, constraints, padding) {
        if (placement.isSide) {
          return NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final label in _labels)
                NavigationRailDestination(
                  icon: const Icon(Icons.circle_outlined),
                  label: Text(label),
                ),
            ],
          );
        }
        return NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: shell.goBranch,
          destinations: [
            for (final label in _labels)
              NavigationDestination(
                icon: const Icon(Icons.circle_outlined),
                label: label,
              ),
          ],
        );
      },
      body: panes.primary,
      secondaryBody: panes.hasSecondary ? panes.secondary : null,
    );
  }
}

late FoldableRouter router;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> pumpApp(
  WidgetTester tester, {
  required Size size,
  required FoldableRouter Function() create,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  router = create();
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router.routerConfig,
      builder: (context, child) => SizedBox.fromSize(size: size, child: child!),
    ),
  );
  await settle(tester);
}

Finder inNavigation(Type type, String label) =>
    find.descendant(of: find.byType(type), matching: find.text(label));

/// Whether a tap on [finder] reaches it, rather than something above it.
bool isHit(WidgetTester tester, Finder finder) {
  final target = tester.renderObject(finder);
  final result = tester.hitTestOnBinding(tester.getCenter(finder));
  return result.path.any((entry) => identical(entry.target, target));
}

void main() {
  setUp(session.reset);
  tearDown(session.reset);

  testWidgets('a page under the bottom bar does not take its taps', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: const Size(500, 800),
      create: () => createExampleRouter(const _ExtendBodyShell()),
    );
    expect(find.byType(HomePage), findsOneWidget);
    // The page reaches under the bar: extendBody.
    final page = tester.getRect(find.byType(HomePage));
    final bar = tester.getRect(find.byType(NavigationBar));
    expect(page.bottom, 800);
    expect(page.overlaps(bar), isTrue);

    expect(isHit(tester, inNavigation(NavigationBar, 'Users')), isTrue);
    await tester.tap(inNavigation(NavigationBar, 'Users'));
    await settle(tester);
    expect(router.stack.last, isA<UsersRoute>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page under the rail does not take its taps', (tester) async {
    await pumpApp(
      tester,
      size: const Size(1000, 800),
      create: () => createExampleRouter(const _ExtendBodyShell()),
    );
    final rail = tester.getRect(find.byType(NavigationRail));
    // Only the pane next to the rail extends under it, to the edge.
    expect(tester.getRect(find.byType(HomePage)).left, 0);
    expect(rail.left, 0);

    expect(isHit(tester, inNavigation(NavigationRail, 'Users')), isTrue);
    await tester.tap(inNavigation(NavigationRail, 'Users'));
    await settle(tester);
    expect(router.stack.last, isA<UsersRoute>());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'with_scaffold: the bar is moved to the scaffold of the new tab',
    (tester) async {
      await pumpApp(
        tester,
        size: const Size(500, 800),
        create: with_scaffold.createRouter,
      );
      final bar = tester.element(find.byType(NavigationBar));

      await tester.tap(inNavigation(NavigationBar, 'Users'));
      await tester.pump();
      // The same bar, now in the Users scaffold, animating its indicator.
      expect(
        identical(tester.element(find.byType(NavigationBar)), bar),
        isTrue,
      );
      await settle(tester);
      expect(router.stack.last, isA<UsersRoute>());
      expect(
        identical(tester.element(find.byType(NavigationBar)), bar),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
