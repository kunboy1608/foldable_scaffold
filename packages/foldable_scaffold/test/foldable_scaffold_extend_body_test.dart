// extendBody: the navigation is painted above the panes, and above what is
// drawn over the scaffold in the same route (the pages of foldable_router), and
// a rail on the side gets the pane next to it extended under it.
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:foldable_scaffold/src/foldable_scaffold_divider.dart'
    show PaneDivider;
import 'package:foldable_scaffold/src/foldable_scaffold_layout.dart';
import 'package:material_ui/material_ui.dart';

const _destinations = [
  NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
  NavigationDestination(icon: Icon(Icons.send), label: 'Sent'),
];

/// What a pane saw: its `MediaQuery.padding`.
class _Seen {
  EdgeInsets? padding;
}

Widget _pane(String key, _Seen seen) => Builder(
  builder: (context) {
    seen.padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: const Color(0xFF00FF00),
      child: SizedBox.expand(key: Key(key)),
    );
  },
);

/// The layer a [RepaintBoundary] around [finder] paints into, and its index
/// in the paint order of the whole layer tree.
int _layerIndex(WidgetTester tester, Finder finder) {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
  );
  final layer = boundary.debugLayer!;
  final index = tester.layers.indexOf(layer);
  expect(index, isNonNegative);
  return index;
}

