import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:foldable_scaffold/src/foldable_scaffold_layout.dart';
import 'package:material_ui/material_ui.dart';

DisplayFeature _cutout(double l, double t, double r, double b) {
  return DisplayFeature(
    bounds: Rect.fromLTRB(l, t, r, b),
    type: DisplayFeatureType.cutout,
    state: DisplayFeatureState.unknown,
  );
}

void main() {
  group('cutoutInsets', () {
    const window = Size(951, 669);
    const toolbar = Rect.fromLTRB(0, 0, 951, 56);

    EdgeInsets horizontal(
      Rect area,
      List<Rect> cutouts, {
      EdgeInsets padding = EdgeInsets.zero,
      Size size = window,
    }) => cutoutInsets(
      area: area,
      cutouts: cutouts,
      padding: padding,
      windowSize: size,
      axis: Axis.horizontal,
    );

    EdgeInsets vertical(
      Rect area,
      List<Rect> cutouts, {
      EdgeInsets padding = EdgeInsets.zero,
      Size size = window,
    }) => cutoutInsets(
      area: area,
      cutouts: cutouts,
      padding: padding,
      windowSize: size,
      axis: Axis.vertical,
    );

    test('a camera at the top right pushes the right edge of an app bar', () {
      expect(
        horizontal(toolbar, [const Rect.fromLTRB(867, 0, 951, 124)]),
        const EdgeInsets.only(right: 84),
      );
    });

    test('a camera at the top left pushes the left edge of an app bar', () {
      expect(
        horizontal(const Rect.fromLTRB(0, 0, 678, 56), [
          const Rect.fromLTRB(0, 0, 84, 82),
        ]),
        const EdgeInsets.only(left: 84),
      );
    });

    test('a camera in the middle goes to the nearer side', () {
      expect(
        horizontal(toolbar, [const Rect.fromLTRB(500, 0, 560, 40)]),
        const EdgeInsets.only(right: 451),
      );
      expect(
        horizontal(toolbar, [const Rect.fromLTRB(400, 0, 460, 40)]),
        const EdgeInsets.only(left: 460),
      );
    });

    test('a rail with a camera above it is pushed down', () {
      expect(
        vertical(const Rect.fromLTRB(879, 56, 951, 669), [
          const Rect.fromLTRB(867, 0, 951, 124),
        ]),
        const EdgeInsets.only(top: 68),
      );
    });

    test('a rail with a camera below it is pushed up', () {
      expect(
        vertical(const Rect.fromLTRB(606, 56, 678, 466), [
          const Rect.fromLTRB(594, 384, 678, 466),
        ], size: const Size(678, 466)),
        const EdgeInsets.only(bottom: 82),
      );
    });

    test('a cutout that does not overlap gives nothing', () {
      expect(
        horizontal(toolbar, [const Rect.fromLTRB(867, 56, 951, 124)]),
        EdgeInsets.zero,
      );
      expect(
        vertical(const Rect.fromLTRB(0, 56, 72, 669), [
          const Rect.fromLTRB(867, 0, 951, 124),
        ]),
        EdgeInsets.zero,
      );
      expect(horizontal(toolbar, const []), EdgeInsets.zero);
    });

    test('several cutouts give the largest inset on each edge', () {
      expect(
        horizontal(toolbar, [
          const Rect.fromLTRB(899.67, 29.33, 936.67, 55),
          const Rect.fromLTRB(867, 0, 951, 82),
          const Rect.fromLTRB(0, 0, 30, 20),
          const Rect.fromLTRB(0, 0, 60, 20),
        ]),
        const EdgeInsets.only(left: 60, right: 84),
      );
      expect(
        vertical(const Rect.fromLTRB(879, 0, 951, 669), [
          const Rect.fromLTRB(867, 0, 951, 124),
          const Rect.fromLTRB(900, 0, 940, 50),
          const Rect.fromLTRB(900, 600, 940, 669),
          const Rect.fromLTRB(900, 640, 940, 669),
        ]),
        const EdgeInsets.only(top: 124, bottom: 69),
      );
    });

    test('a cutout inside the strip of the system padding is ignored', () {
      const cutoutAtTop = Rect.fromLTRB(867, 0, 951, 48);
      expect(
        horizontal(toolbar, [
          cutoutAtTop,
        ], padding: const EdgeInsets.only(top: 48)),
        EdgeInsets.zero,
      );
      expect(
        horizontal(toolbar, [
          const Rect.fromLTRB(0, 0, 40, 56),
        ], padding: const EdgeInsets.only(left: 40)),
        EdgeInsets.zero,
      );
      expect(
        vertical(const Rect.fromLTRB(879, 56, 951, 669), [
          const Rect.fromLTRB(911, 0, 951, 48),
        ], padding: const EdgeInsets.only(top: 48)),
        EdgeInsets.zero,
      );
      expect(
        vertical(
          const Rect.fromLTRB(879, 56, 951, 669),
          [const Rect.fromLTRB(900, 640, 940, 669)],
          padding: const EdgeInsets.only(bottom: 30),
        ),
        EdgeInsets.zero,
      );
      expect(
        horizontal(toolbar, [
          const Rect.fromLTRB(930, 0, 951, 56),
        ], padding: const EdgeInsets.only(right: 21)),
        EdgeInsets.zero,
      );
      // The same cutout without that padding does count.
      expect(horizontal(toolbar, [cutoutAtTop]), isNot(EdgeInsets.zero));
    });

    test('an empty area gives nothing', () {
      expect(
        horizontal(const Rect.fromLTRB(900, 10, 900, 10), [
          const Rect.fromLTRB(867, 0, 951, 124),
        ]),
        EdgeInsets.zero,
      );
      expect(
        vertical(Rect.zero, [const Rect.fromLTRB(0, 0, 10, 10)]),
        EdgeInsets.zero,
      );
    });
  });

  group('resolveCutouts', () {
    const window = Size(951, 669);
    final features = [
      _cutout(867, 0, 951, 124),
      DisplayFeature(
        bounds: const Rect.fromLTRB(455, 0, 495, 669),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ];

    test('keeps the cutouts only, when the scaffold covers the window', () {
      expect(
        resolveCutouts(
          scaffoldWidth: 951,
          scaffoldHeight: 669,
          windowSize: window,
          displayFeatures: features,
          avoid: true,
        ),
        [const Rect.fromLTRB(867, 0, 951, 124)],
      );
    });

    test('is empty when off or when the scaffold is smaller', () {
      for (final (w, h, avoid) in [
        (951.0, 669.0, false),
        (900.0, 669.0, true),
        (951.0, 600.0, true),
      ]) {
        expect(
          resolveCutouts(
            scaffoldWidth: w,
            scaffoldHeight: h,
            windowSize: window,
            displayFeatures: features,
            avoid: avoid,
          ),
          isEmpty,
        );
      }
    });
  });

  group('FoldableScaffold avoids the cutouts', () {
    const landscape = Size(951, 669);
    const cameraTopRight = Rect.fromLTRB(867, 0, 951, 124);
    const cameraTopLeft = Rect.fromLTRB(0, 0, 84, 82);
    const tiny = Size(678, 466);
    const cameraBottomRight = Rect.fromLTRB(594, 384, 678, 466);

    const action = Key('action');
    const background = Key('background');
    const head = Key('rail_head');
    const foot = Key('rail_foot');

    Widget rail(
      BuildContext context,
      FoldableNavigationPlacement placement,
      BoxConstraints constraints,
      EdgeInsets padding,
    ) {
      return Column(
        children: const [
          SizedBox(key: head, width: 40, height: 40),
          Spacer(),
          SizedBox(key: foot, width: 40, height: 40),
        ],
      );
    }

    AppBar appBar() => AppBar(
      title: const Text('title'),
      flexibleSpace: const ColoredBox(
        key: background,
        color: Colors.red,
        child: SizedBox.expand(),
      ),
      actions: [
        IconButton(key: action, onPressed: () {}, icon: const Icon(Icons.add)),
      ],
    );

    Future<void> pump(
      WidgetTester tester, {
      Size size = landscape,
      List<Rect> cutouts = const [cameraTopRight],
      FoldableNavigationPlacement? placement,
      bool avoidCutouts = true,
      bool withAppBar = true,
      bool appBarBuilder = false,
      bool extendBehind = false,
      FakeViewPadding padding = FakeViewPadding.zero,
      EdgeInsets around = EdgeInsets.zero,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      tester.view.displayFeatures = [
        for (final c in cutouts) _cutout(c.left, c.top, c.right, c.bottom),
      ];
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Padding(
            padding: around,
            child: FoldableScaffold(
              avoidCutouts: avoidCutouts,
              extendBodyBehindAppBar: extendBehind,
              appBar: withAppBar && !appBarBuilder ? appBar() : null,
              appBarBuilder: withAppBar && appBarBuilder
                  ? (context, constraints) => appBar()
                  : null,
              navigationPlacement: placement == null ? null : (_) => placement,
              navigationBuilder: placement == null ? null : rail,
              body: const Text('body'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Rect rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

    testWidgets('the actions of the app bar are out of the camera, the '
        'background is not', (tester) async {
      await pump(tester);

      expect(tester.takeException(), isNull);
      expect(
        rect(tester, action).overlaps(cameraTopRight),
        isFalse,
        reason: '${rect(tester, action)}',
      );
      expect(rect(tester, action).right, lessThanOrEqualTo(867));
      final bg = rect(tester, background);
      expect(bg.left, 0);
      expect(bg.right, landscape.width);
      expect(bg.top, 0);
      expect(bg.height, kToolbarHeight);
    });

    testWidgets('a camera at the top left moves the leading side', (
      tester,
    ) async {
      await pump(tester, cutouts: [cameraTopLeft]);

      final title = tester.getRect(find.text('title'));
      expect(title.left, greaterThanOrEqualTo(84));
      expect(rect(tester, background).left, 0);
      expect(rect(tester, background).right, landscape.width);
    });

    testWidgets('a camera that is not over the app bar changes nothing', (
      tester,
    ) async {
      await pump(tester, size: tiny, cutouts: [cameraBottomRight]);
      final avoided = rect(tester, action);
      await pump(
        tester,
        size: tiny,
        cutouts: [cameraBottomRight],
        avoidCutouts: false,
      );
      expect(avoided, rect(tester, action));
    });

    testWidgets('a rail on the right starts under the camera', (tester) async {
      await pump(tester, placement: FoldableNavigationPlacement.right());

      expect(tester.takeException(), isNull);
      final h = rect(tester, head);
      expect(h.overlaps(cameraTopRight), isFalse);
      expect(h.top, 124);
      // Only the content moves: the navigation has the room under the camera.
      final slot = tester.getRect(
        find.byKey(const Key('primary_navigation_builder')),
      );
      expect(slot.right, landscape.width);
      expect(slot.top, 124);
      expect(rect(tester, foot).bottom, landscape.height);
    });

    testWidgets('a rail on the left starts under a camera at the top left', (
      tester,
    ) async {
      await pump(
        tester,
        cutouts: [cameraTopLeft],
        placement: FoldableNavigationPlacement.left(),
      );

      final h = rect(tester, head);
      expect(h.overlaps(cameraTopLeft), isFalse);
      expect(h.top, 82);
    });

    testWidgets('a rail ends above a camera that is below it', (tester) async {
      await pump(
        tester,
        size: tiny,
        cutouts: [cameraBottomRight],
        placement: FoldableNavigationPlacement.right(),
      );

      expect(rect(tester, foot).overlaps(cameraBottomRight), isFalse);
      expect(rect(tester, foot).bottom, 384);
      expect(rect(tester, head).top, kToolbarHeight);
    });

    testWidgets('avoidCutouts: false keeps the layout as it was', (
      tester,
    ) async {
      await pump(
        tester,
        placement: FoldableNavigationPlacement.right(),
        avoidCutouts: false,
      );

      expect(rect(tester, action).overlaps(cameraTopRight), isTrue);
      expect(rect(tester, head).top, kToolbarHeight);
      expect(rect(tester, foot).bottom, landscape.height);
    });

    testWidgets('a cutout inside the system padding is not avoided twice', (
      tester,
    ) async {
      const padding = FakeViewPadding(top: 124);
      Future<List<Rect>> measure({required bool avoid}) async {
        await pump(
          tester,
          placement: FoldableNavigationPlacement.right(),
          padding: padding,
          avoidCutouts: avoid,
        );
        return [rect(tester, action), rect(tester, head), rect(tester, foot)];
      }

      final on = await measure(avoid: true);
      final off = await measure(avoid: false);
      expect(on, off);
    });

    testWidgets('extendBodyBehindAppBar: the rail is measured from the top', (
      tester,
    ) async {
      await pump(
        tester,
        placement: FoldableNavigationPlacement.right(),
        extendBehind: true,
      );

      expect(rect(tester, head).top, 124);
      expect(rect(tester, action).overlaps(cameraTopRight), isFalse);
    });

    testWidgets('without an app bar the rail is measured from the top', (
      tester,
    ) async {
      await pump(
        tester,
        placement: FoldableNavigationPlacement.right(),
        withAppBar: false,
      );

      expect(tester.takeException(), isNull);
      expect(rect(tester, head).top, 124);
    });

    testWidgets('an appBarBuilder gets the same treatment', (tester) async {
      await pump(tester, appBarBuilder: true);

      expect(rect(tester, action).overlaps(cameraTopRight), isFalse);
      expect(rect(tester, background).width, landscape.width);
    });

    testWidgets('a scaffold that does not cover the window ignores them', (
      tester,
    ) async {
      await pump(
        tester,
        placement: FoldableNavigationPlacement.right(),
        around: const EdgeInsets.only(bottom: 40),
      );
      final ignored = [rect(tester, action), rect(tester, head)];
      await pump(
        tester,
        placement: FoldableNavigationPlacement.right(),
        around: const EdgeInsets.only(bottom: 40),
        avoidCutouts: false,
      );

      expect(ignored, [rect(tester, action), rect(tester, head)]);
      expect(ignored[0].overlaps(cameraTopRight), isTrue);
      expect(ignored[1].top, kToolbarHeight);
    });

    testWidgets('the builders still get the padding of the system', (
      tester,
    ) async {
      EdgeInsets? seen;
      tester.view.physicalSize = landscape;
      tester.view.devicePixelRatio = 1;
      tester.view.displayFeatures = [_cutout(867, 0, 951, 124)];
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: FoldableScaffold(
            navigationPlacement: (_) => FoldableNavigationPlacement.right(),
            navigationBuilder: (context, placement, constraints, padding) {
              seen = padding;
              return const SizedBox.expand();
            },
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(seen, EdgeInsets.zero);
    });
  });
}
