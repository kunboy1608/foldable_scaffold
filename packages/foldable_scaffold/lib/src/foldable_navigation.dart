import 'package:flutter/widgets.dart';

import 'foldable_breakpoints.dart';
import 'foldable_fold.dart';

/// The edge of the scaffold where the navigation is placed.
///
/// [start] and [end] follow the text direction: [start] is the left edge in
/// left-to-right text and the right edge in right-to-left text. [left] and
/// [right] are the physical edges, for a navigation that must stay on the
/// same side of the hardware whatever the language (the vertical bars of
/// iPhone Duo's outer display, for instance).
enum FoldableNavigationEdge {
  /// No navigation is shown.
  none,

  /// Below the panes. The scaffold gives it to [Scaffold.bottomNavigationBar],
  /// so the floating action button, `extendBody` and the insets work as usual.
  bottom,

  /// Above the panes, under the app bar.
  top,

  /// Beside the panes, on the start side of the text direction.
  start,

  /// Beside the panes, on the end side of the text direction.
  end,

  /// Beside the panes, on the physical left edge.
  left,

  /// Beside the panes, on the physical right edge.
  right;

  /// Whether the navigation is beside the panes: [start], [end], [left] or
  /// [right].
  bool get isSide =>
      this == start || this == end || this == left || this == right;

  /// Whether the navigation is above or below the panes: [top] or [bottom].
  bool get isHorizontalBar => this == top || this == bottom;

  /// The physical edge for [textDirection]: [none], [top], [bottom], [left] or
  /// [right] ([start] and [end] are resolved).
  FoldableNavigationEdge resolve(TextDirection textDirection) {
    final isRtl = textDirection == TextDirection.rtl;
    return switch (this) {
      start => isRtl ? right : left,
      end => isRtl ? left : right,
      _ => this,
    };
  }
}

/// Where the navigation goes, and how thick it is.
///
/// The scaffold asks for one with [FoldableScaffold.navigationPlacement], which
/// defaults to [defaultNavigationPlacement], and hands it to the navigation
/// builder, so the same builder can make a bar for [FoldableNavigationEdge.bottom]
/// and a rail for [FoldableNavigationEdge.start].
@immutable
class FoldableNavigationPlacement {
  /// A navigation on [edge], [extent] thick.
  const FoldableNavigationPlacement(this.edge, {this.extent})
    : assert(extent == null || extent >= 0, 'The extent cannot be negative.');

  /// No navigation.
  const FoldableNavigationPlacement.none() : this(FoldableNavigationEdge.none);

  /// Below the panes. A bottom navigation is as tall as the widget makes it.
  const FoldableNavigationPlacement.bottom()
    : this(FoldableNavigationEdge.bottom);

  /// Above the panes. A top navigation is as tall as the widget makes it.
  const FoldableNavigationPlacement.top() : this(FoldableNavigationEdge.top);

  /// Beside the panes, on the start side, [extent] wide.
  const FoldableNavigationPlacement.start({double? extent})
    : this(FoldableNavigationEdge.start, extent: extent);

  /// Beside the panes, on the end side, [extent] wide.
  const FoldableNavigationPlacement.end({double? extent})
    : this(FoldableNavigationEdge.end, extent: extent);

  /// Beside the panes, on the physical left edge, [extent] wide.
  const FoldableNavigationPlacement.left({double? extent})
    : this(FoldableNavigationEdge.left, extent: extent);

  /// Beside the panes, on the physical right edge, [extent] wide.
  const FoldableNavigationPlacement.right({double? extent})
    : this(FoldableNavigationEdge.right, extent: extent);

  /// Where the navigation is.
  final FoldableNavigationEdge edge;

  /// How wide a navigation beside the panes is, without the system inset on its
  /// side, which the scaffold adds.
  ///
  /// Null takes [FoldableScaffold.minWidthNavigation], or
  /// [FoldableScaffold.maxWidthNavigation] when the scaffold is wider than
  /// [FoldableBreakpoints.wideRail]. Ignored for a navigation above or below the
  /// panes, which is as tall as its widget.
  final double? extent;

  /// Whether the navigation is beside the panes.
  bool get isSide => edge.isSide;

  /// Whether there is a navigation at all.
  bool get isVisible => edge != FoldableNavigationEdge.none;

  @override
  bool operator ==(Object other) =>
      other is FoldableNavigationPlacement &&
      other.edge == edge &&
      other.extent == extent;

  @override
  int get hashCode => Object.hash(edge, extent);

  @override
  String toString() =>
      'FoldableNavigationPlacement(${edge.name}'
      '${extent == null ? '' : ', extent: $extent'})';
}

