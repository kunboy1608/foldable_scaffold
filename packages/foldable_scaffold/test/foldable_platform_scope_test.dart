import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

// The numbers are made up for the tests: they are not the sizes of a device.
const _window = Size(800, 1200);

/// Narrow enough for one pane under the phone rules.
const _phone = Size(500, 1200);

/// A source the test drives: it answers [getState] with [state] and sends what
/// is added to [push].
class _FakeSource implements FoldablePlatformSource {
  _FakeSource([this.state = FoldablePlatformState.empty]);

  FoldablePlatformState state;
  int getStateCalls = 0;
  Completer<FoldablePlatformState>? hold;

  final _controller = StreamController<FoldablePlatformState>.broadcast();

  bool get hasListener => _controller.hasListener;

  void push(FoldablePlatformState next) {
    state = next;
    _controller.add(next);
  }

  @override
  Future<FoldablePlatformState> getState() {
    getStateCalls++;
    return hold?.future ?? Future.value(state);
  }

  @override
  Stream<FoldablePlatformState> get stateChanges => _controller.stream;
}

FoldablePlatformState _state({
  Rect? division,
  bool divisionActive = true,
  Rect? occlusion,
  FoldableNavigationEdge? edge,
}) => FoldablePlatformState(
  version: 1,
  viewSize: _window,
  divisions: [
    if (division != null)
      FoldableReservedRegion(frame: division, isActive: divisionActive),
  ],
  occlusions: [
    if (occlusion != null)
      FoldableReservedRegion(frame: occlusion, isActive: true),
  ],
  verticalBarEdge: edge,
);

/// What a probe below the scope sees.
class _Seen {
  List<DisplayFeature>? features;
  FoldableNavigationEdge? edge;
  FoldablePlatformState? state;
  int builds = 0;
}

Widget _probe(_Seen seen) => Builder(
  builder: (context) {
    seen
      ..features = MediaQuery.maybeOf(context)?.displayFeatures
      ..edge = FoldableVerticalBarScope.maybeOf(context)
      ..state = FoldablePlatformScope.maybeOf(context)
      ..builds += 1;
    return const SizedBox();
  },
);

class _Counter extends StatefulWidget {
  const _Counter();

  static int created = 0;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  void initState() {
    super.initState();
    _Counter.created++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// A frame, then the microtasks that the stream and the futures leave.
Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpScope(
  WidgetTester tester, {
  required Widget child,
  FoldablePlatformSource? source,
  Key? scopeKey,
}) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      // Like an app: the scope goes in the builder, below the MediaQuery.
      builder: (context, home) =>
          FoldablePlatformScope(key: scopeKey, source: source, child: home!),
      home: child,
    ),
  );
  await _flush(tester);
}

const _fold = DisplayFeature(
  bounds: Rect.fromLTRB(0, 590, 800, 610),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureHalfOpened,
);

