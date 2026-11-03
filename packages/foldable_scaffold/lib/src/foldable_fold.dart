import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// A vertical fold or hinge of the device, as reported by
/// [MediaQuery.displayFeaturesOf].
///
/// Android reports one for foldables (a Galaxy Z Fold, a Pixel Fold) and
/// dual-screen devices. Other platforms report none, and the layout is then
/// the same as without this class.
///
/// A fold that is **separating** ([isSeparating]) cuts the window in two parts
/// that must not be drawn across: the hinge of a dual-screen device, or a fold
/// that is half open (the book posture). `FoldableScaffold` puts one pane on
/// each side. A flat fold is only a crease: the content may cross it, and the
/// scaffold lines its divider up with it instead.
@immutable
class FoldableFold {
  const FoldableFold({required this.bounds, required this.isSeparating});

  /// The fold or hinge among [features] that runs from the top to the bottom of
  /// a window of [windowSize], or null when there is none.
  ///
  /// Horizontal folds (a laptop posture or the tabletop one) and cutouts are
  /// ignored: they do not split the width.
  static FoldableFold? fromFeatures(
    List<DisplayFeature> features,
    Size windowSize,
  ) {
    for (final feature in features) {
      final isFold =
          feature.type == DisplayFeatureType.fold ||
          feature.type == DisplayFeatureType.hinge;
      if (!isFold) continue;
      final bounds = feature.bounds;
      final isVertical =
          bounds.height >= windowSize.height * 0.9 &&
          bounds.width < bounds.height;
      final isInside = bounds.left > 0 && bounds.right < windowSize.width;
      if (!isVertical || !isInside) continue;
      return FoldableFold(
        bounds: bounds,
        // A hinge hides what is under it; a half-open fold bends the screen.
        isSeparating:
            feature.type == DisplayFeatureType.hinge ||
            feature.state == DisplayFeatureState.postureHalfOpened,
      );
    }
    return null;
  }

  /// The fold of the closest [MediaQuery], if the device has a vertical one.
  static FoldableFold? maybeOf(BuildContext context) {
    return fromFeatures(
      MediaQuery.displayFeaturesOf(context),
      MediaQuery.sizeOf(context),
    );
  }

  /// Where the fold is, in the coordinates of the window.
  final Rect bounds;

  /// Whether the two sides of the fold must be kept apart.
  ///
  /// True for a hinge and for a half-open fold; false for a flat fold.
  final bool isSeparating;

  /// The horizontal position of the middle of the fold.
  double get center => bounds.center.dx;

  @override
  bool operator ==(Object other) {
    return other is FoldableFold &&
        other.bounds == bounds &&
        other.isSeparating == isSeparating;
  }

  @override
  int get hashCode => Object.hash(bounds, isSeparating);

  @override
  String toString() =>
      'FoldableFold(bounds: $bounds, isSeparating: $isSeparating)';
}
