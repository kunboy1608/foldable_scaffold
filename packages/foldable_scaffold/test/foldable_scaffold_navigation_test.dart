import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

const _navKey = Key('nav');

/// What the navigation builder was last called with.
class _Call {
  FoldableNavigationPlacement? placement;
  BoxConstraints? constraints;
  EdgeInsets? padding;
}

FoldableLayoutInfo _info({
  double width = 800,
  double height = 600,
  TargetPlatform platform = TargetPlatform.android,
  TextDirection textDirection = TextDirection.ltr,
  FoldableNavigationEdge? verticalBarEdge,
  FoldableBreakpoints? breakpoints,
}) {
  return FoldableLayoutInfo(
    scaffoldSize: Size(width, height),
    windowSize: Size(width, height),
    platform: platform,
    textDirection: textDirection,
    padding: EdgeInsets.zero,
    breakpoints: breakpoints ?? FoldableBreakpoints.forPlatform(platform),
    verticalBarEdge: verticalBarEdge,
  );
}

/// Pumps a [FoldableScaffold] in a window of [size], with a navigation made by
/// a builder (the slots when [useSlots] is true) and the other arguments.
Future<_Call> _pump(
  WidgetTester tester,
  Size size, {
  FoldableNavigationPlacementResolver? placement,
  bool useSlots = false,
  bool rtl = false,
  bool secondary = false,
  FoldableNavigationEdge? verticalBarEdge,
  List<DisplayFeature> features = const [],
  EdgeInsets inset = EdgeInsets.zero,
  Widget? body,
  PreferredSizeWidget? appBar,
  Key? scaffoldKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = features;
  tester.view.padding = FakeViewPadding(
    left: inset.left,
    top: inset.top,
    right: inset.right,
    bottom: inset.bottom,
  );
  addTearDown(tester.view.reset);

  final call = _Call();
  Widget scaffold = FoldableScaffold(
    key: scaffoldKey,
    appBar: appBar,
    navigationPlacement: placement,
    body: body ?? const Text('body'),
    secondaryBody: secondary ? const Text('secondary') : null,
    navigationBuilder: useSlots
        ? null
        : (context, p, constraints, padding) {
            call
              ..placement = p
              ..constraints = constraints
              ..padding = padding;
            return p.isSide
                ? SizedBox.expand(key: _navKey, child: Text(p.edge.name))
                : SizedBox(
                    key: _navKey,
                    height: 56,
                    width: double.infinity,
                    child: Text(p.edge.name),
                  );
          },
    primaryNavigation: useSlots
        ? const SizedBox.expand(key: Key('rail'), child: Text('rail'))
        : null,
    bottomNavigationBar: useSlots
        ? const SizedBox(key: Key('bar'), height: 56, child: Text('bar'))
        : null,
  );
  if (verticalBarEdge != null) {
    scaffold = FoldableVerticalBarScope(edge: verticalBarEdge, child: scaffold);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      builder: (context, child) => Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: scaffold,
    ),
  );
  await tester.pumpAndSettle();
  return call;
}

Rect _rect(WidgetTester tester, Key key) =>
    tester.getRect(find.byKey(key, skipOffstage: false));

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const Text('probe');
}

