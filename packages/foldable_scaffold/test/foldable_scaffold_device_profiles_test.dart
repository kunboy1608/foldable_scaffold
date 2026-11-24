// Tests of FoldableScaffold against the numbers of real devices.
//
// The numbers are NOT here yet. They come from the simulator of the device
// (Device Hub of Xcode), and must not be guessed: every size and display
// feature below is `null` until someone fills it in. A profile with a null
// value is skipped, with the reason; once it is filled in, its tests run by
// themselves. To fill one in, edit the constants of the table below and
// nothing else.
//
// What a filled profile checks:
//
//  * the scaffold lays out without an overflow, with an app bar and a
//    navigation;
//  * the navigation is where the default placement puts it (a bar below the
//    panes under [FoldableBreakpoints.rail], a rail on the start side from
//    there, or on the side of the vertical bars when the profile says which);
//  * around a separating fold (a hinge, or a half-open fold) the body and the
//    secondary body are on each side of it: side by side for a vertical fold,
//    stacked for a horizontal one, whenever each side is at least minBodySize.
import 'dart:ui' show DisplayFeature;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// A device, in a pose, as the platform reports it to Flutter.
class DeviceProfile {
  const DeviceProfile({
    required this.name,
    required this.windowSize,
    required this.features,
    required this.verticalBarEdge,
  });

  /// What the profile is, for the name of the tests.
  final String name;

  /// The size of the Flutter view, in logical pixels. Null until filled in.
  final Size? windowSize;

  /// `MediaQuery.displayFeatures` of the pose, in logical pixels of the window:
  /// the hinge or the fold, and the cutouts. An empty list means the device
  /// reports none in this pose; null means it has not been filled in.
  final List<DisplayFeature>? features;

  /// The side of the vertical bars the system asks for in this pose
  /// (`verticalBarEdge` in UIKit), or null when it asks for none. Only
  /// meaningful for a profile that is filled in.
  final FoldableNavigationEdge? verticalBarEdge;

  /// Whether the numbers of the profile have been filled in.
  bool get isFilled => windowSize != null && features != null;
}

// ---------------------------------------------------------------------------
// THE TABLE. Fill in the constants; leave the rest alone.
//
// Where a value is to be read: the size is the size of the view in the
// simulator (logical pixels), the features are the hinge/fold of the pose
// (`DisplayFeature(bounds: Rect.fromLTRB(...), type: ..., state: ...)`, in
// logical pixels of the window), and the vertical bar edge is what the system
// reports for the pose (`FoldableNavigationEdge.left`, `.right`, `.start`, `.end`,
// or null for none).
// ---------------------------------------------------------------------------

// iPhone Duo, outer display.
const Size? _duoOuterSize = null; // TODO(user): điền từ Device Hub của Xcode
const List<DisplayFeature>? _duoOuterFeatures =
    null; // TODO(user): điền từ Device Hub của Xcode
const FoldableNavigationEdge? _duoOuterVerticalBar =
    null; // TODO(user): điền từ Device Hub của Xcode

// iPhone Duo, inner display, portrait, fully open.
const Size? _duoInnerPortraitSize =
    null; // TODO(user): điền từ Device Hub của Xcode
const List<DisplayFeature>? _duoInnerPortraitFeatures =
    null; // TODO(user): điền từ Device Hub của Xcode
const FoldableNavigationEdge? _duoInnerPortraitVerticalBar =
    null; // TODO(user): điền từ Device Hub của Xcode

// iPhone Duo, inner display, landscape, fully open.
const Size? _duoInnerLandscapeSize =
    null; // TODO(user): điền từ Device Hub của Xcode
const List<DisplayFeature>? _duoInnerLandscapeFeatures =
    null; // TODO(user): điền từ Device Hub của Xcode
const FoldableNavigationEdge? _duoInnerLandscapeVerticalBar =
    null; // TODO(user): điền từ Device Hub của Xcode

// iPhone Duo, inner display, partially folded: a horizontal hinge.
const Size? _duoInnerHalfFoldedSize =
    null; // TODO(user): điền từ Device Hub của Xcode
const List<DisplayFeature>? _duoInnerHalfFoldedFeatures =
    null; // TODO(user): điền từ Device Hub của Xcode
const FoldableNavigationEdge? _duoInnerHalfFoldedVerticalBar =
    null; // TODO(user): điền từ Device Hub của Xcode

const deviceProfiles = <DeviceProfile>[
  DeviceProfile(
    name: 'iPhone Duo outer display',
    windowSize: _duoOuterSize,
    features: _duoOuterFeatures,
    verticalBarEdge: _duoOuterVerticalBar,
  ),
  DeviceProfile(
    name: 'iPhone Duo inner display, portrait, fully open',
    windowSize: _duoInnerPortraitSize,
    features: _duoInnerPortraitFeatures,
    verticalBarEdge: _duoInnerPortraitVerticalBar,
  ),
  DeviceProfile(
    name: 'iPhone Duo inner display, landscape, fully open',
    windowSize: _duoInnerLandscapeSize,
    features: _duoInnerLandscapeFeatures,
    verticalBarEdge: _duoInnerLandscapeVerticalBar,
  ),
  DeviceProfile(
    name: 'iPhone Duo inner display, partially folded (horizontal hinge)',
    windowSize: _duoInnerHalfFoldedSize,
    features: _duoInnerHalfFoldedFeatures,
    verticalBarEdge: _duoInnerHalfFoldedVerticalBar,
  ),
];

