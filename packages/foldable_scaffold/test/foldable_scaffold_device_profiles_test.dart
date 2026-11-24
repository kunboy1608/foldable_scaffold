// Tests of FoldableScaffold against the numbers of real devices.
//
// The numbers below were read on an iPhone Duo with the "Platform data" button
// of the example (FoldablePlatformScope), one block per pose (see "report
// iPhone Duo.rtf" in this folder): the size of the Flutter view, the display
// features the scope gives to MediaQuery (the active regions only: a division is
// a fold, an occlusion is a cutout) and the side of the vertical bars
// (`verticalBarEdge`). They must not be guessed: a profile whose size or
// features are `null` is skipped, with the reason, and runs by itself once it is
// filled in. To add a pose, add its constants to the table below and nothing
// else.
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
import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect;

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
    this.padding = EdgeInsets.zero,
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

  /// `MediaQuery.padding` of the pose (the system insets), in logical pixels:
  /// the "view padding (raw ...)" line of the "Platform data" button. Zero
  /// until it is read on the device.
  final EdgeInsets padding;

  /// Whether the numbers of the profile have been filled in.
  bool get isFilled => windowSize != null && features != null;
}

// ---------------------------------------------------------------------------
// THE TABLE. Add a pose by adding its constants and one DeviceProfile.
//
// The size is the size of the view (logical pixels), the features are the
// active regions as FoldablePlatformScope gives them to MediaQuery (logical
// pixels of the window; the frames already include the margins around the
// fold and the cameras), and the vertical bar edge is what the system reports
// for the pose (`FoldableNavigationEdge.start` / `.end` for leading /
// trailing, null for none).
// ---------------------------------------------------------------------------

/// A camera or the Dynamic Island: an active occlusion.
DisplayFeature _cutout(double left, double top, double right, double bottom) {
  return DisplayFeature(
    bounds: Rect.fromLTRB(left, top, right, bottom),
    type: DisplayFeatureType.cutout,
    state: DisplayFeatureState.unknown,
  );
}

/// The fold of a device that is partly open: an active division.
DisplayFeature _fold(double left, double top, double right, double bottom) {
  return DisplayFeature(
    bounds: Rect.fromLTRB(left, top, right, bottom),
    type: DisplayFeatureType.fold,
    state: DisplayFeatureState.postureHalfOpened,
  );
}

// iPhone Duo, outer display (closed), portrait. Camera at the top right.
const Size? _duoOuterPortraitSize = Size(466, 678);
final List<DisplayFeature>? _duoOuterPortraitFeatures = [
  _cutout(399.67, 29.33, 436.67, 66.33),
  _cutout(382, 0, 466, 174),
];
const FoldableNavigationEdge? _duoOuterPortraitVerticalBar =
    FoldableNavigationEdge.end;

// iPhone Duo, outer display, rotated: camera on the right side.
const Size? _duoOuterLandscapeEndSize = Size(678, 466);
final List<DisplayFeature>? _duoOuterLandscapeEndFeatures = [
  _cutout(611.67, 399.67, 648.67, 436.67),
  _cutout(594, 384, 678, 466),
];
const FoldableNavigationEdge? _duoOuterLandscapeEndVerticalBar =
    FoldableNavigationEdge.end;

// iPhone Duo, outer display, rotated the other way: camera on the left side.
const Size? _duoOuterLandscapeStartSize = Size(678, 466);
final List<DisplayFeature>? _duoOuterLandscapeStartFeatures = [
  _cutout(29.33, 29.33, 66.33, 66.33),
  _cutout(0, 0, 84, 82),
];
const FoldableNavigationEdge? _duoOuterLandscapeStartVerticalBar =
    FoldableNavigationEdge.start;

// iPhone Duo, inner display, portrait, fully open: the division is inactive,
// so the only feature is the camera. No vertical bar.
const Size? _duoInnerPortraitSize = Size(669, 951);
final List<DisplayFeature>? _duoInnerPortraitFeatures = [
  _cutout(525, 0, 669, 82),
];
const FoldableNavigationEdge? _duoInnerPortraitVerticalBar = null;

// iPhone Duo, inner display, landscape, fully open.
const Size? _duoInnerLandscapeSize = Size(951, 669);
final List<DisplayFeature>? _duoInnerLandscapeFeatures = [
  _cutout(867, 0, 951, 124),
];
const FoldableNavigationEdge? _duoInnerLandscapeVerticalBar =
    FoldableNavigationEdge.end;

// iPhone Duo, inner display, partially folded like a book: a vertical fold.
const Size? _duoInnerBookSize = Size(951, 669);
final List<DisplayFeature>? _duoInnerBookFeatures = [
  _fold(455.5, 0, 495.5, 669),
  _cutout(867, 0, 951, 124),
];
const FoldableNavigationEdge? _duoInnerBookVerticalBar =
    FoldableNavigationEdge.end;

// iPhone Duo, inner display, partially folded like a laptop: a horizontal fold.
const Size? _duoInnerLaptopSize = Size(669, 951);
final List<DisplayFeature>? _duoInnerLaptopFeatures = [
  _fold(0, 455.5, 669, 495.5),
  _cutout(525, 0, 669, 82),
];
const FoldableNavigationEdge? _duoInnerLaptopVerticalBar = null;