void main() {
  group('a bottom navigation with extendBody', () {
    Future<List<String>> pumpCovered(
      WidgetTester tester, {
      required bool extendBody,
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Stack(
            children: [
              FoldableScaffold(
                extendBody: extendBody,
                body: const SizedBox.expand(),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: 0,
                  onDestinationSelected: (i) => taps.add('navigation $i'),
                  destinations: _destinations,
                ),
              ),
              // What foldable_router does: a page drawn over the whole layout
              // of the scaffold, in the same route.
              Positioned.fill(
                child: RepaintBoundary(
                  child: GestureDetector(
                    key: const Key('cover'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps.add('cover'),
                    child: const ColoredBox(color: Color(0x80FF0000)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      return taps;
    }

    testWidgets('is hit before what covers the scaffold', (tester) async {
      final taps = await pumpCovered(tester, extendBody: true);

      await tester.tap(find.text('Sent'));
      expect(taps, ['navigation 1']);

      await tester.tapAt(const Offset(200, 300));
      expect(taps, ['navigation 1', 'cover']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is painted after what covers the scaffold', (tester) async {
      await pumpCovered(tester, extendBody: true);

      expect(
        _layerIndex(tester, find.byType(NavigationBar)),
        greaterThan(_layerIndex(tester, find.byKey(const Key('cover')))),
      );
    });

    testWidgets('keeps its slot: same rect, same padding for the body', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      final seen = _Seen();
      await tester.pumpWidget(
        MaterialApp(
          home: FoldableScaffold(
            extendBody: true,
            body: _pane('body', seen),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: _destinations,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byType(NavigationBar));
      expect(bar.bottom, 800);
      expect(bar.width, 400);
      // Scaffold's extendBody: the body goes under the bar and is told how
      // tall the bar is.
      expect(tester.getRect(find.byKey(const Key('body'))).bottom, 800);
      expect(seen.padding!.bottom, bar.height);
    });

    testWidgets('without extendBody stays in place, under the cover', (
      tester,
    ) async {
      final taps = await pumpCovered(tester, extendBody: false);

      await tester.tap(find.text('Sent'), warnIfMissed: false);
      expect(taps, ['cover']);
    });

    testWidgets('is painted in place without an Overlay', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          // Above the Navigator, so there is no Overlay.
          builder: (context, _) => FoldableScaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: GestureDetector(
              onTap: () => taps.add('navigation'),
              child: const SizedBox(
                key: Key('bar'),
                width: double.infinity,
                height: 80,
                child: ColoredBox(color: Color(0xFF0000FF)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('bar'))).bottom, 800);
      await tester.tap(find.byKey(const Key('bar')));
      expect(taps, ['navigation']);
    });

    testWidgets('follows the bar when it switches in and out', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var edge = FoldableNavigationEdge.bottom;
      late StateSetter setState;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return FoldableScaffold(
                extendBody: true,
                navigationPlacement: (_) => FoldableNavigationPlacement(edge),
                navigationBuilder: (context, placement, constraints, padding) =>
                    placement.isSide
                    ? NavigationRail(
                        selectedIndex: 0,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.inbox),
                            label: Text('Inbox'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.send),
                            label: Text('Sent'),
                          ),
                        ],
                      )
                    : NavigationBar(
                        selectedIndex: 0,
                        destinations: _destinations,
                      ),
                body: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final next in [
        FoldableNavigationEdge.left,
        FoldableNavigationEdge.right,
        FoldableNavigationEdge.bottom,
        FoldableNavigationEdge.top,
        FoldableNavigationEdge.bottom,
      ]) {
        setState(() => edge = next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$next');
      }
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('can be switched on and off', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var extendBody = true;
      late StateSetter setState;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return FoldableScaffold(
                extendBody: extendBody,
                primaryNavigation: const SizedBox.expand(),
                bottomNavigationBar: const SizedBox(height: 80),
                body: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final next in [false, true, false]) {
        setState(() => extendBody = next);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'extendBody $next');
      }
    });
  });

  group('a rail with extendBody', () {
    /// Two panes 1300 wide on a desktop, the navigation on [edge] in a slot of
    /// [extent] (no system inset).
    Future<({_Seen body, _Seen secondary})> pumpRail(
      WidgetTester tester, {
      required bool extendBody,
      FoldableNavigationEdge edge = FoldableNavigationEdge.left,
      TextDirection textDirection = TextDirection.ltr,
      Size size = const Size(1300, 800),
      bool secondary = true,
      List<String>? taps,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final body = _Seen();
      final secondaryBody = _Seen();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: Directionality(
            textDirection: textDirection,
            child: FoldableScaffold(
              extendBody: extendBody,
              navigationPlacement: (_) =>
                  FoldableNavigationPlacement(edge, extent: 80),
              primaryNavigation: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps?.add('rail'),
                child: const ColoredBox(
                  key: Key('rail'),
                  color: Color(0xFF0000FF),
                  child: SizedBox.expand(),
                ),
              ),
              body: GestureDetector(
                onTap: () => taps?.add('body'),
                child: _pane('body', body),
              ),
              secondaryBody: secondary
                  ? _pane('secondary', secondaryBody)
                  : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (body: body, secondary: secondaryBody);
    }

    Rect rectOf(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(Key(key), skipOffstage: false));

    testWidgets('on the left extends the body only, in LTR', (tester) async {
      await pumpRail(tester, extendBody: false);
      final body = rectOf(tester, 'body');
      final secondary = rectOf(tester, 'secondary');
      final divider = tester.getRect(find.byType(PaneDivider));
      expect(body.left, 80);

      final seen = await pumpRail(tester, extendBody: true);
      expect(rectOf(tester, 'body'), Rect.fromLTRB(0, 0, body.right, 800));
      expect(seen.body.padding!.left, 80);
      // The rest of the layout does not move.
      expect(rectOf(tester, 'secondary'), secondary);
      expect(seen.secondary.padding!.left, 0);
      expect(tester.getRect(find.byType(PaneDivider)), divider);
      expect(rectOf(tester, 'rail'), const Rect.fromLTWH(0, 0, 80, 800));
    });

    testWidgets('on the right extends the secondary body, in LTR', (
      tester,
    ) async {
      await pumpRail(
        tester,
        extendBody: false,
        edge: FoldableNavigationEdge.right,
      );
      final body = rectOf(tester, 'body');
      final secondary = rectOf(tester, 'secondary');
      expect(secondary.right, 1220);

      final seen = await pumpRail(
        tester,
        extendBody: true,
        edge: FoldableNavigationEdge.right,
      );
      expect(
        rectOf(tester, 'secondary'),
        Rect.fromLTRB(secondary.left, 0, 1300, 800),
      );
      expect(seen.secondary.padding!.right, 80);
      expect(rectOf(tester, 'body'), body);
      expect(seen.body.padding!.right, 0);
    });

    testWidgets('at the start in RTL (the right) extends the body', (
      tester,
    ) async {
      await pumpRail(
        tester,
        extendBody: false,
        edge: FoldableNavigationEdge.start,
        textDirection: TextDirection.rtl,
      );
      final body = rectOf(tester, 'body');
      final secondary = rectOf(tester, 'secondary');
      expect(body.right, 1220);
      expect(secondary.left, 0);

      final seen = await pumpRail(
        tester,
        extendBody: true,
        edge: FoldableNavigationEdge.start,
        textDirection: TextDirection.rtl,
      );
      expect(rectOf(tester, 'body'), Rect.fromLTRB(body.left, 0, 1300, 800));
      expect(seen.body.padding!.right, 80);
      expect(rectOf(tester, 'secondary'), secondary);
      expect(seen.secondary.padding!.left, 0);
      expect(seen.secondary.padding!.right, 0);
    });

    testWidgets('on the left in RTL extends the secondary body', (
      tester,
    ) async {
      final seen = await pumpRail(
        tester,
        extendBody: true,
        textDirection: TextDirection.rtl,
      );
      expect(rectOf(tester, 'secondary').left, 0);
      expect(seen.secondary.padding!.left, 80);
      expect(rectOf(tester, 'body').right, 1300);
      expect(seen.body.padding!.left, 0);
    });

    testWidgets('extends the one pane shown in a single-pane layout', (
      tester,
    ) async {
      // 900 wide: one pane, the secondary body shown alone.
      final seen = await pumpRail(
        tester,
        extendBody: true,
        size: const Size(900, 800),
      );
      expect(rectOf(tester, 'secondary'), const Rect.fromLTWH(0, 0, 900, 800));
      expect(seen.secondary.padding!.left, 80);
      expect(rectOf(tester, 'body').width, 0);

      final only = await pumpRail(
        tester,
        extendBody: true,
        size: const Size(900, 800),
        secondary: false,
      );
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(0, 0, 900, 800));
      expect(only.body.padding!.left, 80);
    });

    testWidgets('the rail is hit, not the pane under it', (tester) async {
      final taps = <String>[];
      await pumpRail(tester, extendBody: true, taps: taps);

      await tester.tapAt(const Offset(40, 400));
      expect(taps, ['rail']);
      await tester.tapAt(const Offset(300, 400));
      expect(taps, ['rail', 'body']);
    });

    testWidgets('the extension follows the rail while it animates', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1300, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var edge = FoldableNavigationEdge.left;
      late StateSetter setState;
      final seen = _Seen();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return FoldableScaffold(
                extendBody: true,
                navigationPlacement: (_) =>
                    FoldableNavigationPlacement(edge, extent: 80),
                primaryNavigation: const ColoredBox(
                  key: Key('rail'),
                  color: Color(0xFF0000FF),
                  child: SizedBox.expand(),
                ),
                bottomNavigationBar: const SizedBox(height: 80),
                body: _pane('body', seen),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      setState(() => edge = FoldableNavigationEdge.bottom);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final rail = tester.getRect(find.byKey(const Key('rail')));
      expect(rail.width, inExclusiveRange(0, 80));
      // Still extended under the shrinking rail, to the edge.
      expect(rectOf(tester, 'body').left, 0);
      expect(seen.padding!.left, rail.width);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'body').left, 0);
      expect(seen.padding!.left, 0);
    });

    testWidgets('iPhone Duo: the pane extends under the rail in the strip', (
      tester,
    ) async {
      // Inner screen, landscape, fully open: the strip of 84 on the right.
      tester.view.physicalSize = const Size(951, 669);
      tester.view.devicePixelRatio = 1;
      const padding = FakeViewPadding(right: 84, bottom: 35);
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      tester.view.displayFeatures = [
        const DisplayFeature(
          bounds: Rect.fromLTRB(867, 0, 951, 124),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ];
      addTearDown(tester.view.reset);
      Future<_Seen> pump({required bool extendBody}) async {
        final seen = _Seen();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: FoldableVerticalBarScope(
              edge: FoldableNavigationEdge.end,
              child: FoldableScaffold(
                extendBody: extendBody,
                primaryNavigation: const SizedBox.expand(),
                body: _pane('body', seen),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return seen;
      }

      final inline = await pump(extendBody: false);
      expect(rectOf(tester, 'body').right, 867);
      expect(inline.padding!.right, 0);

      final seen = await pump(extendBody: true);
      expect(rectOf(tester, 'body').left, 0);
      expect(rectOf(tester, 'body').right, 951);
      // The slot is the strip: the system inset it covers.
      expect(seen.padding!.right, 84);
      expect(seen.padding!.bottom, 35);
    });
  });

  group('paneReaches', () {
    const ltr = TextDirection.ltr;
    const rtl = TextDirection.rtl;
    const split = PaneGeometry(
      primaryExtent: 500,
      dividerExtent: 24,
      secondaryExtent: 500,
    );

    test('side by side: the outer pane of each side', () {
      expect(paneReaches(split, ltr, left: 80, right: 60), (
        primaryLeft: 80.0,
        primaryRight: 0.0,
        secondaryLeft: 0.0,
        secondaryRight: 60.0,
      ));
      expect(paneReaches(split, rtl, left: 80, right: 60), (
        primaryLeft: 0.0,
        primaryRight: 60.0,
        secondaryLeft: 80.0,
        secondaryRight: 0.0,
      ));
    });

    test('one pane shown: it has both edges', () {
      const secondaryOnly = PaneGeometry(
        primaryExtent: 0,
        dividerExtent: 0,
        secondaryExtent: 1024,
      );
      expect(paneReaches(secondaryOnly, ltr, left: 80, right: 60), (
        primaryLeft: 0.0,
        primaryRight: 0.0,
        secondaryLeft: 80.0,
        secondaryRight: 60.0,
      ));
      const primaryOnly = PaneGeometry(
        primaryExtent: 1024,
        dividerExtent: 0,
        secondaryExtent: 0,
      );
      expect(paneReaches(primaryOnly, rtl, left: 80, right: 60), (
        primaryLeft: 80.0,
        primaryRight: 60.0,
        secondaryLeft: 0.0,
        secondaryRight: 0.0,
      ));
    });

    test('a pane sliding out hands the edge over progressively', () {
      // The secondary body is 30 wide on its way out, the divider gone: the
      // body reaches the part of the right slot that nothing covers.
      const leaving = PaneGeometry(
        primaryExtent: 994,
        dividerExtent: 0,
        secondaryExtent: 30,
      );
      expect(paneReaches(leaving, ltr, left: 0, right: 80), (
        primaryLeft: 0.0,
        primaryRight: 50.0,
        secondaryLeft: 0.0,
        secondaryRight: 80.0,
      ));
      expect(paneReaches(leaving, rtl, left: 80, right: 0), (
        primaryLeft: 50.0,
        primaryRight: 0.0,
        secondaryLeft: 80.0,
        secondaryRight: 0.0,
      ));
    });

    test('stacked: both panes span the width', () {
      const stacked = PaneGeometry(
        axis: Axis.vertical,
        primaryExtent: 300,
        dividerExtent: 20,
        secondaryExtent: 300,
      );
      expect(paneReaches(stacked, ltr, left: 80, right: 60), (
        primaryLeft: 80.0,
        primaryRight: 60.0,
        secondaryLeft: 80.0,
        secondaryRight: 60.0,
      ));
    });
  });
}
