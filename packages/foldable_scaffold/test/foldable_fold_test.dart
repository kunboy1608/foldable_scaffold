import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect, Size;

import 'package:flutter/widgets.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:foldable_scaffold/src/foldable_scaffold_layout.dart'
    show resolveFold;

const _window = Size(800, 1200);

DisplayFeature _feature(
  Rect bounds, {
  DisplayFeatureType type = DisplayFeatureType.hinge,
  DisplayFeatureState state = DisplayFeatureState.postureFlat,
}) => DisplayFeature(bounds: bounds, type: type, state: state);

// A vertical hinge and a horizontal one, in the 800x1200 window.
final _verticalHinge = _feature(const Rect.fromLTRB(390, 0, 410, 1200));
final _horizontalHinge = _feature(const Rect.fromLTRB(0, 580, 800, 620));

void main() {
  group('FoldableFold', () {
    test('keeps the old constructor: a fold is vertical by default', () {
      const fold = FoldableFold(
        bounds: Rect.fromLTRB(390, 0, 410, 1200),
        isSeparating: true,
      );

      expect(fold.axis, Axis.vertical);
      expect(fold.isVertical, isTrue);
      expect(fold.isHorizontal, isFalse);
      expect(fold.paneAxis, Axis.horizontal);
      expect(fold.center, 400);
    });

    test('a horizontal fold knows its direction and its center', () {
      const fold = FoldableFold(
        bounds: Rect.fromLTRB(0, 580, 800, 620),
        isSeparating: true,
        axis: Axis.horizontal,
      );

      expect(fold.isHorizontal, isTrue);
      expect(fold.isVertical, isFalse);
      expect(fold.paneAxis, Axis.vertical);
      expect(fold.center, 600);
    });

    test('compares by value, the axis included', () {
      const bounds = Rect.fromLTRB(0, 580, 800, 620);
      expect(
        const FoldableFold(
          bounds: bounds,
          isSeparating: true,
          axis: Axis.horizontal,
        ),
        const FoldableFold(
          bounds: bounds,
          isSeparating: true,
          axis: Axis.horizontal,
        ),
      );
      expect(
        const FoldableFold(bounds: bounds, isSeparating: true),
        isNot(
          const FoldableFold(
            bounds: bounds,
            isSeparating: true,
            axis: Axis.horizontal,
          ),
        ),
      );
      expect(
        const FoldableFold(
          bounds: bounds,
          isSeparating: true,
          axis: Axis.horizontal,
        ).hashCode,
        const FoldableFold(
          bounds: bounds,
          isSeparating: true,
          axis: Axis.horizontal,
        ).hashCode,
      );
    });
  });

  group('FoldableFold.fromFeatures', () {
    test('a vertical hinge is vertical and separating', () {
      final fold = FoldableFold.fromFeatures([_verticalHinge], _window);

      expect(fold, isNotNull);
      expect(fold!.isVertical, isTrue);
      expect(fold.isSeparating, isTrue);
    });

    test('a horizontal hinge is horizontal and separating', () {
      final fold = FoldableFold.fromFeatures([_horizontalHinge], _window);

      expect(fold, isNotNull);
      expect(fold!.isHorizontal, isTrue);
      expect(fold.isSeparating, isTrue);
      expect(fold.bounds, const Rect.fromLTRB(0, 580, 800, 620));
    });

    test('a half-open horizontal fold separates', () {
      final fold = FoldableFold.fromFeatures([
        _feature(
          const Rect.fromLTRB(0, 600, 800, 600),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ], _window);

      expect(fold?.isHorizontal, isTrue);
      expect(fold?.isSeparating, isTrue);
    });

    test('a flat horizontal fold is ignored like a cutout', () {
      expect(
        FoldableFold.fromFeatures([
          _feature(
            const Rect.fromLTRB(0, 600, 800, 600),
            type: DisplayFeatureType.fold,
          ),
        ], _window),
        isNull,
      );
    });

    test('a flat vertical fold still applies, as before', () {
      final fold = FoldableFold.fromFeatures([
        _feature(
          const Rect.fromLTRB(400, 0, 400, 1200),
          type: DisplayFeatureType.fold,
        ),
      ], _window);

      expect(fold?.isVertical, isTrue);
      expect(fold?.isSeparating, isFalse);
    });

    test('cutouts, and folds along an edge, are ignored', () {
      expect(
        FoldableFold.fromFeatures([
          _feature(
            const Rect.fromLTRB(300, 0, 500, 40),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
          // A horizontal hinge on the very top edge is not inside the window.
          _feature(const Rect.fromLTRB(0, 0, 800, 20)),
          // A short one does not cross the window.
          _feature(const Rect.fromLTRB(0, 580, 300, 620)),
        ], _window),
        isNull,
      );
    });

    test('the first applicable fold wins', () {
      expect(
        FoldableFold.fromFeatures([
          _verticalHinge,
          _horizontalHinge,
        ], _window)?.isVertical,
        isTrue,
      );
      expect(
        FoldableFold.fromFeatures([
          _horizontalHinge,
          _verticalHinge,
        ], _window)?.isHorizontal,
        isTrue,
      );
    });

    test('a flat vertical fold gives way to a separating horizontal one', () {
      final flatVertical = _feature(
        const Rect.fromLTRB(400, 0, 400, 1200),
        type: DisplayFeatureType.fold,
      );

      expect(
        FoldableFold.fromFeatures([
          flatVertical,
          _horizontalHinge,
        ], _window)?.isHorizontal,
        isTrue,
      );
      // Without the hinge it is still the fold.
      expect(
        FoldableFold.fromFeatures([flatVertical], _window)?.isVertical,
        isTrue,
      );
    });

    test('a flat vertical fold is not replaced by a later vertical hinge', () {
      // The first vertical fold has always been the one: nothing changes
      // for devices that only have vertical folds.
      final flatVertical = _feature(
        const Rect.fromLTRB(400, 0, 400, 1200),
        type: DisplayFeatureType.fold,
      );

      expect(
        FoldableFold.fromFeatures([flatVertical, _verticalHinge], _window),
        FoldableFold.fromFeatures([flatVertical], _window),
      );
    });

    test('vertical and horizontal can be switched off', () {
      expect(
        FoldableFold.fromFeatures(
          [_verticalHinge, _horizontalHinge],
          _window,
          vertical: false,
        )?.isHorizontal,
        isTrue,
      );
      expect(
        FoldableFold.fromFeatures(
          [_horizontalHinge, _verticalHinge],
          _window,
          horizontal: false,
        )?.isVertical,
        isTrue,
      );
      expect(
        FoldableFold.fromFeatures(
          [_horizontalHinge],
          _window,
          horizontal: false,
        ),
        isNull,
      );
    });
  });

  group('resolveFold', () {
    test('a vertical fold needs the scaffold as wide as the window', () {
      expect(
        resolveFold(
          scaffoldWidth: 800,
          windowSize: _window,
          displayFeatures: [_verticalHinge],
          followFold: true,
        ),
        isNotNull,
      );
      expect(
        resolveFold(
          scaffoldWidth: 700,
          windowSize: _window,
          displayFeatures: [_verticalHinge],
          followFold: true,
        ),
        isNull,
      );
    });

    test('a horizontal fold needs the scaffold as tall as the window', () {
      expect(
        resolveFold(
          scaffoldWidth: 800,
          scaffoldHeight: 1200,
          windowSize: _window,
          displayFeatures: [_horizontalHinge],
          followFold: true,
        )?.isHorizontal,
        isTrue,
      );
      expect(
        resolveFold(
          scaffoldWidth: 800,
          scaffoldHeight: 1100,
          windowSize: _window,
          displayFeatures: [_horizontalHinge],
          followFold: true,
        ),
        isNull,
      );
      // Unknown height (the default): no horizontal fold.
      expect(
        resolveFold(
          scaffoldWidth: 800,
          windowSize: _window,
          displayFeatures: [_horizontalHinge],
          followFold: true,
        ),
        isNull,
      );
    });

    test('a scaffold that spans one direction only follows that fold', () {
      // As wide as the window, not as tall: the vertical hinge applies even
      // though the horizontal one comes first.
      final fold = resolveFold(
        scaffoldWidth: 800,
        scaffoldHeight: 1000,
        windowSize: _window,
        displayFeatures: [_horizontalHinge, _verticalHinge],
        followFold: true,
      );

      expect(fold?.isVertical, isTrue);
    });

    test('followFold: false ignores both', () {
      expect(
        resolveFold(
          scaffoldWidth: 800,
          scaffoldHeight: 1200,
          windowSize: _window,
          displayFeatures: [_horizontalHinge, _verticalHinge],
          followFold: false,
        ),
        isNull,
      );
    });
  });
}
