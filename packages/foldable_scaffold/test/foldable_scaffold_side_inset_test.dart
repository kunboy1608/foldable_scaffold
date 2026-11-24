// The slot of a navigation beside the panes is the extent plus the system inset
// of its edge; the navigation itself must stay in the extent.
import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

DisplayFeature _cutout(double l, double t, double r, double b) {
  return DisplayFeature(
    bounds: Rect.fromLTRB(l, t, r, b),
    type: DisplayFeatureType.cutout,
    state: DisplayFeatureState.unknown,
  );
}

void main() {
  const landscape = Size(951, 669);
  const content = Key('content');
  const body = Key('body');

  EdgeInsets? seenPadding;
  BoxConstraints? seenConstraints;

  Future<void> pump(
    WidgetTester tester, {
    FakeViewPadding padding = FakeViewPadding.zero,
    List<DisplayFeature> features = const [],
    FoldableNavigationPlacement? placement,
    FoldableNavigationEdge? verticalBar,
    TextDirection direction = TextDirection.ltr,
    bool avoidCutouts = true,
    bool navigationRail = false,
  }) async {
    seenPadding = null;
    seenConstraints = null;
    tester.view.physicalSize = landscape;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    tester.view.displayFeatures = features;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Directionality(
          textDirection: direction,
          child: FoldableVerticalBarScope(
            edge: verticalBar,
            child: FoldableScaffold(
              avoidCutouts: avoidCutouts,
              appBar: AppBar(title: const Text('title')),
              navigationPlacement: placement == null ? null : (_) => placement,
              navigationBuilder: (context, p, constraints, insets) {
                seenPadding = insets;
                seenConstraints = constraints;
                if (!p.isSide) return const SizedBox(height: 40);
                if (navigationRail) {
                  return NavigationRail(
                    selectedIndex: 0,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.inbox, key: content),
                        label: Text('Inbox'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.send),
                        label: Text('Sent'),
                      ),
                    ],
                  );
                }
                return const Center(
                  child: SizedBox(key: content, width: 24, height: 24),
                );
              },
              body: const SizedBox.expand(key: body),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

  group('a side navigation stays out of the system inset', () {
    testWidgets('the dev.8 layout: a rail beside the strip, not inside it', (
      tester,
    ) async {
      await pump(
        tester,
        padding: const FakeViewPadding(right: 84, bottom: 35),
        features: [_cutout(867, 0, 951, 124)],
        placement: const FoldableNavigationPlacement.end(),
        navigationRail: true,
      );

      expect(tester.takeException(), isNull);
      // The icon is in the extent, left of 951 - 84 = 867.
      final icon = rect(tester, content);
      expect(icon.right, lessThanOrEqualTo(867));
      // The slot is extent + inset, and so are the panes.
      final slot = tester.getRect(
        find.byKey(const Key('primary_navigation_builder')),
      );
      expect(slot.right, 867);
      expect(slot.width, 72);
      expect(rect(tester, body).right, 951 - 156);
      expect(rect(tester, body).width, 951 - 156);
    });

    testWidgets('a Center in the navigation is centred in the extent', (
      tester,
    ) async {
      await pump(
        tester,
        padding: const FakeViewPadding(right: 84, bottom: 35),
        placement: FoldableNavigationPlacement.right(),
      );

      expect(rect(tester, content).center.dx, 867 - 36);
      expect(seenConstraints!.maxWidth, 72);
    });

    testWidgets('the left edge (a notch in landscape on Android)', (
      tester,
    ) async {
      await pump(
        tester,
        padding: const FakeViewPadding(left: 48),
        placement: FoldableNavigationPlacement.left(),
      );

      expect(rect(tester, content).left, greaterThanOrEqualTo(48));
      expect(rect(tester, content).center.dx, 48 + 36);
      expect(rect(tester, body).left, 48 + 72);
      expect(seenConstraints!.maxWidth, 72);
    });

    testWidgets('RTL: start is on the right and uses padding.right', (
      tester,
    ) async {
      await pump(
        tester,
        padding: const FakeViewPadding(left: 20, right: 84),
        placement: FoldableNavigationPlacement.start(),
        direction: TextDirection.rtl,
      );

      expect(rect(tester, content).right, lessThanOrEqualTo(951 - 84));
      expect(rect(tester, body).right, 951 - 156);
      expect(seenPadding, const EdgeInsets.only(left: 20));
    });

    testWidgets('the padding the builder gets has the padded side at 0', (
      tester,
    ) async {
      const system = FakeViewPadding(left: 10, top: 20, right: 84, bottom: 35);
      await pump(
        tester,
        padding: system,
        placement: FoldableNavigationPlacement.right(),
      );
      expect(seenPadding, const EdgeInsets.fromLTRB(10, 20, 0, 35));

      await pump(
        tester,
        padding: system,
        placement: FoldableNavigationPlacement.left(),
      );
      expect(seenPadding, const EdgeInsets.fromLTRB(0, 20, 84, 35));
    });

    testWidgets('a bar still gets the whole padding', (tester) async {
      await pump(
        tester,
        padding: const FakeViewPadding(
          left: 10,
          top: 20,
          right: 84,
          bottom: 35,
        ),
        placement: FoldableNavigationPlacement.bottom(),
      );
      expect(seenPadding, const EdgeInsets.fromLTRB(10, 20, 84, 35));
    });

    testWidgets('without a system inset nothing changes', (tester) async {
      await pump(tester, placement: FoldableNavigationPlacement.right());

      final slot = tester.getRect(
        find.byKey(const Key('primary_navigation_builder')),
      );
      expect(slot, const Rect.fromLTRB(951 - 72, 56, 951, 669));
      expect(rect(tester, content).center.dx, 951 - 36);
      expect(seenPadding, EdgeInsets.zero);
      expect(seenConstraints!.maxWidth, 72);
    });

    testWidgets('avoidCutouts: false still pads the system inset', (
      tester,
    ) async {
      await pump(
        tester,
        padding: const FakeViewPadding(right: 84, bottom: 35),
        features: [_cutout(867, 0, 951, 124)],
        placement: FoldableNavigationPlacement.right(),
        avoidCutouts: false,
      );

      expect(rect(tester, content).right, lessThanOrEqualTo(867));
      expect(rect(tester, body).width, 951 - 156);
      expect(seenPadding, const EdgeInsets.only(bottom: 35));
    });
  });
}