// ---------------------------------------------------------------------------
// The tests. Nothing below depends on a device.
// ---------------------------------------------------------------------------

const _minBodySize = 200.0;
const _bottomBarHeight = 80.0;

Finder get _body => find.byKey(const Key('body_builder'), skipOffstage: false);
Finder get _secondary =>
    find.byKey(const Key('secondary_body_builder'), skipOffstage: false);

/// Pumps the scaffold the way an app would on [profile]: an app bar, a
/// navigation (a bar of [_bottomBarHeight] below, or a rail on a side), a body
/// and a secondary body, on the platform of the device.
Future<void> _pumpProfile(WidgetTester tester, DeviceProfile profile) async {
  tester.view.physicalSize = profile.windowSize!;
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = profile.features!;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: FoldableVerticalBarScope(
        edge: profile.verticalBarEdge,
        child: FoldableScaffold(
          minBodySize: _minBodySize,
          appBar: AppBar(title: const Text('title')),
          navigationBuilder: (context, placement, constraints, padding) =>
              placement.isSide
              ? SizedBox.expand(child: Text('nav ${placement.edge.name}'))
              : SizedBox(
                  height: _bottomBarHeight,
                  child: Text('nav ${placement.edge.name}'),
                ),
          body: const Text('body'),
          secondaryBody: const Text('secondary'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The name of the edge of the navigation under the default placement for a
/// scaffold of [profile], said without asking the code under test.
String _expectedNavigationEdge(DeviceProfile profile) {
  final edge = profile.verticalBarEdge;
  if (edge != null && edge.isSide) return edge.name;
  final rail = FoldableBreakpoints.forPlatform(TargetPlatform.iOS).rail;
  return profile.windowSize!.width >= rail ? 'start' : 'bottom';
}

void main() {
  for (final profile in deviceProfiles) {
    group(
      profile.name,
      () {
        testWidgets('lays out without an overflow', (tester) async {
          await _pumpProfile(tester, profile);

          expect(tester.takeException(), isNull);
          expect(
            find.text('nav ${_expectedNavigationEdge(profile)}'),
            findsOne,
          );
        });

        testWidgets('puts the navigation where the default placement says', (
          tester,
        ) async {
          await _pumpProfile(tester, profile);

          final window = profile.windowSize!;
          final nav = tester.getRect(
            find.text('nav ${_expectedNavigationEdge(profile)}'),
          );
          final body = tester.getRect(_body);
          final secondary = tester.getRect(_secondary);
          final panes = body.expandToInclude(secondary);

          switch (_expectedNavigationEdge(profile)) {
            case 'bottom':
              expect(nav.top, greaterThanOrEqualTo(panes.bottom - 0.01));
              expect(nav.bottom, lessThanOrEqualTo(window.height + 0.01));
            case 'start':
            case 'left':
              expect(nav.right, lessThanOrEqualTo(panes.left + 0.01));
            case 'end':
            case 'right':
              expect(nav.left, greaterThanOrEqualTo(panes.right - 0.01));
          }
        });

        testWidgets('puts the two panes on each side of a separating fold', (
          tester,
        ) async {
          await _pumpProfile(tester, profile);

          final window = profile.windowSize!;
          final fold = FoldableFold.fromFeatures(profile.features!, window);
          if (fold == null || !fold.isSeparating) {
            // Nothing to go around: the layout only has to be sound.
            expect(tester.takeException(), isNull);
            return;
          }

          final body = tester.getRect(_body);
          final secondary = tester.getRect(_secondary);
          final bounds = fold.bounds;
          if (fold.isHorizontal) {
            // The panes start under the app bar and, with a bottom bar, end
            // above it.
            final top = tester.getBottomLeft(find.byType(AppBar)).dy;
            final bottom = _expectedNavigationEdge(profile) == 'bottom'
                ? window.height - _bottomBarHeight
                : window.height;
            final stacks =
                bounds.top - top >= _minBodySize &&
                bottom - bounds.bottom >= _minBodySize;
            if (stacks) {
              expect(body.bottom, lessThanOrEqualTo(bounds.top + 0.01));
              expect(secondary.top, greaterThanOrEqualTo(bounds.bottom - 0.01));
              expect(body.left, secondary.left);
              expect(body.width, secondary.width);
            }
          } else {
            final rail = tester.getRect(
              find.byKey(const Key('primary_navigation_builder')),
            );
            final railEdge = _expectedNavigationEdge(profile);
            final left = railEdge == 'start' || railEdge == 'left'
                ? rail.right
                : 0.0;
            final splits =
                bounds.left - left >= _minBodySize &&
                window.width - bounds.right >= _minBodySize;
            if (splits) {
              expect(body.right, lessThanOrEqualTo(bounds.left + 0.01));
              expect(secondary.left, greaterThanOrEqualTo(bounds.right - 0.01));
            }
          }
        });
      },
      skip: profile.isFilled
          ? false
          : 'The numbers of "${profile.name}" are not filled in yet: '
                'fill in its size and display features in '
                'test/foldable_scaffold_device_profiles_test.dart '
                '(from the Device Hub of Xcode) and this test runs.',
    );
  }
}