final deviceProfiles = <DeviceProfile>[
  DeviceProfile(
    name: 'iPhone Duo outer display, portrait',
    windowSize: _duoOuterPortraitSize,
    features: _duoOuterPortraitFeatures,
    verticalBarEdge: _duoOuterPortraitVerticalBar,
    // TODO(user): điền padding từ dòng \"view padding\" của nút Platform data
  ),
  DeviceProfile(
    name: 'iPhone Duo outer display, landscape, camera on the right',
    windowSize: _duoOuterLandscapeEndSize,
    features: _duoOuterLandscapeEndFeatures,
    verticalBarEdge: _duoOuterLandscapeEndVerticalBar,
    // TODO(user): điền padding từ dòng \"view padding\" của nút Platform data
  ),
  DeviceProfile(
    name: 'iPhone Duo outer display, landscape, camera on the left',
    windowSize: _duoOuterLandscapeStartSize,
    features: _duoOuterLandscapeStartFeatures,
    verticalBarEdge: _duoOuterLandscapeStartVerticalBar,
    // TODO(user): điền padding từ dòng \"view padding\" của nút Platform data
  ),
  DeviceProfile(
    name: 'iPhone Duo inner display, portrait, fully open',
    windowSize: _duoInnerPortraitSize,
    features: _duoInnerPortraitFeatures,
    verticalBarEdge: _duoInnerPortraitVerticalBar,
    // TODO(user): điền padding từ dòng \"view padding\" của nút Platform data
  ),
  DeviceProfile(
    name: 'iPhone Duo inner display, landscape, fully open',
    windowSize: _duoInnerLandscapeSize,
    features: _duoInnerLandscapeFeatures,
    verticalBarEdge: _duoInnerLandscapeVerticalBar,
    // TODO(user): điền padding từ dòng \"view padding\" của nút Platform data
  ),
  DeviceProfile(
    name:
        'iPhone Duo inner display, partially folded like a book (vertical fold)',
    windowSize: _duoInnerBookSize,
    features: _duoInnerBookFeatures,
    verticalBarEdge: _duoInnerBookVerticalBar,
    // TODO(user): điền padding từ dòng \"view padding\" của nút Platform data
  ),
  DeviceProfile(
    name:
        'iPhone Duo inner display, partially folded like a laptop (horizontal fold)',
    windowSize: _duoInnerLaptopSize,
    features: _duoInnerLaptopFeatures,
    verticalBarEdge: _duoInnerLaptopVerticalBar,
    // TODO(user): điền padding từ dòng \"view padding\" của nút Platform data
  ),
];

// ---------------------------------------------------------------------------
// The tests. Nothing below depends on a device.
// ---------------------------------------------------------------------------

const _minBodySize = 200.0;
const _actionKey = Key('app_bar_action');
const _railHeadKey = Key('rail_head');
const _bottomBarHeight = 80.0;

Finder get _body => find.byKey(const Key('body_builder'), skipOffstage: false);
Finder get _secondary =>
    find.byKey(const Key('secondary_body_builder'), skipOffstage: false);

/// Pumps the scaffold the way an app would on [profile]: an app bar, a
/// navigation (a bar of [_bottomBarHeight] below, or a rail on a side), a body
/// and a secondary body, on the platform of the device.
Future<void> _pumpProfile(
  WidgetTester tester,
  DeviceProfile profile, {
  bool withAction = false,
}) async {
  tester.view.physicalSize = profile.windowSize!;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    left: profile.padding.left,
    top: profile.padding.top,
    right: profile.padding.right,
    bottom: profile.padding.bottom,
  );
  tester.view.displayFeatures = profile.features!;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: FoldableVerticalBarScope(
        edge: profile.verticalBarEdge,
        child: FoldableScaffold(
          minBodySize: _minBodySize,
          appBar: AppBar(
            title: const Text('title'),
            actions: withAction
                ? [
                    IconButton(
                      key: _actionKey,
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                    ),
                  ]
                : null,
          ),
          navigationBuilder: (context, placement, constraints, padding) =>
              placement.isSide
              ? withAction
                    ? Column(
                        children: [
                          SizedBox(
                            key: _railHeadKey,
                            width: 40,
                            height: 40,
                            child: Text('nav ${placement.edge.name}'),
                          ),
                        ],
                      )
                    : SizedBox.expand(child: Text('nav ${placement.edge.name}'))
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

        testWidgets(
          'keeps the app bar action and the head of a rail out of the '
          'cutouts',
          (tester) async {
            await _pumpProfile(tester, profile, withAction: true);

            expect(tester.takeException(), isNull);
            final cutouts = [
              for (final feature in profile.features!)
                if (feature.type == DisplayFeatureType.cutout) feature.bounds,
            ];
            final action = tester.getRect(find.byKey(_actionKey));
            for (final cutout in cutouts) {
              expect(
                action.overlaps(cutout),
                isFalse,
                reason: 'the action $action is under the cutout $cutout',
              );
            }
            if (_expectedNavigationEdge(profile) != 'bottom') {
              final head = tester.getRect(find.byKey(_railHeadKey));
              for (final cutout in cutouts) {
                expect(
                  head.overlaps(cutout),
                  isFalse,
                  reason: 'the rail content $head is under the cutout $cutout',
                );
              }
            }
          },
        );

        testWidgets('keeps the head of a side navigation out of the system '
            'padding', (tester) async {
          await _pumpProfile(tester, profile);

          final edge = _expectedNavigationEdge(profile);
          if (edge == 'bottom') return;
          final window = profile.windowSize!;
          final strip = edge == 'start' || edge == 'left'
              ? Rect.fromLTRB(0, 0, profile.padding.left, window.height)
              : Rect.fromLTRB(
                  window.width - profile.padding.right,
                  0,
                  window.width,
                  window.height,
                );
          final head = tester.getRect(find.text('nav $edge'));
          expect(
            head.overlaps(strip),
            isFalse,
            reason: 'the navigation content $head is in the inset $strip',
          );
          for (final feature in profile.features!) {
            if (feature.type != DisplayFeatureType.cutout) continue;
            expect(head.overlaps(feature.bounds), isFalse);
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
