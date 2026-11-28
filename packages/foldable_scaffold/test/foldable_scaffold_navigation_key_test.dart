// navigationKey: the navigation keeps its State when the scaffold is replaced
// (one scaffold per tab), and the key is only ever in one slot.
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// A navigation that records its State objects and the indexes it was given.
class _Nav extends StatefulWidget {
  const _Nav({required this.index, required this.log});

  final int index;
  final _NavLog log;

  @override
  State<_Nav> createState() => _NavState();
}

class _NavLog {
  final states = <State<_Nav>>[];
  final updates = <(int, int)>[];
}

class _NavState extends State<_Nav> {
  @override
  void initState() {
    super.initState();
    widget.log.states.add(this);
  }

  @override
  void didUpdateWidget(_Nav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      widget.log.updates.add((oldWidget.index, widget.index));
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('nav'),
    color: const Color(0xFF0000FF),
    child: SizedBox.expand(child: Text('tab ${widget.index}')),
  );
}

/// The State of the navigation under [key].
State keyedState(WidgetTester tester, GlobalKey key) => tester.state(
  find.descendant(of: find.byKey(key), matching: find.byType(_Nav)),
);

void main() {
  Future<void> pumpTab(
    WidgetTester tester, {
    required int tab,
    required _NavLog log,
    GlobalKey? navigationKey,
    FoldableNavigationEdge edge = FoldableNavigationEdge.bottom,
    bool extendBody = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: FoldableScaffold(
          // One scaffold per tab, as foldable_router builds them.
          key: ValueKey(tab),
          navigationKey: navigationKey,
          extendBody: extendBody,
          navigationPlacement: (_) =>
              FoldableNavigationPlacement(edge, extent: 80),
          navigationBuilder: (context, placement, constraints, padding) =>
              SizedBox(
                height: placement.isSide ? null : 80,
                child: _Nav(index: tab, log: log),
              ),
          body: Text('body $tab'),
        ),
      ),
    );
  }

  for (final extendBody in [false, true]) {
    group('extendBody $extendBody', () {
      testWidgets('a new scaffold gets the same navigation State', (
        tester,
      ) async {
        final key = GlobalKey();
        final log = _NavLog();
        await pumpTab(
          tester,
          tab: 0,
          log: log,
          navigationKey: key,
          extendBody: extendBody,
        );
        final state = log.states.single;

        await pumpTab(
          tester,
          tab: 1,
          log: log,
          navigationKey: key,
          extendBody: extendBody,
        );
        await pumpTab(
          tester,
          tab: 2,
          log: log,
          navigationKey: key,
          extendBody: extendBody,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(log.states, [state]);
        expect(state.mounted, isTrue);
        expect(log.updates, [(0, 1), (1, 2)]);
        expect(find.text('tab 2'), findsOneWidget);
      });

      testWidgets('without the key the navigation is built again', (
        tester,
      ) async {
        final log = _NavLog();
        await pumpTab(tester, tab: 0, log: log, extendBody: extendBody);
        await pumpTab(tester, tab: 1, log: log, extendBody: extendBody);

        expect(log.states, hasLength(2));
        expect(log.updates, isEmpty);
      });

      testWidgets('the key moves with the navigation from edge to edge', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(900, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final log = _NavLog();
        await pumpTab(
          tester,
          tab: 0,
          log: log,
          navigationKey: key,
          extendBody: extendBody,
        );
        final state = log.states.single;

        for (final edge in [
          FoldableNavigationEdge.left,
          FoldableNavigationEdge.right,
          FoldableNavigationEdge.top,
          FoldableNavigationEdge.left,
          FoldableNavigationEdge.bottom,
          FoldableNavigationEdge.right,
          FoldableNavigationEdge.bottom,
        ]) {
          await pumpTab(
            tester,
            tab: 0,
            log: log,
            navigationKey: key,
            edge: edge,
            extendBody: extendBody,
          );
          // Mid-animation: the slot that is left still shows a copy.
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull, reason: '$edge');
          expect(keyedState(tester, key), same(state), reason: '$edge');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$edge');
          expect(keyedState(tester, key), same(state), reason: '$edge');
        }
        // A new scaffold on a side, mid-way through a move.
        await pumpTab(
          tester,
          tab: 1,
          log: log,
          navigationKey: key,
          edge: FoldableNavigationEdge.left,
          extendBody: extendBody,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await pumpTab(
          tester,
          tab: 2,
          log: log,
          navigationKey: key,
          edge: FoldableNavigationEdge.bottom,
          extendBody: extendBody,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(keyedState(tester, key), same(state));
        expect(log.updates, [(0, 1), (1, 2)]);
      });
    });
  }

  for (final withKey in [true, false]) {
    testWidgets(
      'a NavigationBar ${withKey ? 'animates' : 'jumps'} to the new tab of a '
      'new scaffold ${withKey ? 'with' : 'without'} the key',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = withKey ? GlobalKey() : null;
        Widget tab(int index) => MaterialApp(
          home: FoldableScaffold(
            key: ValueKey(index),
            navigationKey: key,
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.person), label: 'Users'),
              ],
            ),
            body: Text('tab $index'),
          ),
        );
        await tester.pumpWidget(tab(0));
        await tester.pumpAndSettle();
        final bar = tester.element(find.byType(NavigationBar));

        await tester.pumpWidget(tab(1));
        expect(
          identical(tester.element(find.byType(NavigationBar)), bar),
          withKey,
        );
        // With the key the indicator moves from the old destination to the
        // new one; without it the new bar starts on the new destination.
        expect(tester.hasRunningAnimations, withKey);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
