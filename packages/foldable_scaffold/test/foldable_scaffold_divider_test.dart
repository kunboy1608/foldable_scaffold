import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps a desktop [FoldableScaffold] in a window of [size], with a secondary
/// body.
Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 600),
  List<double> snapWidths = const [],
  bool secondary = true,
  Widget? floatingActionButton,
  Widget? drawer,
  Widget? endDrawer,
  Widget? bottomSheet,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      home: FoldableScaffold(
        snapWidths: snapWidths,
        hasSecondaryBody: secondary,
        floatingActionButton: floatingActionButton,
        drawer: drawer,
        endDrawer: endDrawer,
        bottomSheet: bottomSheet,
        bodyBuilder: (_, _) => const Text('body'),
        secondaryBodyBuilder: (_, _) => const Text('secondary'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _width(WidgetTester tester, String key) {
  return tester.getSize(find.byKey(Key(key), skipOffstage: false)).width;
}

void main() {
  group('Scaffold slots', () {
    testWidgets('shows the floating action button and the sheets', (
      tester,
    ) async {
      await _pump(
        tester,
        floatingActionButton: const FloatingActionButton(
          onPressed: null,
          child: Text('fab'),
        ),
        bottomSheet: const Text('sheet'),
      );

      expect(find.text('fab'), findsOneWidget);
      expect(find.text('sheet'), findsOneWidget);
    });

    testWidgets('opens the drawer and the end drawer', (tester) async {
      await _pump(
        tester,
        drawer: const Drawer(child: Text('drawer')),
        endDrawer: const Drawer(child: Text('end drawer')),
      );
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));

      expect(find.text('drawer'), findsNothing);
      scaffold.openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('drawer'), findsOneWidget);

      scaffold.closeDrawer();
      await tester.pumpAndSettle();
      scaffold.openEndDrawer();
      await tester.pumpAndSettle();
      expect(find.text('end drawer'), findsOneWidget);
    });
  });

  group('snapWidths', () {
    // No navigation: the panes share 1400 - 24 (the divider) = 1376, and the
    // secondary body starts at half of 1400.
    testWidgets('the secondary body snaps to a width near the release', (
      tester,
    ) async {
      await _pump(tester, snapWidths: const [360]);

      // The drag loses the touch slop: the secondary body ends near 380.
      await tester.drag(
        find.byKey(const Key('pane_divider')),
        const Offset(340, 0),
      );
      await tester.pumpAndSettle();

      expect(_width(tester, 'secondary_body_builder'), closeTo(360, 0.01));
      expect(_width(tester, 'body_builder'), closeTo(1016, 0.01));
    });

    testWidgets('the body snaps too, whichever pane is nearer', (tester) async {
      await _pump(tester, snapWidths: const [360]);

      await tester.drag(
        find.byKey(const Key('pane_divider')),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle();

      expect(_width(tester, 'body_builder'), closeTo(360, 0.01));
      expect(_width(tester, 'secondary_body_builder'), closeTo(1016, 0.01));
    });

    testWidgets('a release far from every width stays where it is', (
      tester,
    ) async {
      await _pump(tester, snapWidths: const [360, 412]);

      await tester.drag(
        find.byKey(const Key('pane_divider')),
        const Offset(100, 0),
      );
      await tester.pumpAndSettle();

      final secondary = _width(tester, 'secondary_body_builder');
      expect(secondary, greaterThan(560));
      expect(secondary, lessThan(700));
    });

    testWidgets('does not snap by default', (tester) async {
      await _pump(tester);

      await tester.drag(
        find.byKey(const Key('pane_divider')),
        const Offset(340, 0),
      );
      await tester.pumpAndSettle();

      expect(_width(tester, 'secondary_body_builder'), isNot(360));
    });
  });
}
