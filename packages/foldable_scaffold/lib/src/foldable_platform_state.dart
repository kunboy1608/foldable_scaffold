import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'foldable_navigation.dart';

/// A region of the Flutter view that the platform reserves: the hinge of a
/// dual-screen phone (a division), or a camera or the Dynamic Island (an
/// occlusion).
///
/// On iOS it is a `UIView.ReservedRegion`. The numbers are in logical pixels
/// (points are logical pixels on iOS) and in the coordinates of the Flutter
/// view, which is the window when the view covers it. The [frame] includes the
/// [margins], and can start at negative coordinates or extend past the view
/// when the region only overlaps one of its corners.
@immutable
class FoldableReservedRegion {
  /// A region at [frame], [margins] wide around it.
  const FoldableReservedRegion({
    required this.frame,
    this.isActive = false,
    this.margins = EdgeInsets.zero,
  });

  /// Reads a region from the map the platform sent, or returns null when the
  /// four sides of the frame are not finite numbers. The other fields fall back
  /// to their defaults: not active, no margins. Never throws.
  static FoldableReservedRegion? tryParse(Object? data) {
    if (data is! Map) return null;
    final left = _number(data['left']);
    final top = _number(data['top']);
    final right = _number(data['right']);
    final bottom = _number(data['bottom']);
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    final margins = data['margins'];
    return FoldableReservedRegion(
      frame: Rect.fromLTRB(
        left < right ? left : right,
        top < bottom ? top : bottom,
        left < right ? right : left,
        top < bottom ? bottom : top,
      ),
      isActive: data['isActive'] == true,
      margins: margins is Map
          ? EdgeInsets.fromLTRB(
              _number(margins['left']) ?? 0,
              _number(margins['top']) ?? 0,
              _number(margins['right']) ?? 0,
              _number(margins['bottom']) ?? 0,
            )
          : EdgeInsets.zero,
    );
  }

  /// Where the region is, margins included.
  final Rect frame;

  /// Whether the region affects the view now.
  ///
  /// The fold of iPhone Duo is active when the device is partially open or
  /// closed, and inactive when it is fully open. The camera of the inner display
  /// is active only while it is in use.
  final bool isActive;

  /// The extra space around the reserved area, already part of [frame].
  final EdgeInsets margins;

  @override
  bool operator ==(Object other) =>
      other is FoldableReservedRegion &&
      other.frame == frame &&
      other.isActive == isActive &&
      other.margins == margins;

  @override
  int get hashCode => Object.hash(frame, isActive, margins);

  @override
  String toString() =>
      'FoldableReservedRegion($frame, ${isActive ? 'active' : 'inactive'}'
      '${margins == EdgeInsets.zero ? '' : ', margins: $margins'})';
}

/// What the platform knows about the display, which Flutter does not put in
/// `MediaQuery` yet.
///
/// It is the Dart side of the protocol of the iOS plugin of this package (see
/// [FoldablePlatformScope]): the reserved regions of the view and the edge where
/// the system places its vertical bars. It is immutable and compares by value.
/// [FoldablePlatformState.fromMap] reads what the platform sent and never
/// throws: whatever is missing or wrong falls back to the safe default, so a
/// state read from nonsense is [empty].
@immutable
class FoldablePlatformState {
  /// A state, for tests or a custom [FoldablePlatformSource].
  const FoldablePlatformState({
    this.version = 0,
    this.viewSize = Size.zero,
    this.divisions = const [],
    this.occlusions = const [],
    this.verticalBarEdge,
  });