/// What a [FoldableNavigationPlacementResolver] has to decide on.
///
/// Nothing in here depends on the navigation itself (its size, its content), so
/// a placement can be worked out before the panes are laid out.
@immutable
class FoldableLayoutInfo {
  /// Builds the facts about the layout, for tests or for calling a resolver
  /// yourself. The scaffold makes its own.
  const FoldableLayoutInfo({
    required this.scaffoldSize,
    required this.windowSize,
    required this.platform,
    required this.textDirection,
    required this.padding,
    required this.breakpoints,
    this.fold,
    this.hasSecondaryBody = false,
    this.verticalBarEdge,
    this.minWidthNavigation = 72.0,
    this.maxWidthNavigation = 192.0,
  });

  /// The size the scaffold has.
  final Size scaffoldSize;

  /// The size of the window, which the scaffold may not fill (multi-window).
  final Size windowSize;

  /// The platform of the closest [Theme].
  final TargetPlatform platform;

  /// The text direction of the scaffold.
  final TextDirection textDirection;

  /// The system insets around the scaffold.
  final EdgeInsets padding;

  /// The breakpoints of the scaffold.
  final FoldableBreakpoints breakpoints;

  /// The fold or hinge the scaffold follows, or null.
  ///
  /// It can be vertical or horizontal: see [FoldableFold.axis]. A horizontal
  /// one only shows up here when it separates the screen (a hinge, or a half-open
  /// fold) and the scaffold is as tall as the window. Whether the panes really
  /// stack around it is not known yet when the placement is decided, as that
  /// depends on where the pane area ends up.
  final FoldableFold? fold;

  /// Whether the secondary body is shown.
  final bool hasSecondaryBody;

  /// The side where the platform wants vertical bars, from the closest
  /// [FoldableVerticalBarScope], or null when it says nothing or wants none.
  ///
  /// Only [FoldableNavigationEdge.start], [FoldableNavigationEdge.end],
  /// [FoldableNavigationEdge.left] and [FoldableNavigationEdge.right] mean
  /// anything here.
  final FoldableNavigationEdge? verticalBarEdge;

  /// [FoldableScaffold.minWidthNavigation].
  final double minWidthNavigation;

  /// [FoldableScaffold.maxWidthNavigation].
  final double maxWidthNavigation;

  /// The width of the scaffold.
  double get scaffoldWidth => scaffoldSize.width;

  /// The height of the scaffold.
  double get scaffoldHeight => scaffoldSize.height;

  /// Whether the scaffold is at least [FoldableBreakpoints.rail] wide, which
  /// is where a bottom bar gives way to a rail.
  bool get hasRailWidth => scaffoldWidth >= breakpoints.rail;

  /// Whether the scaffold is wider than [FoldableBreakpoints.wideRail].
  bool get hasWideRailWidth => scaffoldWidth > breakpoints.wideRail;

  /// Whether the platform asks for vertical bars on a side.
  bool get wantsVerticalBar => verticalBarEdge?.isSide ?? false;

  @override
  bool operator ==(Object other) =>
      other is FoldableLayoutInfo &&
      other.scaffoldSize == scaffoldSize &&
      other.windowSize == windowSize &&
      other.platform == platform &&
      other.textDirection == textDirection &&
      other.padding == padding &&
      other.breakpoints == breakpoints &&
      other.fold == fold &&
      other.hasSecondaryBody == hasSecondaryBody &&
      other.verticalBarEdge == verticalBarEdge &&
      other.minWidthNavigation == minWidthNavigation &&
      other.maxWidthNavigation == maxWidthNavigation;

  @override
  int get hashCode => Object.hash(
    scaffoldSize,
    windowSize,
    platform,
    textDirection,
    padding,
    breakpoints,
    fold,
    hasSecondaryBody,
    verticalBarEdge,
    minWidthNavigation,
    maxWidthNavigation,
  );
}

/// Decides where the navigation of a [FoldableScaffold] goes.
///
/// Pass one to [FoldableScaffold.navigationPlacement], or start from
/// [defaultNavigationPlacement] and change only the cases you care about:
///
/// ```dart
/// navigationPlacement: (info) => info.scaffoldHeight < 400
///     ? const FoldableNavigationPlacement.start()
///     : defaultNavigationPlacement(info),
/// ```
typedef FoldableNavigationPlacementResolver =
    FoldableNavigationPlacement Function(FoldableLayoutInfo info);

