import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// The widths at which a `FoldableScaffold` changes its layout.
///
/// The defaults depend on the platform (see [FoldableBreakpoints.forPlatform]):
///
/// * [FoldableBreakpoints.handheld], for Android and iOS (also in a mobile
///   browser): shows two panes on the inner screen of a foldable or on a
///   tablet, but never on a phone, not even one held sideways.
/// * [FoldableBreakpoints.desktop], for everything else: two panes from a
///   window 1200 wide.
///
/// ```dart
/// FoldableScaffold(
///   breakpoints: const FoldableBreakpoints(split: 840),
///   // ...
/// )
/// ```
@immutable
class FoldableBreakpoints {
  const FoldableBreakpoints({
    this.rail = 600,
    this.wideRail = 1000,
    this.split = 1200,
    this.splitMinShortestSide = 0,
  });

  /// Handheld devices: Android and iOS.
  ///
  /// The body and the secondary body are shown side by side when the scaffold
  /// is [split] wide **and** the shortest side of the window is at least
  /// [splitMinShortestSide]. That is the `sw600dp` rule of Android, and it
  /// separates what folds open into a small tablet (the inner screen of a
  /// Galaxy Z Fold, an unfolded iPhone Fold) from a phone: a phone is at most
  /// about 480 on its short side, in either orientation, so it keeps one pane.
  const FoldableBreakpoints.handheld({
    this.rail = 600,
    this.wideRail = 1000,
    this.split = 600,
    this.splitMinShortestSide = 600,
  });

  /// Desktop, laptop and everything that is not a handheld: two panes from a
  /// width of 1200, whatever the height.
  const FoldableBreakpoints.desktop({
    this.rail = 600,
    this.wideRail = 1000,
    this.split = 1200,
    this.splitMinShortestSide = 0,
  });

  /// The default for [platform]: [FoldableBreakpoints.handheld] for Android and
  /// iOS, [FoldableBreakpoints.desktop] for the rest.
  ///
  /// On the web the platform is the one of the device the browser runs on, so a
  /// mobile browser on a foldable gets the handheld layout.
  factory FoldableBreakpoints.forPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS => const FoldableBreakpoints.handheld(),
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => const FoldableBreakpoints.desktop(),
    };
  }

  /// From this width the primary navigation is shown sideways, narrow
  /// ([FoldableScaffold.minWidthNavigation]). Below it, the bottom navigation.
  final double rail;

  /// Above this width the sideways navigation is wide
  /// ([FoldableScaffold.maxWidthNavigation]).
  final double wideRail;

  /// From this scaffold width the body and the secondary body can be shown
  /// side by side, provided [splitMinShortestSide] is met.
  final double split;

  /// The shortest side of the window must be at least this for two panes to be
  /// shown, even when the scaffold is [split] wide. Keeps a phone held sideways
  /// (wide but short) in a single pane. Zero turns the check off.
  final double splitMinShortestSide;

  /// Whether a scaffold [scaffoldWidth] wide, in a window of [windowSize], has
  /// room for two panes.
  bool canSplit(double scaffoldWidth, Size windowSize) {
    return scaffoldWidth >= split &&
        windowSize.shortestSide >= splitMinShortestSide;
  }

  /// A copy with the given values replaced.
  FoldableBreakpoints copyWith({
    double? rail,
    double? wideRail,
    double? split,
    double? splitMinShortestSide,
  }) {
    return FoldableBreakpoints(
      rail: rail ?? this.rail,
      wideRail: wideRail ?? this.wideRail,
      split: split ?? this.split,
      splitMinShortestSide: splitMinShortestSide ?? this.splitMinShortestSide,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoldableBreakpoints &&
        other.rail == rail &&
        other.wideRail == wideRail &&
        other.split == split &&
        other.splitMinShortestSide == splitMinShortestSide;
  }

  @override
  int get hashCode => Object.hash(rail, wideRail, split, splitMinShortestSide);

  @override
  String toString() =>
      'FoldableBreakpoints(rail: $rail, wideRail: $wideRail, split: $split, '
      'splitMinShortestSide: $splitMinShortestSide)';
}
