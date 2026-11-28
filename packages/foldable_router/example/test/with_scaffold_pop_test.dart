// Popping the detail page of the Users tab of `with_scaffold.dart` while it
// shows two panes: the list stays where it is (and grows when the layout goes
// to one pane), the detail leaves from its pane, frame by frame, with nothing
// jumping at the start or at the end.
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_router_example/pages/users_pages.dart';
import 'package:foldable_router_example/session.dart';
import 'package:foldable_router_example/with_scaffold.dart';
import 'package:material_ui/material_ui.dart';

late FoldableRouter router;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

/// The part of the first match of [finder] that is painted, in global
/// coordinates: its box cut by every clip above it (the pane of the page
/// included), [Rect.zero] when an ancestor does not paint it (a page faded out
/// completely), null when it is not in the tree.
Rect? visibleRect(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return null;
  final RenderBox box = tester.renderObject<RenderBox>(finder.first);
  Rect rect = Offset.zero & box.size;
  RenderObject child = box;
  while (child.parent != null) {
    final RenderObject parent = child.parent!;
    if (!parent.paintsChild(child)) return Rect.zero;
    final Matrix4 transform = Matrix4.identity();
    parent.applyPaintTransform(child, transform);
    rect = MatrixUtils.transformRect(transform, rect);
    final Rect? clip = parent.describeApproximatePaintClip(child);
    if (clip != null) rect = rect.intersect(clip);
    child = parent;
  }
  return rect.width <= 0 || rect.height <= 0 ? Rect.zero : rect;
}

/// What the screen shows of the list and of the detail, one entry per frame.
Future<List<(Rect list, Rect? detail)>> pop(WidgetTester tester) async {
  final Finder list = find.byType(UsersPage);
  final Finder detail = find.byType(UserPage);
  final samples = <(Rect, Rect?)>[
    (visibleRect(tester, list)!, visibleRect(tester, detail)),
  ];
  router.pop();
  // Small steps over the pane animation and the page transition.
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 4));
    samples.add((visibleRect(tester, list)!, visibleRect(tester, detail)));
  }
  await tester.pumpAndSettle();
  samples.add((visibleRect(tester, list)!, visibleRect(tester, detail)));
  return samples;
}

Future<void> pumpUser(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  router = createRouter();
  await tester.pumpWidget(WithScaffoldApp(router: router));
  await settle(tester);
  final Future<void> opened = router.open(const UserRoute(id: '7'));
  await settle(tester);
  await opened;
  expect(find.byType(UserPage), findsOneWidget);
}

const _platforms = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.iOS,
});

void main() {
  setUp(session.reset);
  tearDown(session.reset);

  testWidgets(
    'a fold narrower than the split: popping the detail closes its pane '
    'smoothly',
    variant: _platforms,
    (WidgetTester tester) async {
      // Half open around a vertical hinge, narrower than the 840 of the split:
      // two panes only while a user is open, one pane after the pop.
      tester.view.displayFeatures = const [
        DisplayFeature(
          bounds: Rect.fromLTRB(400, 0, 400, 600),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];
      await pumpUser(tester, const Size(800, 600));
      final samples = await pop(tester);

      final Rect start = samples.first.$1;
      var step = 0.0;
      for (var i = 1; i < samples.length; i++) {
        final (Rect list, Rect? detail) = samples[i];
        final Rect before = samples[i - 1].$1;
        // The list does not move (no parallax of the page below, which a
        // one-pane tab would play): it only grows towards the closed pane.
        expect(list.left, moreOrLessEquals(start.left), reason: 'frame $i');
        expect(list.top, moreOrLessEquals(start.top), reason: 'frame $i');
        expect(
          list.right,
          greaterThanOrEqualTo(before.right - 0.01),
          reason: 'frame $i',
        );
        final double delta = list.right - before.right;
        if (delta > step) step = delta;
        // The detail leaves from its own pane: it never covers the list.
        if (detail != null && detail != Rect.zero) {
          expect(
            detail.left,
            greaterThanOrEqualTo(list.right - 0.5),
            reason: 'frame $i: the detail covers the list',
          );
        }
      }
      // Growing by small steps (4 ms frames over a 250 ms animation), not in
      // one jump.
      expect(step, lessThan(40));
      expect(samples.last.$1.right, 800);
      expect(samples.last.$2, isNull);
    },
  );

  testWidgets(
    'a wide window: popping the detail leaves the list in place',
    variant: _platforms,
    (WidgetTester tester) async {
      await pumpUser(tester, const Size(1200, 800));
      final samples = await pop(tester);
      final Rect start = samples.first.$1;
      final Rect pane = samples.first.$2!;
      for (var i = 1; i < samples.length; i++) {
        final (Rect list, Rect? detail) = samples[i];
        expect(list, start, reason: 'frame $i');
        if (detail != null && detail != Rect.zero) {
          // Inside the right pane, cut to it.
          expect(detail.left, greaterThanOrEqualTo(pane.left - 0.5));
          expect(detail.right, lessThanOrEqualTo(pane.right + 0.5));
        }
      }
      expect(find.byKey(const Key('no-user-selected')), findsOneWidget);
    },
  );
}