/// The placements the scaffold knows, by platform.
abstract final class FoldableNavigationPlacements {
  /// Android and iOS: a bottom bar below [FoldableBreakpoints.rail], a rail on
  /// the start side from there.
  ///
  /// When the platform asks for vertical bars ([FoldableLayoutInfo.verticalBarEdge],
  /// which iPhone Duo does on its outer display), the navigation goes on that
  /// side whatever the width.
  static FoldableNavigationPlacement handheld(FoldableLayoutInfo info) =>
      _standard(info);

  /// Desktop (Linux, macOS, Windows, Fuchsia) and the web on them: a bottom bar
  /// below [FoldableBreakpoints.rail], a rail on the start side from there.
  ///
  /// Kept apart from [handheld] so the two can diverge; today they agree.
  static FoldableNavigationPlacement desktop(FoldableLayoutInfo info) =>
      _standard(info);

  /// The resolver for [platform]: [handheld] for Android and iOS, [desktop] for
  /// the rest, as [FoldableBreakpoints.forPlatform] does.
  static FoldableNavigationPlacementResolver forPlatform(
    TargetPlatform platform,
  ) {
    return switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS => handheld,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => desktop,
    };
  }

  static FoldableNavigationPlacement _standard(FoldableLayoutInfo info) {
    final verticalBarEdge = info.verticalBarEdge;
    if (verticalBarEdge != null && verticalBarEdge.isSide) {
      return FoldableNavigationPlacement(verticalBarEdge);
    }
    return info.hasRailWidth
        ? const FoldableNavigationPlacement.start()
        : const FoldableNavigationPlacement.bottom();
  }
}

/// The placement the scaffold uses when [FoldableScaffold.navigationPlacement]
/// is null: [FoldableNavigationPlacements.forPlatform] for
/// [FoldableLayoutInfo.platform].
///
/// Exported so a custom resolver can fall back to it.
FoldableNavigationPlacement defaultNavigationPlacement(
  FoldableLayoutInfo info,
) => FoldableNavigationPlacements.forPlatform(info.platform)(info);

/// Builds the navigation, whatever its [placement]: a bar for
/// [FoldableNavigationEdge.bottom] or [FoldableNavigationEdge.top], a rail for
/// a side.
///
/// [constraints] are what the navigation gets: for a side, its extent (the
/// slot minus the system inset of its edge, which the scaffold pads) and the
/// height of the scaffold; for a bar, the width of the scaffold and no height
/// limit. [padding] is the system inset around the scaffold that the scaffold
/// has not applied to the navigation: for a side, that side is 0 and the others
/// are the system's; for a bar, all of it. Use it to keep the content off the
/// camera and the rounded corners. Returning null shows nothing.
typedef FoldableNavigationBuilder =
    Widget? Function(
      BuildContext context,
      FoldableNavigationPlacement placement,
      BoxConstraints constraints,
      EdgeInsets padding,
    );

/// Tells the [FoldableScaffold]s below on which side the platform wants its
/// vertical bars.
///
/// iPhone Duo puts navigation bars, toolbars and tab bars on the side of the
/// display on its outer display, and in some poses of the inner display. The
/// system tells an iOS app which side: the `verticalBarEdge` trait in UIKit,
/// the `toolbarVerticalEdge` environment value in SwiftUI. Flutter does not
/// expose it: [FoldablePlatformScope] reads it on iOS and provides this scope.
/// An app that knows it another way (its own platform code, a test) provides it
/// here:
///
/// ```dart
/// FoldableVerticalBarScope(
///   edge: FoldableNavigationEdge.end, // null when no vertical bar is wanted
///   child: MaterialApp(/* ... */),
/// )
/// ```
///
/// The default placement then puts the navigation on that side, whatever the
/// width. Without a scope, or with a null [edge], nothing changes.
class FoldableVerticalBarScope extends InheritedWidget {
  /// Provides [edge] to the scaffolds below.
  const FoldableVerticalBarScope({
    super.key,
    required this.edge,
    required super.child,
  }) : assert(
         edge == null || edge != FoldableNavigationEdge.none,
         'Pass null, not none, for no vertical bar.',
       );

  /// The side of the vertical bars: [FoldableNavigationEdge.start],
  /// [FoldableNavigationEdge.end], [FoldableNavigationEdge.left] or
  /// [FoldableNavigationEdge.right], or null for none.
  final FoldableNavigationEdge? edge;

  /// The edge of the closest scope, or null.
  static FoldableNavigationEdge? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FoldableVerticalBarScope>()
      ?.edge;

  @override
  bool updateShouldNotify(FoldableVerticalBarScope oldWidget) =>
      oldWidget.edge != edge;
}
