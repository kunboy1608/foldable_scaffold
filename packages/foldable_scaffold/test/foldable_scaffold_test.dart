import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps a [FoldableScaffold] in a window of exactly [size].
///
/// The platform is a desktop one unless said otherwise: the tests run as
/// Android, whose breakpoints are the handheld ones.
Future<void> _pumpScaffold(
  WidgetTester tester,
  Size size, {
  TargetPlatform platform = TargetPlatform.linux,
  FoldableBreakpoints? breakpoints,
  List<DisplayFeature> features = const [],
  bool followFold = true,
  bool focusOnPrimaryBody = false,
  bool secondary = false,
  bool withNavigation = false,
  double minBodySize = 200.0,
  ValueListenable<bool>? paneTransition,
  PopInvokedWithResultCallback<dynamic>? onSecondBodyClose,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = features;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: FoldableScaffold(
        followFold: followFold,
        breakpoints: breakpoints,
        focusOnPrimaryBody: focusOnPrimaryBody,
        minBodySize: minBodySize,
        paneTransition: paneTransition,
        onSecondBodyClose: onSecondBodyClose,
        bodyBuilder: (_, _) => const Text('body'),
        secondaryBodyBuilder: secondary
            ? (_, _) => const Text('secondary')
            : null,
        primaryNavigationBuilder: withNavigation
            ? (context, constraints, padding) =>
                  const SizedBox(width: 80, child: Text('rail'))
            : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _paneWidth(WidgetTester tester, String key) {
  return tester.getSize(find.byKey(Key(key), skipOffstage: false)).width;
}

FoldablePaneLayout _layout(WidgetTester tester) {
  return tester.widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout));
}

void main() {
  testWidgets('shows the secondary body alone below 1200', (tester) async {
    await _pumpScaffold(tester, const Size(800, 600), secondary: true);

    expect(_paneWidth(tester, 'body_builder'), 0);
    expect(_paneWidth(tester, 'secondary_body_builder'), 800);
    expect(_layout(tester).primaryVisible, isFalse);
    expect(_layout(tester).secondaryVisible, isTrue);
    expect(
      tester
          .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
          .canSplit,
      isFalse,
    );
  });

  testWidgets('keeps the body when focusOnPrimaryBody is true', (tester) async {
    await _pumpScaffold(
      tester,
      const Size(800, 600),
      secondary: true,
      focusOnPrimaryBody: true,
    );

    expect(_paneWidth(tester, 'body_builder'), 800);
    expect(_paneWidth(tester, 'secondary_body_builder'), 0);
  });

  testWidgets('shows both panes from 1200 with a secondary body', (
    tester,
  ) async {
    await _pumpScaffold(tester, const Size(1400, 600), secondary: true);

    expect(_paneWidth(tester, 'body_builder'), greaterThan(0));
    expect(_paneWidth(tester, 'secondary_body_builder'), greaterThan(0));
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);
    expect(
      tester
          .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
          .canSplit,
      isTrue,
    );
  });

  testWidgets('splits the panes at exactly 1200, not below', (tester) async {
    await _pumpScaffold(tester, const Size(1199, 600), secondary: true);

    expect(_paneWidth(tester, 'body_builder'), 0);
    expect(_paneWidth(tester, 'secondary_body_builder'), 1199);
    expect(
      tester
          .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
          .canSplit,
      isFalse,
    );

    await _pumpScaffold(tester, const Size(1200, 600), secondary: true);

    expect(_paneWidth(tester, 'body_builder'), greaterThanOrEqualTo(200));
    expect(
      _paneWidth(tester, 'secondary_body_builder'),
      greaterThanOrEqualTo(200),
    );
    expect(
      _paneWidth(tester, 'body_builder') +
          _paneWidth(tester, 'pane_divider') +
          _paneWidth(tester, 'secondary_body_builder'),
      closeTo(1200, 0.01),
    );
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);
    expect(
      tester
          .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
          .canSplit,
      isTrue,
    );
  });

  testWidgets('the divider stops at both edges and can be dragged back', (
    tester,
  ) async {
    await _pumpScaffold(tester, const Size(1400, 600), secondary: true);
    final divider = find.byKey(const Key('pane_divider'));

    // Far past the left edge: the body keeps minBodySize.
    await tester.drag(divider, const Offset(-5000, 0));
    await tester.pumpAndSettle();
    expect(_paneWidth(tester, 'body_builder'), closeTo(200, 0.01));
    expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(1176, 0.01));
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);

    // Far past the right edge: the secondary body keeps minBodySize.
    await tester.drag(divider, const Offset(5000, 0));
    await tester.pumpAndSettle();
    expect(_paneWidth(tester, 'body_builder'), closeTo(1176, 0.01));
    expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(200, 0.01));
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);

    // No dead zone: the divider follows the pointer from the edge.
    await tester.drag(divider, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(_paneWidth(tester, 'secondary_body_builder'), greaterThan(300));
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);
  });

  testWidgets('a pane narrower than minBodySize collapses into the other', (
    tester,
  ) async {
    // Two panes of 800 do not fit in 1400, so the body gives way.
    await _pumpScaffold(
      tester,
      const Size(1400, 600),
      secondary: true,
      minBodySize: 800,
    );

    expect(_paneWidth(tester, 'body_builder'), 0);
    expect(_paneWidth(tester, 'pane_divider'), 0);
    expect(_paneWidth(tester, 'secondary_body_builder'), 1400);
    expect(_layout(tester).primaryVisible, isFalse);
    expect(_layout(tester).secondaryVisible, isTrue);
  });

  testWidgets('calls onSecondBodyClose on back with a secondary body', (
    tester,
  ) async {
    final closed = <bool>[];
    await _pumpScaffold(
      tester,
      const Size(800, 600),
      secondary: true,
      onSecondBodyClose: (didPop, _) => closed.add(didPop),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(closed, [false]);
  });

  testWidgets('shows the navigation rail from 600', (tester) async {
    await _pumpScaffold(tester, const Size(500, 600), withNavigation: true);
    expect(find.text('rail'), findsNothing);

    await _pumpScaffold(tester, const Size(800, 600), withNavigation: true);
    expect(find.text('rail'), findsOneWidget);
    // The rail takes room from the body.
    expect(_paneWidth(tester, 'body_builder'), lessThan(800));
  });

  testWidgets('reads an explicit paneTransition signal', (tester) async {
    final transition = ValueNotifier(false);
    addTearDown(transition.dispose);

    await _pumpScaffold(
      tester,
      const Size(800, 600),
      paneTransition: transition,
    );
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('hasSecondaryBody skips probing the builder', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<int> pumpWith({required bool? hasSecondaryBody}) async {
      var calls = 0;
      // Start from an empty tree so both runs build from scratch.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: FoldableScaffold(
            hasSecondaryBody: hasSecondaryBody,
            bodyBuilder: (_, _) => const Text('body'),
            secondaryBodyBuilder: (_, _) {
              calls++;
              return const Text('secondary');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calls;
    }

    final probed = await pumpWith(hasSecondaryBody: null);
    final flagged = await pumpWith(hasSecondaryBody: true);

    // One call to probe for null plus one to build the pane, or only the latter.
    expect(probed, 2);
    expect(flagged, 1);
    expect(find.text('secondary'), findsOneWidget);
  });

  testWidgets('hasSecondaryBody false hides the secondary pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: FoldableScaffold(
          hasSecondaryBody: false,
          bodyBuilder: (_, _) => const Text('body'),
          secondaryBodyBuilder: (_, _) => const Text('secondary'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_paneWidth(tester, 'body_builder'), 800);
    expect(_paneWidth(tester, 'secondary_body_builder'), 0);
  });

  group('breakpoints by platform', () {
    /// Whether the body and the secondary body are both on screen.
    bool isSplit(WidgetTester tester) =>
        _layout(tester).primaryVisible && _layout(tester).secondaryVisible;

    /// A device by what Flutter reports for it: logical size in either
    /// orientation, with the platform it runs.
    Future<void> expectPanes(
      WidgetTester tester, {
      required String device,
      required TargetPlatform platform,
      required Size portrait,
      required bool split,
    }) async {
      for (final size in [portrait, Size(portrait.height, portrait.width)]) {
        await _pumpScaffold(tester, size, platform: platform, secondary: true);
        expect(isSplit(tester), split, reason: '$device at $size');
        expect(
          tester
              .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
              .canSplit,
          split,
          reason: '$device at $size',
        );
        if (split) {
          // Both panes are usable, not squeezed to nothing.
          expect(_paneWidth(tester, 'body_builder'), greaterThanOrEqualTo(200));
          expect(
            _paneWidth(tester, 'secondary_body_builder'),
            greaterThanOrEqualTo(200),
          );
        }
      }
    }

    testWidgets('a phone keeps one pane, held either way', (tester) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        await expectPanes(
          tester,
          device: 'phone',
          platform: platform,
          portrait: const Size(360, 800),
          split: false,
        );
        await expectPanes(
          tester,
          device: 'large phone',
          platform: platform,
          portrait: const Size(440, 956),
          split: false,
        );
        // Even a big, wide phone is short on one side.
        await expectPanes(
          tester,
          device: 'phablet',
          platform: platform,
          portrait: const Size(480, 1000),
          split: false,
        );
      }
    });

    testWidgets('the cover screen of a foldable keeps one pane', (
      tester,
    ) async {
      await expectPanes(
        tester,
        device: 'Z Fold8 cover',
        platform: TargetPlatform.android,
        portrait: const Size(411, 960),
        split: false,
      );
    });

    testWidgets('the inner screen of a Galaxy Z Fold8 shows two panes', (
      tester,
    ) async {
      // About 635 x 841 dp (2448 x 1848 px, 403 ppi).
      await expectPanes(
        tester,
        device: 'Z Fold8',
        platform: TargetPlatform.android,
        portrait: const Size(635, 841),
        split: true,
      );
    });

    testWidgets('the inner screen of a Galaxy Z Fold8 Ultra shows two panes', (
      tester,
    ) async {
      // About 740 x 822 dp (2256 x 2504 px, 422 ppi).
      await expectPanes(
        tester,
        device: 'Z Fold8 Ultra',
        platform: TargetPlatform.android,
        portrait: const Size(740, 822),
        split: true,
      );
    });

    testWidgets('the inner screen of an iPhone Fold shows two panes', (
      tester,
    ) async {
      // About 640 x 904 pt, from the leaked 1920 x 2713 px at 3x.
      await expectPanes(
        tester,
        device: 'iPhone Fold',
        platform: TargetPlatform.iOS,
        portrait: const Size(640, 904),
        split: true,
      );
      await expectPanes(
        tester,
        device: 'iPhone Fold, smaller leak',
        platform: TargetPlatform.iOS,
        portrait: const Size(626, 890),
        split: true,
      );
    });

    testWidgets('a tablet shows two panes on Android and iOS', (tester) async {
      await expectPanes(
        tester,
        device: 'tablet',
        platform: TargetPlatform.android,
        portrait: const Size(800, 1280),
        split: true,
      );
      await expectPanes(
        tester,
        device: 'iPad',
        platform: TargetPlatform.iOS,
        portrait: const Size(820, 1180),
        split: true,
      );
    });

    testWidgets('a narrow window of a handheld stays on one pane', (
      tester,
    ) async {
      // Tall enough, but not wide enough: multi-window on a tablet.
      await expectPanes(
        tester,
        device: 'half a tablet',
        platform: TargetPlatform.android,
        portrait: const Size(500, 1200),
        split: false,
      );
    });

    testWidgets('desktop platforms split from 1200, whatever the height', (
      tester,
    ) async {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        for (final size in const [Size(1199, 900), Size(800, 1300)]) {
          await _pumpScaffold(
            tester,
            size,
            platform: platform,
            secondary: true,
          );
          expect(isSplit(tester), isFalse, reason: '$platform at $size');
        }
        await _pumpScaffold(
          tester,
          const Size(1200, 600),
          platform: platform,
          secondary: true,
        );
        expect(isSplit(tester), isTrue, reason: '$platform at 1200 x 600');
      }
    });

    testWidgets('the navigation rail follows the width on every platform', (
      tester,
    ) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
        await _pumpScaffold(
          tester,
          const Size(500, 900),
          platform: platform,
          withNavigation: true,
        );
        expect(find.text('rail'), findsNothing, reason: '$platform');

        // A phone held sideways still gets the rail.
        await _pumpScaffold(
          tester,
          const Size(900, 412),
          platform: platform,
          withNavigation: true,
        );
        expect(find.text('rail'), findsOneWidget, reason: '$platform');
      }
    });

    testWidgets('breakpoints replaces the platform default', (tester) async {
      const breakpoints = FoldableBreakpoints(split: 840);

      await _pumpScaffold(
        tester,
        const Size(839, 700),
        breakpoints: breakpoints,
        secondary: true,
      );
      expect(isSplit(tester), isFalse);

      await _pumpScaffold(
        tester,
        const Size(840, 700),
        breakpoints: breakpoints,
        secondary: true,
      );
      expect(isSplit(tester), isTrue);

      // A phone can be given two panes on purpose.
      await _pumpScaffold(
        tester,
        const Size(900, 400),
        platform: TargetPlatform.android,
        breakpoints: const FoldableBreakpoints.desktop(split: 800),
        secondary: true,
      );
      expect(isSplit(tester), isTrue);
    });

    test('forPlatform picks handheld or desktop', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(
          FoldableBreakpoints.forPlatform(platform),
          const FoldableBreakpoints.handheld(),
        );
      }
      for (final platform in [
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(
          FoldableBreakpoints.forPlatform(platform),
          const FoldableBreakpoints.desktop(),
        );
      }
    });

    test('canSplit needs the width and the short side', () {
      const handheld = FoldableBreakpoints.handheld();

      expect(handheld.canSplit(600, const Size(600, 800)), isTrue);
      expect(handheld.canSplit(599, const Size(599, 800)), isFalse);
      expect(handheld.canSplit(900, const Size(900, 599)), isFalse);
      // A scaffold inside a bigger window still needs its own width.
      expect(handheld.canSplit(500, const Size(900, 900)), isFalse);

      const desktop = FoldableBreakpoints.desktop();
      expect(desktop.canSplit(1200, const Size(1200, 100)), isTrue);
      expect(desktop.canSplit(1199, const Size(1199, 2000)), isFalse);
    });

    test('copyWith, equality and toString', () {
      const base = FoldableBreakpoints.handheld();
      final changed = base.copyWith(split: 840);

      expect(changed.split, 840);
      expect(changed.splitMinShortestSide, base.splitMinShortestSide);
      expect(changed.rail, base.rail);
      expect(changed.wideRail, base.wideRail);
      expect(changed, isNot(base));
      expect(changed.copyWith(split: 600), base);
      expect(changed.hashCode, isNot(base.hashCode));
      expect(base.toString(), contains('split: 600'));
    });
  });

  group('folds and hinges', () {
    DisplayFeature hinge(double left, double right, double height) {
      return DisplayFeature(
        bounds: Rect.fromLTRB(left, 0, right, height),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      );
    }

    DisplayFeature fold(
      double x,
      double height, {
      DisplayFeatureState state = DisplayFeatureState.postureFlat,
    }) {
      return DisplayFeature(
        bounds: Rect.fromLTRB(x, 0, x, height),
        type: DisplayFeatureType.fold,
        state: state,
      );
    }

    bool isSplit(WidgetTester tester) =>
        _layout(tester).primaryVisible && _layout(tester).secondaryVisible;

    bool canSplit(WidgetTester tester) => tester
        .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
        .canSplit;

    testWidgets('a hinge puts one pane on each screen, on a narrow window', (
      tester,
    ) async {
      // A dual-screen device: 2 x 480 and a 40 wide hinge. A desktop window of
      // this width would show one pane.
      await _pumpScaffold(
        tester,
        const Size(1000, 700),
        secondary: true,
        features: [hinge(480, 520, 700)],
      );

      expect(_paneWidth(tester, 'body_builder'), closeTo(480, 0.01));
      expect(_paneWidth(tester, 'pane_divider'), closeTo(40, 0.01));
      expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(480, 0.01));
      expect(isSplit(tester), isTrue);
      expect(canSplit(tester), isTrue);
    });

    testWidgets('the hinge area is not a handle', (tester) async {
      await _pumpScaffold(
        tester,
        const Size(1000, 700),
        secondary: true,
        features: [hinge(480, 520, 700)],
      );

      await tester.drag(
        find.byKey(const Key('pane_divider')),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      expect(_paneWidth(tester, 'body_builder'), closeTo(480, 0.01));
      expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(480, 0.01));
    });

    testWidgets('the navigation rail is left of the first screen', (
      tester,
    ) async {
      await _pumpScaffold(
        tester,
        const Size(1000, 700),
        secondary: true,
        withNavigation: true,
        features: [hinge(480, 520, 700)],
      );

      // The rail takes 72 of the first screen, the hinge stays where it is.
      final body = tester.getRect(
        find.byKey(const Key('body_builder'), skipOffstage: false),
      );
      final secondary = tester.getRect(
        find.byKey(const Key('secondary_body_builder'), skipOffstage: false),
      );
      expect(body.right, closeTo(480, 0.01));
      expect(secondary.left, closeTo(520, 0.01));
      expect(secondary.right, closeTo(1000, 0.01));
    });

    testWidgets('a half-open fold separates the panes like a hinge', (
      tester,
    ) async {
      // A foldable held like a book: below the width where a phone splits, and
      // with a hinge-less fold in the middle.
      await _pumpScaffold(
        tester,
        const Size(700, 800),
        platform: TargetPlatform.linux,
        secondary: true,
        features: [
          fold(350, 800, state: DisplayFeatureState.postureHalfOpened),
        ],
      );

      expect(isSplit(tester), isTrue);
      expect(_paneWidth(tester, 'body_builder'), closeTo(350, 0.01));
      expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(350, 0.01));
    });

    testWidgets('the same fold flat starts the divider on the crease', (
      tester,
    ) async {
      // 1400 is wide enough for two panes on a desktop platform.
      await _pumpScaffold(
        tester,
        const Size(1400, 800),
        secondary: true,
        features: [fold(900, 800)],
      );

      // The divider (24 wide) is centered on x = 900.
      final divider = tester.getRect(find.byKey(const Key('pane_divider')));
      expect(divider.center.dx, closeTo(900, 0.01));
      expect(_paneWidth(tester, 'body_builder'), closeTo(888, 0.01));
      expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(488, 0.01));
    });

    testWidgets('a flat fold still lets the user drag the divider away', (
      tester,
    ) async {
      await _pumpScaffold(
        tester,
        const Size(1400, 800),
        secondary: true,
        features: [fold(900, 800)],
      );

      await tester.drag(
        find.byKey(const Key('pane_divider')),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();

      // Continues from the crease, no jump to the 50/50 ratio.
      expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(588, 1));
      expect(_paneWidth(tester, 'body_builder'), closeTo(788, 1));
    });

    testWidgets('moving the fold takes the divider back to it', (tester) async {
      await _pumpScaffold(
        tester,
        const Size(1400, 800),
        secondary: true,
        features: [fold(900, 800)],
      );
      await tester.drag(
        find.byKey(const Key('pane_divider')),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();

      // The device is folded half way and unfolded again, the crease moves.
      tester.view.displayFeatures = [fold(700, 800)];
      await tester.pumpAndSettle();

      final divider = tester.getRect(find.byKey(const Key('pane_divider')));
      expect(divider.center.dx, closeTo(700, 0.01));
    });

    testWidgets('unfolding to the book posture and back follows the posture', (
      tester,
    ) async {
      await _pumpScaffold(
        tester,
        const Size(700, 800),
        secondary: true,
        features: [fold(350, 800)],
      );
      // Flat, but a desktop platform needs 1200: one pane.
      expect(isSplit(tester), isFalse);

      tester.view.displayFeatures = [
        fold(350, 800, state: DisplayFeatureState.postureHalfOpened),
      ];
      await tester.pumpAndSettle();
      expect(isSplit(tester), isTrue);

      tester.view.displayFeatures = [fold(350, 800)];
      await tester.pumpAndSettle();
      expect(isSplit(tester), isFalse);
    });

    testWidgets('a flat fold on a foldable aligns the two panes', (
      tester,
    ) async {
      // The inner screen of a foldable: two panes by the handheld rule, with
      // the crease a little off center because of the rail.
      await _pumpScaffold(
        tester,
        const Size(841, 635),
        platform: TargetPlatform.android,
        secondary: true,
        features: [fold(420.5, 635)],
      );

      final divider = tester.getRect(find.byKey(const Key('pane_divider')));
      expect(divider.center.dx, closeTo(420.5, 0.01));
      expect(isSplit(tester), isTrue);
    });

    testWidgets('followFold false ignores the fold', (tester) async {
      await _pumpScaffold(
        tester,
        const Size(1000, 700),
        secondary: true,
        followFold: false,
        features: [hinge(480, 520, 700)],
      );

      expect(isSplit(tester), isFalse);
    });

    testWidgets('folds that do not split the width are ignored', (
      tester,
    ) async {
      // A horizontal fold (laptop posture) and a camera cutout.
      await _pumpScaffold(
        tester,
        const Size(1000, 700),
        secondary: true,
        features: [
          DisplayFeature(
            bounds: const Rect.fromLTRB(0, 340, 1000, 360),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureHalfOpened,
          ),
          DisplayFeature(
            bounds: const Rect.fromLTRB(480, 0, 520, 40),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      expect(isSplit(tester), isFalse);
    });

    testWidgets('a hinge too close to an edge leaves the usual layout', (
      tester,
    ) async {
      // The left screen would be 100 wide, under minBodySize.
      await _pumpScaffold(
        tester,
        const Size(1000, 700),
        secondary: true,
        features: [hinge(100, 140, 700)],
      );

      expect(isSplit(tester), isFalse);
    });

    testWidgets('a scaffold narrower than the window ignores the fold', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.displayFeatures = [hinge(480, 520, 700)];
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 600,
              child: FoldableScaffold(
                bodyBuilder: (_, _) => const Text('body'),
                secondaryBodyBuilder: (_, _) => const Text('secondary'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(isSplit(tester), isFalse);
    });

    testWidgets('a hinge does nothing without a secondary body', (
      tester,
    ) async {
      await _pumpScaffold(
        tester,
        const Size(1000, 700),
        features: [hinge(480, 520, 700)],
      );

      expect(_paneWidth(tester, 'body_builder'), 1000);
      expect(_paneWidth(tester, 'secondary_body_builder'), 0);
    });

    test('FoldableFold.fromFeatures keeps only a vertical fold or hinge', () {
      const window = Size(1000, 700);

      final found = FoldableFold.fromFeatures([
        DisplayFeature(
          bounds: const Rect.fromLTRB(480, 0, 520, 700),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ], window);
      expect(found?.bounds, const Rect.fromLTRB(480, 0, 520, 700));
      expect(found?.isSeparating, isTrue);
      expect(found?.center, 500);

      final flat = FoldableFold.fromFeatures([
        DisplayFeature(
          bounds: const Rect.fromLTRB(500, 0, 500, 700),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
      ], window);
      expect(flat?.isSeparating, isFalse);

      expect(FoldableFold.fromFeatures(const [], window), isNull);
      expect(
        FoldableFold.fromFeatures([
          DisplayFeature(
            bounds: const Rect.fromLTRB(0, 340, 1000, 360),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ], window),
        isNull,
      );
      // At the very edge it does not cut the window in two.
      expect(
        FoldableFold.fromFeatures([
          DisplayFeature(
            bounds: const Rect.fromLTRB(0, 0, 20, 700),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ], window),
        isNull,
      );
    });

    test('FoldableFold compares by value', () {
      const a = FoldableFold(
        bounds: Rect.fromLTRB(1, 0, 2, 3),
        isSeparating: true,
      );
      const b = FoldableFold(
        bounds: Rect.fromLTRB(1, 0, 2, 3),
        isSeparating: true,
      );
      const c = FoldableFold(
        bounds: Rect.fromLTRB(1, 0, 2, 3),
        isSeparating: false,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('isSeparating: true'));
    });
  });
}
