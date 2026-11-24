// A NavigationRail has a SafeArea of its own. The scaffold already applied the
// system inset of the edge, so the rail must keep its room: on iPhone Duo's
// outer screen (678x466, strip 84 on the start edge) it used to be left with
// no width and drew outside the strip.
import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect;

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
  testWidgets(
    'a labelled rail keeps its width inside the strip (outer, start)',
    (tester) async {
      tester.view.physicalSize = const Size(678, 466);
      tester.view.devicePixelRatio = 1;
      const padding = FakeViewPadding(left: 84, bottom: 34);
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      tester.view.displayFeatures = [
        _cutout(29.33, 29.33, 66.33, 66.33),
        _cutout(0, 0, 84, 82),
      ];
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: FoldableVerticalBarScope(
            edge: FoldableNavigationEdge.start,
            child: FoldableScaffold(
              appBar: AppBar(title: const Text('Sent')),
              navigationBuilder: (context, placement, constraints, _) {
                return NavigationRail(
                  selectedIndex: 0,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: 1,
                  minWidth: constraints.maxWidth < 72
                      ? constraints.maxWidth
                      : 72,
                  destinations: [
                    for (final label in ['Inbox', 'Sent', 'Starred', 'Trash'])
                      NavigationRailDestination(
                        icon: const Icon(Icons.inbox),
                        label: Text(label),
                      ),
                  ],
                );
              },
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder inRail(Finder f) =>
          find.descendant(of: find.byType(NavigationRail), matching: f);
      final strip = tester.getRect(
        find.byKey(const Key('primary_navigation_builder')),
      );
      expect(strip.left, 0);
      expect(strip.width, 84);
      for (final label in ['Inbox', 'Sent', 'Starred', 'Trash']) {
        final rect = tester.getRect(inRail(find.text(label)));
        expect(rect.width, greaterThan(20), reason: label);
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(84), reason: label);
      }
      for (var i = 0; i < 4; i++) {
        final icon = tester.getRect(inRail(find.byType(Icon)).at(i));
        expect(icon.width, 24);
        expect(icon.center.dx, closeTo(42, 0.5));
      }
      // Below the camera (82) and above the home indicator (466 - 34).
      final last = tester.getRect(inRail(find.text('Trash')));
      expect(last.bottom, lessThanOrEqualTo(466 - 34));
    },
  );
}
