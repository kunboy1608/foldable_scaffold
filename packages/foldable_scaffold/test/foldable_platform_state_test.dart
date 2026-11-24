import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:foldable_scaffold/src/foldable_platform_scope.dart'
    show mergeDisplayFeatures;
import 'package:material_ui/material_ui.dart';

// The numbers are made up for the tests: they are not the sizes of a device.
Map<String, Object?> _region({
  double left = 0,
  double top = 100,
  double right = 50,
  double bottom = 200,
  Object? isActive = true,
  Object? margins = const {'left': 1, 'top': 2, 'right': 3, 'bottom': 4},
}) => {
  'left': left,
  'top': top,
  'right': right,
  'bottom': bottom,
  'isActive': isActive,
  'margins': margins,
};

Map<String, Object?> _map({
  Object? version = 1,
  Object? width = 400,
  Object? height = 800,
  Object? divisions = const <Object?>[],
  Object? occlusions = const <Object?>[],
  Object? verticalBarEdge = 'unspecified',
}) => {
  'version': version,
  'width': width,
  'height': height,
  'divisions': divisions,
  'occlusions': occlusions,
  'verticalBarEdge': verticalBarEdge,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FoldablePlatformState.fromMap', () {
    test('reads a full map', () {
      final state = FoldablePlatformState.fromMap(
        _map(
          divisions: [_region(left: 0, top: 390, right: 400, bottom: 410)],
          occlusions: [
            _region(isActive: false),
            _region(left: 10, top: 0, right: 20, bottom: 5),
          ],
          verticalBarEdge: 'trailing',
        ),
      );

      expect(state.version, 1);
      expect(state.viewSize, const Size(400, 800));
      expect(state.divisions, [
        const FoldableReservedRegion(
          frame: Rect.fromLTRB(0, 390, 400, 410),
          isActive: true,
          margins: EdgeInsets.fromLTRB(1, 2, 3, 4),
        ),
      ]);
      expect(state.occlusions, hasLength(2));
      expect(state.occlusions.first.isActive, isFalse);
      expect(state.verticalBarEdge, FoldableNavigationEdge.end);
    });

    test('maps the vertical bar edge', () {
      FoldablePlatformState edge(Object? value) =>
          FoldablePlatformState.fromMap(_map(verticalBarEdge: value));
      expect(edge('leading').verticalBarEdge, FoldableNavigationEdge.start);
      expect(edge('trailing').verticalBarEdge, FoldableNavigationEdge.end);
      expect(edge('unspecified').verticalBarEdge, isNull);
      expect(edge('left').verticalBarEdge, isNull);
      expect(edge('').verticalBarEdge, isNull);
      expect(edge(1).verticalBarEdge, isNull);
      expect(edge(null).verticalBarEdge, isNull);
    });

    test('anything that is not a map is empty', () {
      for (final data in <Object?>[
        null,
        'state',
        42,
        const <Object?>[],
        [_map()],
      ]) {
        expect(
          FoldablePlatformState.fromMap(data),
          FoldablePlatformState.empty,
        );
      }
    });

    test('accepts a map with other key types, as the platform codec gives', () {
      final state = FoldablePlatformState.fromMap(<Object?, Object?>{
        'version': 1,
        'verticalBarEdge': 'leading',
      });
      expect(state.verticalBarEdge, FoldableNavigationEdge.start);
    });

    test('an empty map is the defaults', () {
      expect(
        FoldablePlatformState.fromMap(const {}),
        FoldablePlatformState.empty,
      );
      final state = FoldablePlatformState.empty;
      expect(state.version, 0);
      expect(state.viewSize, Size.zero);
      expect(state.divisions, isEmpty);
      expect(state.occlusions, isEmpty);
      expect(state.verticalBarEdge, isNull);
      expect(state.displayFeatures, isEmpty);
    });

    test('missing fields take their default one by one', () {
      final state = FoldablePlatformState.fromMap({
        'divisions': [_region()],
        'width': 300,
      });
      expect(state.version, 0);
      expect(state.viewSize, const Size(300, 0));
      expect(state.divisions, hasLength(1));
      expect(state.occlusions, isEmpty);
      expect(state.verticalBarEdge, isNull);
    });

    test('wrong types and values fall back to the defaults', () {
      final state = FoldablePlatformState.fromMap(
        _map(
          version: 'one',
          width: 'wide',
          height: double.nan,
          divisions: 'none',
          occlusions: {'a': 1},
        ),
      );
      expect(state.version, 0);
      expect(state.viewSize, Size.zero);
      expect(state.divisions, isEmpty);
      expect(state.occlusions, isEmpty);

      expect(
        FoldablePlatformState.fromMap(_map(width: -5, height: -1)).viewSize,
        Size.zero,
      );
      expect(
        FoldablePlatformState.fromMap(_map(width: double.infinity)).viewSize,
        const Size(0, 800),
      );
    });

    test('an unknown version is read all the same', () {
      final state = FoldablePlatformState.fromMap(
        _map(version: 7, divisions: [_region()]),
      );
      expect(state.version, 7);
      expect(state.divisions, hasLength(1));
    });

    test('a malformed region is skipped, the others are kept', () {
      final state = FoldablePlatformState.fromMap(
        _map(
          divisions: [
            _region(),
            'region',
            null,
            const {'left': 0, 'top': 0, 'right': 10},
            _region(bottom: double.nan),
            _region(left: 5, top: 5, right: 9, bottom: 9),
          ],
        ),
      );
      expect(state.divisions.map((r) => r.frame), [
        const Rect.fromLTRB(0, 100, 50, 200),
        const Rect.fromLTRB(5, 5, 9, 9),
      ]);
    });

    test('a region has safe defaults for isActive and margins', () {
      final region = FoldableReservedRegion.tryParse(const {
        'left': 1,
        'top': 2,
        'right': 3,
        'bottom': 4,
      });
      expect(region!.isActive, isFalse);
      expect(region.margins, EdgeInsets.zero);

      final wrong = FoldableReservedRegion.tryParse(
        _region(isActive: 'yes', margins: 'big'),
      );
      expect(wrong!.isActive, isFalse);
      expect(wrong.margins, EdgeInsets.zero);

      final partial = FoldableReservedRegion.tryParse(
        _region(margins: const {'left': 8, 'top': 'x'}),
      );
      expect(partial!.margins, const EdgeInsets.only(left: 8));
    });

    test('a region with its sides swapped is normalised', () {
      final region = FoldableReservedRegion.tryParse(
        _region(left: 50, top: 200, right: 0, bottom: 100),
      );
      expect(region!.frame, const Rect.fromLTRB(0, 100, 50, 200));
    });

    test('a region can extend past the view', () {
      final region = FoldableReservedRegion.tryParse(
        _region(left: -10, top: -5, right: 30, bottom: 20),
      );
      expect(region!.frame, const Rect.fromLTRB(-10, -5, 30, 20));
    });
  });

  group('display features', () {
    test('an active division is a half open fold', () {
      final state = FoldablePlatformState.fromMap(
        _map(divisions: [_region(left: 195, top: 0, right: 205, bottom: 800)]),
      );
      expect(state.displayFeatures, [
        const DisplayFeature(
          bounds: Rect.fromLTRB(195, 0, 205, 800),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]);
    });

    test('an inactive division is not a feature, but is kept in the state', () {
      final state = FoldablePlatformState.fromMap(
        _map(divisions: [_region(isActive: false)]),
      );
      expect(state.displayFeatures, isEmpty);
      expect(state.divisions, hasLength(1));
    });

    test('an active occlusion is a cutout, state unknown', () {
      final state = FoldablePlatformState.fromMap(
        _map(
          occlusions: [
            _region(left: 100, top: 0, right: 160, bottom: 30),
            _region(left: 0, top: 0, right: 10, bottom: 10, isActive: false),
          ],
        ),
      );
      expect(state.displayFeatures, [
        const DisplayFeature(
          bounds: Rect.fromLTRB(100, 0, 160, 30),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ]);
      expect(state.occlusions, hasLength(2));
    });

    test('divisions come first, then occlusions', () {
      final state = FoldablePlatformState.fromMap(
        _map(
          occlusions: [_region(left: 1, top: 1, right: 2, bottom: 2)],
          divisions: [_region(left: 5, top: 0, right: 6, bottom: 9)],
        ),
      );
      expect(state.displayFeatures.map((f) => f.type), [
        DisplayFeatureType.fold,
        DisplayFeatureType.cutout,
      ]);
    });
  });

  group('value semantics', () {
    test('equal states are equal and have the same hash code', () {
      FoldablePlatformState make() => FoldablePlatformState.fromMap(
        _map(
          divisions: [_region()],
          occlusions: [_region(left: 3)],
          verticalBarEdge: 'leading',
        ),
      );
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make().divisions.first.hashCode, make().divisions.first.hashCode);
    });

    test('a difference in any field makes states differ', () {
      final base = FoldablePlatformState.fromMap(
        _map(divisions: [_region()], verticalBarEdge: 'leading'),
      );
      for (final other in [
        _map(divisions: [_region()], verticalBarEdge: 'trailing'),
        _map(divisions: [_region(isActive: false)], verticalBarEdge: 'leading'),
        _map(divisions: [_region(right: 51)], verticalBarEdge: 'leading'),
        _map(divisions: const [], verticalBarEdge: 'leading'),
        _map(
          divisions: [_region()],
          occlusions: [_region()],
          verticalBarEdge: 'leading',
        ),
        _map(divisions: [_region()], verticalBarEdge: 'leading', width: 401),
        _map(divisions: [_region()], verticalBarEdge: 'leading', version: 2),
        _map(
          divisions: [
            _region(margins: const {'left': 9}),
          ],
          verticalBarEdge: 'leading',
        ),
      ]) {
        expect(FoldablePlatformState.fromMap(other), isNot(base));
      }
    });
  });

  group('mergeDisplayFeatures', () {
    const fold = DisplayFeature(
      bounds: Rect.fromLTRB(0, 10, 20, 10),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    );
    const hinge = DisplayFeature(
      bounds: Rect.fromLTRB(5, 0, 6, 9),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    );

    test('keeps the base and adds what it lacks', () {
      expect(mergeDisplayFeatures([hinge], [fold]), [hinge, fold]);
    });

    test('drops duplicates', () {
      expect(mergeDisplayFeatures([fold, hinge], [fold]), [fold, hinge]);
      expect(mergeDisplayFeatures(const [], [fold, fold]), [fold]);
    });

    test('a feature of another type or state at the same place is kept', () {
      const flat = DisplayFeature(
        bounds: Rect.fromLTRB(0, 10, 20, 10),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );
      expect(mergeDisplayFeatures([fold], [flat]), [fold, flat]);
    });

    test('nothing to add returns the base', () {
      final base = [hinge];
      expect(mergeDisplayFeatures(base, const []), same(base));
    });
  });

  group('ChannelFoldablePlatformSource', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const method = MethodChannel('test/platform');
    const events = EventChannel('test/platform/events');

    tearDown(() {
      messenger.setMockMethodCallHandler(method, null);
      messenger.setMockStreamHandler(events, null);
    });

    test('has the channel names of the plugin', () {
      expect(
        ChannelFoldablePlatformSource.methodChannelName,
        'foldable_scaffold/platform',
      );
      expect(
        ChannelFoldablePlatformSource.eventChannelName,
        'foldable_scaffold/platform/events',
      );
    });

    test('getState parses the map of the platform', () async {
      messenger.setMockMethodCallHandler(method, (call) async {
        expect(call.method, 'getState');
        return _map(verticalBarEdge: 'trailing', divisions: [_region()]);
      });
      final source = ChannelFoldablePlatformSource(
        methodChannel: method,
        eventChannel: events,
      );
      final state = await source.getState();
      expect(state.verticalBarEdge, FoldableNavigationEdge.end);
      expect(state.divisions, hasLength(1));
    });

    test('getState is empty without a plugin or when it fails', () async {
      final source = ChannelFoldablePlatformSource(
        methodChannel: method,
        eventChannel: events,
      );
      // No handler: MissingPluginException.
      expect(await source.getState(), FoldablePlatformState.empty);

      messenger.setMockMethodCallHandler(method, (call) async {
        throw PlatformException(code: 'broken');
      });
      expect(await source.getState(), FoldablePlatformState.empty);

      messenger.setMockMethodCallHandler(method, (call) async => 'nonsense');
      expect(await source.getState(), FoldablePlatformState.empty);
    });

    test('stateChanges sends each event, parsed', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success(_map(verticalBarEdge: 'leading'));
            sink.success('nonsense');
            sink.success(_map(verticalBarEdge: 'trailing'));
          },
        ),
      );
      final source = ChannelFoldablePlatformSource(
        methodChannel: method,
        eventChannel: events,
      );
      final states = await source.stateChanges.take(3).toList();
      expect(states.map((s) => s.verticalBarEdge), [
        FoldableNavigationEdge.start,
        null,
        FoldableNavigationEdge.end,
      ]);
    });

    test('stateChanges swallows the errors of the platform', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.error(code: 'broken');
            sink.success(_map(verticalBarEdge: 'leading'));
          },
        ),
      );
      final source = ChannelFoldablePlatformSource(
        methodChannel: method,
        eventChannel: events,
      );
      final state = await source.stateChanges.first;
      expect(state.verticalBarEdge, FoldableNavigationEdge.start);
    });

    test('stateChanges without a plugin has no events and no error', () async {
      final source = ChannelFoldablePlatformSource(
        methodChannel: method,
        eventChannel: events,
      );
      final errors = <Object>[];
      final subscription = source.stateChanges.listen(
        (_) {},
        onError: errors.add,
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(errors, isEmpty);
    });
  });
}