  /// Reads the map the platform sent (see [FoldablePlatformSource]).
  ///
  /// The keys are `version` (int), `width` and `height` (the size of the view),
  /// `divisions` and `occlusions` (lists of maps with `left`, `top`, `right`,
  /// `bottom`, `isActive` and `margins`, see [FoldableReservedRegion.tryParse])
  /// and `verticalBarEdge` (`"leading"`, `"trailing"` or `"unspecified"`).
  /// Anything that is not a map gives [empty]; a missing or malformed field gets
  /// its default, a malformed region is skipped, and an unknown
  /// `verticalBarEdge` means none. Never throws.
  factory FoldablePlatformState.fromMap(Object? data) {
    if (data is! Map) return empty;
    final version = _number(data['version']);
    final width = _number(data['width']);
    final height = _number(data['height']);
    return FoldablePlatformState(
      version: version == null ? 0 : version.toInt(),
      viewSize: Size(
        width == null || width < 0 ? 0 : width,
        height == null || height < 0 ? 0 : height,
      ),
      divisions: _regions(data['divisions']),
      occlusions: _regions(data['occlusions']),
      verticalBarEdge: switch (data['verticalBarEdge']) {
        'leading' => FoldableNavigationEdge.start,
        'trailing' => FoldableNavigationEdge.end,
        _ => null,
      },
    );
  }

  /// The version of the protocol this code was written for. A platform that
  /// reports another version is still read, field by field.
  static const int protocolVersion = 1;

  /// Nothing known: no regions and no vertical bar. This is what a platform
  /// without the plugin (or without the SDK that has the data) gives.
  static const FoldablePlatformState empty = FoldablePlatformState();

  /// The protocol version the platform reported, 0 when it did not.
  final int version;

  /// The size of the view the regions are in, in logical pixels, or
  /// [Size.zero] when unknown.
  final Size viewSize;

  /// The regions that divide the content, such as the hinge of iPhone Duo.
  /// Includes the inactive ones: check [FoldableReservedRegion.isActive].
  final List<FoldableReservedRegion> divisions;

  /// The regions where hardware covers the content: the cameras and the
  /// Dynamic Island. Includes the inactive ones, such as the inner camera when
  /// it is not in use.
  final List<FoldableReservedRegion> occlusions;

  /// Where the system places its vertical bars: [FoldableNavigationEdge.start]
  /// for the leading edge, [FoldableNavigationEdge.end] for the trailing edge,
  /// null when the system has no preference (or the platform did not say).
  final FoldableNavigationEdge? verticalBarEdge;

  /// The reserved regions as display features, to put in
  /// `MediaQuery.displayFeatures`.
  ///
  /// Only the **active** regions are included: a division that is not active
  /// (the device is fully open) is no fold, and a camera that is off covers
  /// nothing, so neither changes the layout. Read [divisions] and [occlusions]
  /// for the inactive ones, to leave room for them.
  ///
  /// * An active division is a [DisplayFeatureType.fold] in
  ///   [DisplayFeatureState.postureHalfOpened]. Its bounds say which way it
  ///   runs: taller than wide is a vertical fold (a book), wider than tall a
  ///   horizontal one (a laptop).
  /// * An active occlusion is a [DisplayFeatureType.cutout] in
  ///   [DisplayFeatureState.unknown].
  List<DisplayFeature> get displayFeatures => [
    for (final region in divisions)
      if (region.isActive)
        DisplayFeature(
          bounds: region.frame,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
    for (final region in occlusions)
      if (region.isActive)
        DisplayFeature(
          bounds: region.frame,
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
  ];

  @override
  bool operator ==(Object other) =>
      other is FoldablePlatformState &&
      other.version == version &&
      other.viewSize == viewSize &&
      other.verticalBarEdge == verticalBarEdge &&
      listEquals(other.divisions, divisions) &&
      listEquals(other.occlusions, occlusions);

  @override
  int get hashCode => Object.hash(
    version,
    viewSize,
    verticalBarEdge,
    Object.hashAll(divisions),
    Object.hashAll(occlusions),
  );

  @override
  String toString() =>
      'FoldablePlatformState(version: $version, viewSize: $viewSize, '
      'divisions: $divisions, occlusions: $occlusions, '
      'verticalBarEdge: ${verticalBarEdge?.name})';
}

List<FoldableReservedRegion> _regions(Object? data) {
  if (data is! List) return const [];
  return [
    for (final item in data)
      if (FoldableReservedRegion.tryParse(item) case final region?) region,
  ];
}

double? _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;