void main() {
  group('FoldableNavigationEdge', () {
    test('resolves start and end with the text direction', () {
      expect(
        FoldableNavigationEdge.start.resolve(TextDirection.ltr),
        FoldableNavigationEdge.left,
      );
      expect(
        FoldableNavigationEdge.start.resolve(TextDirection.rtl),
        FoldableNavigationEdge.right,
      );
      expect(
        FoldableNavigationEdge.end.resolve(TextDirection.ltr),
        FoldableNavigationEdge.right,
      );
      expect(
        FoldableNavigationEdge.end.resolve(TextDirection.rtl),
        FoldableNavigationEdge.left,
      );
    });

    test('left, right, top, bottom and none do not move', () {
      for (final edge in [
        FoldableNavigationEdge.left,
        FoldableNavigationEdge.right,
        FoldableNavigationEdge.top,
        FoldableNavigationEdge.bottom,
        FoldableNavigationEdge.none,
      ]) {
        expect(edge.resolve(TextDirection.rtl), edge);
        expect(edge.resolve(TextDirection.ltr), edge);
      }
    });

    test('tells a side from a horizontal bar', () {
      expect(FoldableNavigationEdge.start.isSide, isTrue);
      expect(FoldableNavigationEdge.right.isSide, isTrue);
      expect(FoldableNavigationEdge.top.isSide, isFalse);
      expect(FoldableNavigationEdge.top.isHorizontalBar, isTrue);
      expect(FoldableNavigationEdge.bottom.isHorizontalBar, isTrue);
      expect(FoldableNavigationEdge.none.isSide, isFalse);
      expect(FoldableNavigationEdge.none.isHorizontalBar, isFalse);
    });
  });

  group('FoldableNavigationPlacement', () {
    test('has value equality, a readable toString and named constructors', () {
      expect(
        const FoldableNavigationPlacement.start(extent: 80),
        const FoldableNavigationPlacement(
          FoldableNavigationEdge.start,
          extent: 80,
        ),
      );
      expect(
        const FoldableNavigationPlacement.start(),
        isNot(const FoldableNavigationPlacement.end()),
      );
      expect(
        const FoldableNavigationPlacement.left(extent: 72).toString(),
        'FoldableNavigationPlacement(left, extent: 72.0)',
      );
      expect(
        const FoldableNavigationPlacement.bottom().toString(),
        'FoldableNavigationPlacement(bottom)',
      );
      expect(const FoldableNavigationPlacement.none().isVisible, isFalse);
      expect(const FoldableNavigationPlacement.top().isVisible, isTrue);
      expect(const FoldableNavigationPlacement.right().isSide, isTrue);
    });

    test('refuses a negative extent', () {
      expect(
        () => FoldableNavigationPlacement(
          FoldableNavigationEdge.left,
          extent: -1,
        ),
        throwsAssertionError,
      );
    });
  });

  group('defaultNavigationPlacement', () {
    test('is a bottom bar below the rail breakpoint, a rail from it', () {
      for (final platform in TargetPlatform.values) {
        expect(
          defaultNavigationPlacement(_info(width: 599, platform: platform)),
          const FoldableNavigationPlacement.bottom(),
          reason: '$platform below 600',
        );
        expect(
          defaultNavigationPlacement(_info(width: 600, platform: platform)),
          const FoldableNavigationPlacement.start(),
          reason: '$platform from 600',
        );
      }
    });

    test('follows the breakpoints it is given', () {
      expect(
        defaultNavigationPlacement(
          _info(width: 700, breakpoints: const FoldableBreakpoints(rail: 800)),
        ),
        const FoldableNavigationPlacement.bottom(),
      );
    });

    test('forPlatform picks handheld or desktop', () {
      expect(
        FoldableNavigationPlacements.forPlatform(TargetPlatform.android),
        FoldableNavigationPlacements.handheld,
      );
      expect(
        FoldableNavigationPlacements.forPlatform(TargetPlatform.iOS),
        FoldableNavigationPlacements.handheld,
      );
      expect(
        FoldableNavigationPlacements.forPlatform(TargetPlatform.macOS),
        FoldableNavigationPlacements.desktop,
      );
      expect(
        FoldableNavigationPlacements.forPlatform(TargetPlatform.linux),
        FoldableNavigationPlacements.desktop,
      );
    });

    test('puts the navigation on the side the platform asks for', () {
      for (final edge in [
        FoldableNavigationEdge.start,
        FoldableNavigationEdge.end,
        FoldableNavigationEdge.left,
        FoldableNavigationEdge.right,
      ]) {
        for (final width in [300.0, 900.0]) {
          expect(
            defaultNavigationPlacement(
              _info(
                width: width,
                platform: TargetPlatform.iOS,
                verticalBarEdge: edge,
              ),
            ),
            FoldableNavigationPlacement(edge),
            reason: '$edge at $width',
          );
        }
      }
    });

    test('ignores a vertical bar edge that is not a side', () {
      expect(
        defaultNavigationPlacement(
          _info(width: 300, verticalBarEdge: FoldableNavigationEdge.top),
        ),
        const FoldableNavigationPlacement.bottom(),
      );
      expect(
        defaultNavigationPlacement(
          _info(width: 300, verticalBarEdge: FoldableNavigationEdge.none),
        ),
        const FoldableNavigationPlacement.bottom(),
      );
    });
  });

  group('FoldableLayoutInfo', () {
    test('reads the width classes from the breakpoints', () {
      final narrow = _info(width: 599);
      final rail = _info(width: 600);
      final wide = _info(width: 1001);
      expect(narrow.hasRailWidth, isFalse);
      expect(rail.hasRailWidth, isTrue);
      expect(rail.hasWideRailWidth, isFalse);
      expect(wide.hasWideRailWidth, isTrue);
      expect(narrow.scaffoldWidth, 599);
      expect(narrow.scaffoldHeight, 600);
    });

    test('knows whether the platform wants a vertical bar', () {
      expect(_info().wantsVerticalBar, isFalse);
      expect(
        _info(verticalBarEdge: FoldableNavigationEdge.end).wantsVerticalBar,
        isTrue,
      );
      expect(
        _info(verticalBarEdge: FoldableNavigationEdge.top).wantsVerticalBar,
        isFalse,
      );
    });

    test('has value equality', () {
      expect(_info(), _info());
      expect(_info().hashCode, _info().hashCode);
      expect(_info(), isNot(_info(width: 801)));
      expect(
        _info(),
        isNot(_info(verticalBarEdge: FoldableNavigationEdge.start)),
      );
    });
  });

  group('the navigation on each edge', () {
    const size = Size(900, 600);

    testWidgets('bottom: under the panes, the width of the scaffold', (
      tester,
    ) async {
      await _pump(
        tester,
        size,
        placement: (_) => const FoldableNavigationPlacement.bottom(),
      );

      expect(_rect(tester, _navKey), const Rect.fromLTRB(0, 544, 900, 600));
      expect(_rect(tester, const Key('body_builder')).bottom, 544);
      expect(_rect(tester, const Key('body_builder')).width, 900);
    });

    testWidgets('top: above the panes', (tester) async {
      await _pump(
        tester,
        size,
        placement: (_) => const FoldableNavigationPlacement.top(),
      );

      expect(_rect(tester, _navKey), const Rect.fromLTRB(0, 0, 900, 56));
      expect(_rect(tester, const Key('body_builder')).top, 56);
      expect(_rect(tester, const Key('body_builder')).bottom, 600);
    });

    testWidgets('top: under the app bar', (tester) async {
      await _pump(
        tester,
        size,
        appBar: AppBar(title: const Text('t')),
        placement: (_) => const FoldableNavigationPlacement.top(),
      );

      expect(_rect(tester, _navKey).top, kToolbarHeight);
      expect(_rect(tester, const Key('body_builder')).top, kToolbarHeight + 56);
    });

    testWidgets('start: the left in LTR, 72 wide, beside the panes', (
      tester,
    ) async {
      final call = await _pump(
        tester,
        size,
        placement: (_) => const FoldableNavigationPlacement.start(),
      );

      expect(_rect(tester, _navKey), const Rect.fromLTRB(0, 0, 72, 600));
      expect(_rect(tester, const Key('body_builder')).left, 72);
      expect(_rect(tester, const Key('body_builder')).right, 900);
      expect(call.placement, const FoldableNavigationPlacement.start());
      expect(call.constraints?.maxWidth, 72);
    });

    testWidgets('start: the right in RTL', (tester) async {
      await _pump(
        tester,
        size,
        rtl: true,
        placement: (_) => const FoldableNavigationPlacement.start(),
      );

      expect(_rect(tester, _navKey), const Rect.fromLTRB(828, 0, 900, 600));
      expect(_rect(tester, const Key('body_builder')).left, 0);
      expect(_rect(tester, const Key('body_builder')).right, 828);
    });

    testWidgets('end: the right in LTR, the left in RTL', (tester) async {
      await _pump(
        tester,
        size,
        placement: (_) => const FoldableNavigationPlacement.end(),
      );
      expect(_rect(tester, _navKey), const Rect.fromLTRB(828, 0, 900, 600));
      expect(_rect(tester, const Key('body_builder')).right, 828);

      await _pump(
        tester,
        size,
        rtl: true,
        placement: (_) => const FoldableNavigationPlacement.end(),
      );
      expect(_rect(tester, _navKey), const Rect.fromLTRB(0, 0, 72, 600));
      expect(_rect(tester, const Key('body_builder')).left, 72);
    });

    testWidgets('left and right stay on the same side in RTL', (tester) async {
      await _pump(
        tester,
        size,
        rtl: true,
        placement: (_) => const FoldableNavigationPlacement.left(),
      );
      expect(_rect(tester, _navKey), const Rect.fromLTRB(0, 0, 72, 600));

      await _pump(
        tester,
        size,
        rtl: true,
        placement: (_) => const FoldableNavigationPlacement.right(),
      );
      expect(_rect(tester, _navKey), const Rect.fromLTRB(828, 0, 900, 600));
    });

    testWidgets('none: nothing is shown and the panes take the room', (
      tester,
    ) async {
      await _pump(
        tester,
        size,
        placement: (_) => const FoldableNavigationPlacement.none(),
      );

      expect(find.byKey(_navKey), findsNothing);
      expect(_rect(tester, const Key('body_builder')).width, 900);
      expect(_rect(tester, const Key('body_builder')).height, 600);
    });

    testWidgets('extent sets the width of a side navigation', (tester) async {
      await _pump(
        tester,
        size,
        placement: (_) => const FoldableNavigationPlacement.left(extent: 120),
      );

      expect(_rect(tester, _navKey).width, 120);
      expect(_rect(tester, const Key('body_builder')).left, 120);
    });

    testWidgets('the default extent is 192 above the wide rail breakpoint', (
      tester,
    ) async {
      await _pump(
        tester,
        const Size(1100, 600),
        placement: (_) => const FoldableNavigationPlacement.left(),
      );

      expect(_rect(tester, _navKey).width, 192);
    });

    testWidgets('a side navigation adds the system inset on its edge', (
      tester,
    ) async {
      final call = await _pump(
        tester,
        size,
        inset: const EdgeInsets.only(right: 20),
        placement: (_) => const FoldableNavigationPlacement.right(),
      );

      expect(_rect(tester, _navKey).width, 92);
      expect(call.padding?.right, 20);
      final bodyContext = tester.element(find.text('body'));
      expect(MediaQuery.paddingOf(bodyContext).right, 0);
    });

    testWidgets('a top navigation takes the top inset off the panes', (
      tester,
    ) async {
      await _pump(
        tester,
        size,
        inset: const EdgeInsets.only(top: 30),
        placement: (_) => const FoldableNavigationPlacement.top(),
      );

      final bodyContext = tester.element(find.text('body'));
      expect(MediaQuery.paddingOf(bodyContext).top, 0);
    });

    testWidgets('a bottom navigation keeps the Scaffold insets working', (
      tester,
    ) async {
      await _pump(
        tester,
        size,
        inset: const EdgeInsets.only(bottom: 34),
        placement: (_) => const FoldableNavigationPlacement.bottom(),
      );

      expect(_rect(tester, const Key('body_builder')).bottom, lessThan(600));
    });
  });

  group('the placement resolver', () {
    testWidgets('gets the facts of the scaffold', (tester) async {
      FoldableLayoutInfo? seen;
      await _pump(
        tester,
        const Size(900, 600),
        secondary: true,
        rtl: true,
        placement: (info) {
          seen = info;
          return defaultNavigationPlacement(info);
        },
      );

      expect(seen, isNotNull);
      expect(seen!.scaffoldSize, const Size(900, 600));
      expect(seen!.windowSize, const Size(900, 600));
      expect(seen!.platform, TargetPlatform.linux);
      expect(seen!.textDirection, TextDirection.rtl);
      expect(seen!.hasSecondaryBody, isTrue);
      expect(seen!.verticalBarEdge, isNull);
      expect(seen!.minWidthNavigation, 72);
      expect(seen!.maxWidthNavigation, 192);
    });

    testWidgets('can look at the height, and the default fills the gaps', (
      tester,
    ) async {
      FoldableNavigationPlacement resolver(FoldableLayoutInfo info) =>
          info.scaffoldHeight < 400
          ? const FoldableNavigationPlacement.end()
          : defaultNavigationPlacement(info);

      await _pump(tester, const Size(500, 800), placement: resolver);
      expect(find.text('bottom'), findsOneWidget);

      await _pump(tester, const Size(500, 300), placement: resolver);
      expect(find.text('end'), findsOneWidget);
      expect(_rect(tester, _navKey).right, 500);
    });

    testWidgets('without one, the default is used', (tester) async {
      final call = await _pump(tester, const Size(500, 600));
      expect(call.placement, const FoldableNavigationPlacement.bottom());

      final wide = await _pump(tester, const Size(700, 600));
      expect(wide.placement, const FoldableNavigationPlacement.start());
    });
  });

  group('FoldableVerticalBarScope (iPhone Duo)', () {
    testWidgets('puts the navigation on the side below the rail width', (
      tester,
    ) async {
      final call = await _pump(
        tester,
        const Size(500, 300),
        verticalBarEdge: FoldableNavigationEdge.end,
      );

      expect(call.placement, const FoldableNavigationPlacement.end());
      expect(_rect(tester, _navKey), const Rect.fromLTRB(428, 0, 500, 300));
    });

    testWidgets('an edge that follows the hardware ignores the language', (
      tester,
    ) async {
      await _pump(
        tester,
        const Size(500, 300),
        rtl: true,
        verticalBarEdge: FoldableNavigationEdge.right,
      );

      expect(_rect(tester, _navKey).right, 500);
    });

    testWidgets('a null edge changes nothing', (tester) async {
      tester.view.physicalSize = const Size(500, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FoldableNavigationPlacement? seen;

      await tester.pumpWidget(
        MaterialApp(
          home: FoldableVerticalBarScope(
            edge: null,
            child: FoldableScaffold(
              body: const Text('body'),
              navigationBuilder: (context, p, constraints, padding) {
                seen = p;
                return const SizedBox(height: 56);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(seen, const FoldableNavigationPlacement.bottom());
    });

    test('refuses none, which is null', () {
      expect(
        () => FoldableVerticalBarScope(
          edge: FoldableNavigationEdge.none,
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('the scaffold follows a change of the edge', (tester) async {
      Widget app(FoldableNavigationEdge? edge) => MaterialApp(
        home: FoldableVerticalBarScope(
          edge: edge,
          child: FoldableScaffold(
            body: const Text('body'),
            navigationBuilder: (context, p, constraints, padding) => p.isSide
                ? SizedBox.expand(key: _navKey, child: Text(p.edge.name))
                : SizedBox(key: _navKey, height: 56, child: Text(p.edge.name)),
          ),
        ),
      );
      tester.view.physicalSize = const Size(500, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      expect(find.text('bottom'), findsOneWidget);

      await tester.pumpWidget(app(FoldableNavigationEdge.start));
      await tester.pumpAndSettle();
      expect(find.text('start'), findsOneWidget);
      expect(find.text('bottom'), findsNothing);
      expect(_rect(tester, _navKey).left, 0);

      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      expect(find.text('bottom'), findsOneWidget);
    });
  });

  group('the navigation slots', () {
    testWidgets('primaryNavigation is the navigation of a side', (
      tester,
    ) async {
      await _pump(
        tester,
        const Size(900, 600),
        useSlots: true,
        placement: (_) => const FoldableNavigationPlacement.end(),
      );

      expect(find.text('rail'), findsOneWidget);
      expect(find.text('bar'), findsNothing);
      expect(_rect(tester, const Key('rail')).right, 900);
    });

    testWidgets('bottomNavigationBar is the navigation below the panes', (
      tester,
    ) async {
      await _pump(tester, const Size(400, 600), useSlots: true);

      expect(find.text('bar'), findsOneWidget);
      expect(find.text('rail'), findsNothing);
      expect(_rect(tester, const Key('bar')).bottom, 600);
    });

    testWidgets('bottomNavigationBar is also the navigation above the panes', (
      tester,
    ) async {
      await _pump(
        tester,
        const Size(900, 600),
        useSlots: true,
        placement: (_) => const FoldableNavigationPlacement.top(),
      );

      expect(find.text('bar'), findsOneWidget);
      expect(_rect(tester, const Key('bar')).top, 0);
    });

    test('a navigationBuilder excludes the slots', () {
      Widget? builder(
        BuildContext c,
        FoldableNavigationPlacement p,
        BoxConstraints k,
        EdgeInsets pad,
      ) => null;

      for (final make in <FoldableScaffold Function()>[
        () => FoldableScaffold(
          body: const SizedBox(),
          navigationBuilder: builder,
          primaryNavigation: const SizedBox(),
        ),
        () => FoldableScaffold(
          body: const SizedBox(),
          navigationBuilder: builder,
          bottomNavigationBar: const SizedBox(),
        ),
        () => FoldableScaffold(
          body: const SizedBox(),
          navigationBuilder: builder,
          primaryNavigationBuilder: (c, k, p) => const SizedBox(),
        ),
        () => FoldableScaffold(
          body: const SizedBox(),
          navigationBuilder: builder,
          bottomNavigationBarBuilder: (c, k) => const SizedBox(),
        ),
      ]) {
        expect(make, throwsAssertionError);
      }
    });

    testWidgets('a navigationBuilder that returns null shows nothing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: FoldableScaffold(
            body: const Text('body'),
            navigationBuilder: (context, p, constraints, padding) => null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('body'), findsOneWidget);
    });
  });

  group('moving the navigation', () {
    testWidgets('the panes keep their state when the edge changes', (
      tester,
    ) async {
      FoldableNavigationPlacement placement =
          const FoldableNavigationPlacement.bottom();
      late StateSetter setOuter;

      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return FoldableScaffold(
                navigationPlacement: (_) => placement,
                body: const _Probe(),
                navigationBuilder: (context, p, constraints, padding) =>
                    SizedBox(
                      key: _navKey,
                      height: p.isSide ? null : 56,
                      child: Text(p.edge.name),
                    ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(_Probe));

      for (final next in [
        const FoldableNavigationPlacement.start(),
        const FoldableNavigationPlacement.end(),
        const FoldableNavigationPlacement.top(),
        const FoldableNavigationPlacement.none(),
        const FoldableNavigationPlacement.bottom(),
      ]) {
        setOuter(() => placement = next);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(_Probe)), same(state), reason: '$next');
      }
    });

    testWidgets('one navigation at a time: the edge it left is empty', (
      tester,
    ) async {
      await _pump(
        tester,
        const Size(900, 600),
        placement: (_) => const FoldableNavigationPlacement.left(),
      );
      expect(find.byKey(_navKey), findsOneWidget);

      await _pump(
        tester,
        const Size(900, 600),
        placement: (_) => const FoldableNavigationPlacement.right(),
      );
      expect(find.byKey(_navKey), findsOneWidget);
      expect(_rect(tester, _navKey).left, 828);
      expect(
        find.byKey(const Key('primary_navigation_builder')),
        findsOneWidget,
      );
    });
  });

  group('a navigation beside the panes and a hinge', () {
    DisplayFeature hinge() => const DisplayFeature(
      bounds: Rect.fromLTRB(480, 0, 520, 600),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    );

    testWidgets('on the left, the panes start after it', (tester) async {
      await _pump(
        tester,
        const Size(1000, 600),
        secondary: true,
        features: [hinge()],
        placement: (_) => const FoldableNavigationPlacement.left(),
      );

      final body = _rect(tester, const Key('body_builder'));
      final secondary = _rect(tester, const Key('secondary_body_builder'));
      expect(body.left, 72);
      expect(body.right, 480);
      expect(secondary.left, 520);
      expect(secondary.right, 1000);
    });

    testWidgets('on the right, the panes start at the edge', (tester) async {
      await _pump(
        tester,
        const Size(1000, 600),
        secondary: true,
        features: [hinge()],
        placement: (_) => const FoldableNavigationPlacement.right(),
      );

      final body = _rect(tester, const Key('body_builder'));
      final secondary = _rect(tester, const Key('secondary_body_builder'));
      expect(body.left, 0);
      expect(body.right, 480);
      expect(secondary.left, 520);
      expect(secondary.right, 928);
    });

    testWidgets('below the panes, the hinge is where it was', (tester) async {
      await _pump(
        tester,
        const Size(1000, 600),
        secondary: true,
        features: [hinge()],
        placement: (_) => const FoldableNavigationPlacement.bottom(),
      );

      final body = _rect(tester, const Key('body_builder'));
      final secondary = _rect(tester, const Key('secondary_body_builder'));
      expect(body.right, 480);
      expect(secondary.left, 520);
      expect(secondary.right, 1000);
    });
  });
}
