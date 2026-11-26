import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// A fold or hinge of the device, as reported by
/// [MediaQuery.displayFeaturesOf].
///
/// Android reports one for foldables (a Galaxy Z Fold, a Pixel Fold) and
/// dual-screen devices, and iOS for iPhone Duo-like ones. Other platforms
/// report none, and the layout is then the same as without this class.
///
/// A fold that is **separating** ([isSeparating]) cuts the window in two parts
/// that must not be drawn across: the hinge of a dual-screen device, or a fold
/// that is half open (the book or the tabletop posture). `FoldableScaffold`
/// puts one pane on each side: left and right of a vertical fold ([axis] is
/// [Axis.vertical], the book posture), body on top and secondary body below a
/// horizontal one ([axis] is [Axis.horizontal], the tabletop posture, or the
/// hinge of a device held in portrait). A flat fold is only a crease: the
/// content may cross it, and for a vertical one the scaffold lines its divider
/// up with it instead. A flat horizontal fold means nothing to the layout and
/// is never reported by [fromFeatures].
@immutable
class FoldableFold {
  const FoldableFold({
    required this.bounds,
    required this.isSeparating,
    this.axis = Axis.vertical,
  });

  /// The fold or hinge among [features] that applies to a window of
  /// [windowSize], or null when there is none.
  ///
  /// * A **vertical** fold or hinge runs from the top to the bottom of the
  ///   window (at least 90% of its height) and lies inside it. It applies
  ///   whatever its state, flat or not.
  /// * A **horizontal** one runs across the window (at least 90% of its width)
  ///   and lies inside it. It applies only when it separates the screen
  ///   ([isSeparating]): a hinge, or a fold that is half open. A flat horizontal
  ///   fold is ignored like a cutout, so the width alone decides the layout.
  /// * Cutouts and anything else are ignored.
  ///
  /// With several folds, the first one of [features] that applies wins, except
  /// that a flat vertical fold gives way to a separating horizontal one found
  /// later in the list: a hinge that cuts the screen matters more than a crease
  /// the content may cross.
  ///
  /// [vertical] and [horizontal] switch an orientation off, for a caller that
  /// can only follow one of them (a scaffold that spans the width of the window
  /// but not its height can only follow a vertical fold).
  static FoldableFold? fromFeatures(
    List<DisplayFeature> features,
    Size windowSize, {
    bool vertical = true,
    bool horizontal = true,
  }) {
    FoldableFold? flatVertical;
    for (final feature in features) {
      final fold = _fromFeature(feature, windowSize);
      if (fold == null) continue;
      if (fold.isVertical) {
        // The first vertical fold is the one; after a flat one, only a hinge
        // across the screen can still replace it.
        if (!vertical || flatVertical != null) continue;
        if (fold.isSeparating) return fold;
        flatVertical = fold;
      } else {
        if (!horizontal || !fold.isSeparating) continue;
        return fold;
      }
    }
    return flatVertical;
  }

  static FoldableFold? _fromFeature(DisplayFeature feature, Size windowSize) {
    final isFold =
        feature.type == DisplayFeatureType.fold ||
        feature.type == DisplayFeatureType.hinge;
    if (!isFold) return null;
    final bounds = feature.bounds;
    final isVertical =
        bounds.height >= windowSize.height * 0.9 &&
        bounds.width < bounds.height;
    final isHorizontal =
        bounds.width >= windowSize.width * 0.9 && bounds.height < bounds.width;
    final isSeparating =
        // A hinge hides what is under it; a half-open fold bends the screen.
        feature.type == DisplayFeatureType.hinge ||
        feature.state == DisplayFeatureState.postureHalfOpened;
    if (isVertical && bounds.left > 0 && bounds.right < windowSize.width) {
      return FoldableFold(bounds: bounds, isSeparating: isSeparating);
    }
    if (isHorizontal && bounds.top > 0 && bounds.bottom < windowSize.height) {
      return FoldableFold(
        bounds: bounds,
        isSeparating: isSeparating,
        axis: Axis.horizontal,
      );
    }
    return null;
  }

  /// The fold of the closest [MediaQuery], if the device has one that applies:
  /// see [fromFeatures] for which ones do and how one is picked.
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

  /// The direction the fold line runs in: [Axis.vertical] for a fold from the
  /// top to the bottom of the window (the two sides are left and right of it),
  /// [Axis.horizontal] for one across the window (the sides are above and
  /// below it). Not the axis the panes are laid out along, which is the other
  /// one: see [paneAxis].
  final Axis axis;

  /// Whether the fold runs from the top to the bottom of the window.
  bool get isVertical => axis == Axis.vertical;

  /// Whether the fold runs across the window, from side to side.
  bool get isHorizontal => axis == Axis.horizontal;

  /// The axis the two sides of the fold are laid out along: [Axis.horizontal]
  /// (side by side) for a vertical fold, [Axis.vertical] (stacked) for a
  /// horizontal one.
  Axis get paneAxis => isVertical ? Axis.horizontal : Axis.vertical;

  /// The position of the middle of the fold across its direction: the
  /// horizontal position of a vertical fold, the vertical position of a
  /// horizontal one.
  double get center => isVertical ? bounds.center.dx : bounds.center.dy;

  @override
  bool operator ==(Object other) {
    return other is FoldableFold &&
        other.bounds == bounds &&
        other.isSeparating == isSeparating &&
        other.axis == axis;
  }

  @override
  int get hashCode => Object.hash(bounds, isSeparating, axis);

  @override
  String toString() =>
      'FoldableFold(bounds: $bounds, isSeparating: $isSeparating, '
      'axis: ${axis.name})';
}