void main() {
  group('on a platform that is not iOS', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      testWidgets('does nothing on $platform', (tester) async {
        final source = _FakeSource(
          _state(division: const Rect.fromLTRB(0, 590, 800, 610)),
        );
        final seen = _Seen();
        await _pumpScope(tester, source: source, child: _probe(seen));
        await _flush(tester);

        expect(seen.features, isEmpty);
        expect(seen.edge, isNull);
        expect(seen.state, isNull);
        expect(source.getStateCalls, 0);
        expect(source.hasListener, isFalse);
      }, variant: TargetPlatformVariant.only(platform));
    }

    testWidgets(
      'returns its child as it is, and never touches the channel',
      (tester) async {
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(ChannelFoldablePlatformSource.methodChannelName),
          (call) async {
            calls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel(
              ChannelFoldablePlatformSource.methodChannelName,
            ),
            null,
          ),
        );
        const child = SizedBox(key: Key('child'));
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: FoldablePlatformScope(child: child),
          ),
        );
        tester.binding.handleMetricsChanged();
        await _flush(tester);

        expect(find.byKey(const Key('child')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FoldablePlatformScope),
            matching: find.byType(FoldableVerticalBarScope),
          ),
          findsNothing,
        );
        expect(calls, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('on iOS', () {
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('provides the display features and the vertical bar edge', (
      tester,
    ) async {
      final source = _FakeSource(
        _state(
          division: const Rect.fromLTRB(0, 590, 800, 610),
          occlusion: const Rect.fromLTRB(300, 0, 500, 40),
          edge: FoldableNavigationEdge.end,
        ),
      );
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));
      await _flush(tester);

      expect(seen.features, [
        _fold,
        const DisplayFeature(
          bounds: Rect.fromLTRB(300, 0, 500, 40),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ]);
      expect(seen.edge, FoldableNavigationEdge.end);
      expect(seen.state, source.state);
      expect(source.getStateCalls, 1);
      expect(source.hasListener, isTrue);
    }, variant: ios);

    testWidgets('an inactive division is no fold', (tester) async {
      final source = _FakeSource(
        _state(
          division: const Rect.fromLTRB(0, 590, 800, 610),
          divisionActive: false,
        ),
      );
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));
      await _flush(tester);

      expect(seen.features, isEmpty);
      expect(seen.state!.divisions, hasLength(1));
    }, variant: ios);

    testWidgets('with nothing to report, changes nothing', (tester) async {
      final seen = _Seen();
      await _pumpScope(tester, source: _FakeSource(), child: _probe(seen));
      await _flush(tester);

      expect(seen.features, isEmpty);
      expect(seen.edge, isNull);
      expect(seen.state, FoldablePlatformState.empty);
    }, variant: ios);

    testWidgets('updates when the source pushes a new state', (tester) async {
      final source = _FakeSource();
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));
      await _flush(tester);
      expect(seen.features, isEmpty);

      source.push(
        _state(
          division: const Rect.fromLTRB(0, 590, 800, 610),
          edge: FoldableNavigationEdge.start,
        ),
      );
      await _flush(tester);
      expect(seen.features, [_fold]);
      expect(seen.edge, FoldableNavigationEdge.start);

      source.push(_state(edge: FoldableNavigationEdge.end));
      await _flush(tester);
      expect(seen.features, isEmpty);
      expect(seen.edge, FoldableNavigationEdge.end);
    }, variant: ios);

    testWidgets('an equal state does not rebuild the tree', (tester) async {
      final source = _FakeSource(_state(edge: FoldableNavigationEdge.end));
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));
      await _flush(tester);
      final builds = seen.builds;

      source.push(_state(edge: FoldableNavigationEdge.end));
      await _flush(tester);
      expect(seen.builds, builds);
    }, variant: ios);

    testWidgets('reads the state again when the metrics change', (
      tester,
    ) async {
      final source = _FakeSource();
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));
      await _flush(tester);
      expect(source.getStateCalls, 1);

      // The source changed without telling: only getState finds out.
      source.state = _state(edge: FoldableNavigationEdge.start);
      tester.binding.handleMetricsChanged();
      await _flush(tester);
      await _flush(tester);

      expect(source.getStateCalls, 2);
      expect(seen.edge, FoldableNavigationEdge.start);
    }, variant: ios);

    testWidgets('metrics changes during a read are folded into one more', (
      tester,
    ) async {
      final source = _FakeSource()..hold = Completer();
      await _pumpScope(tester, source: source, child: const SizedBox());
      expect(source.getStateCalls, 1);

      for (var i = 0; i < 5; i++) {
        tester.binding.handleMetricsChanged();
      }
      await _flush(tester);
      expect(source.getStateCalls, 1);

      source.hold!.complete(FoldablePlatformState.empty);
      source.hold = null;
      await _flush(tester);
      await _flush(tester);
      expect(source.getStateCalls, 2);
    }, variant: ios);

    testWidgets('an answer older than an event is dropped', (tester) async {
      final late = Completer<FoldablePlatformState>();
      final source = _FakeSource()..hold = late;
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));

      source.push(_state(edge: FoldableNavigationEdge.end));
      await _flush(tester);
      expect(seen.edge, FoldableNavigationEdge.end);

      // The first answer, from before the event, arrives last.
      late.complete(_state(edge: FoldableNavigationEdge.start));
      await _flush(tester);
      await _flush(tester);
      expect(seen.edge, FoldableNavigationEdge.end);
    }, variant: ios);

    testWidgets('a getState that throws keeps the last state', (tester) async {
      final source = _ThrowingSource();
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));
      await _flush(tester);
      expect(seen.state, FoldablePlatformState.empty);
      expect(tester.takeException(), isNull);
    }, variant: ios);

    testWidgets('an error in the stream is ignored', (tester) async {
      final source = _FakeSource();
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));
      source._controller.addError(StateError('broken'));
      await _flush(tester);
      source.push(_state(edge: FoldableNavigationEdge.end));
      await _flush(tester);
      expect(tester.takeException(), isNull);
      expect(seen.edge, FoldableNavigationEdge.end);
    }, variant: ios);

    testWidgets('dispose cancels the subscription and the observer', (
      tester,
    ) async {
      final source = _FakeSource();
      await _pumpScope(tester, source: source, child: const SizedBox());
      expect(source.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(source.hasListener, isFalse);

      // No read after dispose.
      final calls = source.getStateCalls;
      tester.binding.handleMetricsChanged();
      await _flush(tester);
      expect(source.getStateCalls, calls);
      expect(tester.takeException(), isNull);
    }, variant: ios);

    testWidgets('an answer that comes after dispose is ignored', (
      tester,
    ) async {
      final late = Completer<FoldablePlatformState>();
      final source = _FakeSource()..hold = late;
      await _pumpScope(tester, source: source, child: const SizedBox());

      await tester.pumpWidget(const SizedBox());
      late.complete(_state(edge: FoldableNavigationEdge.end));
      await _flush(tester);
      expect(tester.takeException(), isNull);
    }, variant: ios);

    testWidgets('changing the source moves the subscription', (tester) async {
      final first = _FakeSource();
      final second = _FakeSource(_state(edge: FoldableNavigationEdge.end));
      final seen = _Seen();
      Widget app(FoldablePlatformSource source) => MaterialApp(
        builder: (context, home) =>
            FoldablePlatformScope(source: source, child: home!),
        home: _probe(seen),
      );
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(first));
      await _flush(tester);
      expect(first.hasListener, isTrue);

      await tester.pumpWidget(app(second));
      await _flush(tester);
      expect(first.hasListener, isFalse);
      expect(second.hasListener, isTrue);
      expect(seen.edge, FoldableNavigationEdge.end);
    }, variant: ios);

    testWidgets('merges with the features the engine already reported', (
      tester,
    ) async {
      const engineHinge = DisplayFeature(
        bounds: Rect.fromLTRB(395, 0, 405, 1200),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      );
      tester.view.displayFeatures = [engineHinge, _fold];
      final source = _FakeSource(
        _state(
          // The same fold as the engine's: it is not added twice.
          division: _fold.bounds,
          occlusion: const Rect.fromLTRB(300, 0, 500, 40),
        ),
      );
      final seen = _Seen();
      await _pumpScope(tester, source: source, child: _probe(seen));
      await _flush(tester);

      expect(seen.features, [
        engineHinge,
        _fold,
        const DisplayFeature(
          bounds: Rect.fromLTRB(300, 0, 500, 40),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ]);
    }, variant: ios);

    testWidgets('keeps the engine features when the platform has none', (
      tester,
    ) async {
      tester.view.displayFeatures = [_fold];
      final seen = _Seen();
      await _pumpScope(tester, source: _FakeSource(), child: _probe(seen));
      await _flush(tester);
      expect(seen.features, [_fold]);
    }, variant: ios);

    testWidgets('the tree below keeps its state when a fold appears', (
      tester,
    ) async {
      _Counter.created = 0;
      final source = _FakeSource();
      await _pumpScope(tester, source: source, child: const _Counter());
      await _flush(tester);
      expect(_Counter.created, 1);

      source.push(
        _state(
          division: const Rect.fromLTRB(0, 590, 800, 610),
          edge: FoldableNavigationEdge.end,
        ),
      );
      await _flush(tester);
      source.push(FoldablePlatformState.empty);
      await _flush(tester);
      expect(_Counter.created, 1);
    }, variant: ios);

    testWidgets('provides the edge wherever it is', (tester) async {
      final source = _FakeSource(_state(edge: FoldableNavigationEdge.end));
      final seen = _Seen();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FoldablePlatformScope(source: source, child: _probe(seen)),
        ),
      );
      await _flush(tester);
      expect(seen.edge, FoldableNavigationEdge.end);
    }, variant: ios);
  });

  group('FoldableScaffold under the scope (iOS)', () {
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    Future<void> pumpApp(
      WidgetTester tester,
      FoldablePlatformSource source,
    ) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, home) =>
              FoldablePlatformScope(source: source, child: home!),
          home: FoldableScaffold(
            navigationBuilder: (context, placement, constraints, padding) =>
                SizedBox(
                  key: const Key('nav'),
                  width: placement.isSide ? 72 : null,
                  height: placement.isSide ? null : 60,
                  child: Text('nav ${placement.edge.name}'),
                ),
            body: const SizedBox(key: Key('pane_a')),
            hasSecondaryBody: true,
            secondaryBody: const SizedBox(key: Key('pane_b')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a horizontal division stacks the panes', (tester) async {
      final source = _FakeSource();
      await pumpApp(tester, source);
      // A phone width: one pane (the secondary body, which is the open message),
      // and the navigation below.
      expect(tester.getSize(find.byKey(const Key('pane_a'))).isEmpty, isTrue);
      expect(find.text('nav bottom'), findsOneWidget);

      source.push(_state(division: const Rect.fromLTRB(0, 590, 500, 610)));
      await tester.pumpAndSettle();

      final body = tester.getRect(find.byKey(const Key('pane_a')));
      final secondary = tester.getRect(find.byKey(const Key('pane_b')));
      expect(body.bottom, lessThanOrEqualTo(590));
      expect(secondary.top, greaterThanOrEqualTo(610));
      expect(body.top, lessThan(secondary.top));
      expect(body.width, 500);
      expect(secondary.width, 500);

      // The fold closes: back to one pane.
      source.push(
        _state(
          division: const Rect.fromLTRB(0, 590, 500, 610),
          divisionActive: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('pane_a'))).isEmpty, isTrue);
    }, variant: ios);

    testWidgets('a vertical bar on the end puts the navigation on the right', (
      tester,
    ) async {
      final source = _FakeSource();
      await pumpApp(tester, source);
      expect(find.text('nav bottom'), findsOneWidget);

      source.push(_state(edge: FoldableNavigationEdge.end));
      await tester.pumpAndSettle();

      expect(find.text('nav end'), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('nav'))).right, _phone.width);

      source.push(_state(edge: FoldableNavigationEdge.start));
      await tester.pumpAndSettle();
      expect(find.text('nav start'), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('nav'))).left, 0);

      source.push(FoldablePlatformState.empty);
      await tester.pumpAndSettle();
      expect(find.text('nav bottom'), findsOneWidget);
    }, variant: ios);
  });
}

class _ThrowingSource implements FoldablePlatformSource {
  @override
  Future<FoldablePlatformState> getState() => Future.error(StateError('no'));

  @override
  Stream<FoldablePlatformState> get stateChanges => const Stream.empty();
}
