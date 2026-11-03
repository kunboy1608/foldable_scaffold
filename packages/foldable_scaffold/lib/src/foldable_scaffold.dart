import 'package:flutter/foundation.dart';
import 'package:foldable_core/foldable_core.dart';
import 'package:material_ui/material_ui.dart';

import 'foldable_breakpoints.dart';
import 'foldable_fold.dart';

/// A [Scaffold] with two panes: a body and a secondary body.
///
/// The scaffold only takes care of the layout. Who fills the panes is up to
/// you: `FoldableNavigator` in `foldable_router` puts a page stack in them,
/// but any two widgets work.
///
/// Layout, by available width (the numbers are [breakpoints], shown here for a
/// desktop; see [FoldableBreakpoints] for handhelds):
///
/// * Below 600: one pane at a time, no navigation rail.
/// * From 600: the primary navigation is shown sideways, one pane at a time.
/// * From 1200 on desktop, or from 600 on the inner screen of a foldable or a
///   tablet (a window at least 600 on its short side, so never a phone): the
///   body and the secondary body are shown side by side, with a divider that
///   can be dragged to resize them. The divider stops where either pane would
///   get narrower than [minBodySize].
///
/// When only one pane is shown, the secondary body replaces the body, unless
/// [focusOnPrimaryBody] is true. A pane narrower than [minBodySize] collapses
/// into the other one, which happens when the available width cannot hold two
/// panes of that size.
///
/// A device with a vertical fold or hinge (see [followFold]) gets the panes
/// placed around it: when the fold separates the screen (a hinge, or a fold that
/// is half open) the body is on one side and the secondary body on the other,
/// whatever the width. A flat fold only decides where the divider starts.
///
/// The divider can snap to set widths when it is released ([snapWidths]).
///
/// The usual [Scaffold] slots are forwarded: [floatingActionButton],
/// [drawer], [endDrawer] and [bottomSheet].
///
/// Switching the one visible pane is instant while [paneTransition] is true,
/// so a page slide (`FoldableNavigator`) does not run a pane resize on top of
/// it. [FoldablePaneTransitionScope] provides the same signal automatically
/// when the scaffold is built inside a `FoldableNavigator`.
class FoldableScaffold extends StatefulWidget {
  const FoldableScaffold({
    required this.bodyBuilder,
    super.key,
    this.primary = true,
    this.extendBody = true,
    this.extendBodyBehindAppBar = false,
    this.focusOnPrimaryBody = false,
    this.breakpoints,
    this.followFold = true,
    this.minWidthNavigation = 72.0,
    this.maxWidthNavigation = 192.0,
    this.minBodySize = 200.0,
    this.dividerSize = 24.0,
    this.snapWidths = const [],
    this.snapThreshold = 32.0,
    this.paneAnimationDuration = const Duration(milliseconds: 250),
    this.paneTransition,
    this.topNavigationBuilder,
    this.secondaryBodyBuilder,
    this.hasSecondaryBody,
    this.primaryNavigationBuilder,
    this.bottomNavigationBuilder,
    this.onSecondBodyClose,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  /// Whether this scaffold hosts the primary content of the app, forwarded to
  /// [Scaffold.primary].
  final bool primary;

  /// Forwarded to [Scaffold.extendBody].
  final bool extendBody;

  /// Forwarded to [Scaffold.extendBodyBehindAppBar].
  final bool extendBodyBehindAppBar;

  /// Whether the body stays on screen when the secondary body is opened in a
  /// single-pane layout.
  final bool focusOnPrimaryBody;

  /// The widths at which the layout changes.
  ///
  /// Defaults to [FoldableBreakpoints.forPlatform] for the platform of the
  /// closest [Theme]: two panes on the inner screen of a foldable or on a tablet
  /// for Android and iOS, from a window 1200 wide elsewhere.
  final FoldableBreakpoints? breakpoints;

  /// Whether the panes follow a vertical fold or hinge of the device
  /// ([FoldableFold], from [MediaQuery.displayFeatures]).
  ///
  /// * A fold that separates the screen (a hinge, or a fold that is half open)
  ///   gets one pane on each side, and the hinge area between them stays
  ///   empty. The divider cannot be dragged. This applies even where
  ///   [breakpoints] would show one pane, provided each side is at least
  ///   [minBodySize] wide.
  /// * A flat fold is only a crease: the divider starts on it, and can be dragged
  ///   away. Two panes still need [breakpoints] to say so.
  ///
  /// It needs the scaffold to be as wide as the window, as the fold is reported
  /// in window coordinates; a scaffold inside something narrower ignores the
  /// fold. Devices without a fold are unaffected.
  final bool followFold;

  /// Width of the primary navigation when it is shown sideways.
  final double minWidthNavigation;

  /// Width of the primary navigation when the scaffold is wide
  /// ([FoldableBreakpoints.wideRail]).
  final double maxWidthNavigation;

  /// A pane narrower than this collapses into the other one.
  final double minBodySize;

  /// Width of the drag handle between the two panes.
  final double dividerSize;

  /// Widths a pane snaps to when the divider is released, for example
  /// `[360, 412]`. Either pane snaps, whichever is nearest to one of the widths.
  ///
  /// Empty by default: the divider stays where it is released.
  final List<double> snapWidths;

  /// How close, in logical pixels, a pane must be to one of the [snapWidths]
  /// when the divider is released to snap to it.
  final double snapThreshold;

  /// Duration of the pane animations, scaled by [FoldableMotion].
  final Duration paneAnimationDuration;

  /// Whether pages are sliding right now.
  ///
  /// While true, switching the one visible pane is instant. Both the body and
  /// the secondary body still build; only the pane geometry stops animating.
  ///
  /// Defaults to the closest [FoldablePaneTransitionScope], which
  /// `FoldableNavigator` provides.
  final ValueListenable<bool>? paneTransition;

  /// The app bar. Gets the scaffold width and [kToolbarHeight].
  final PreferredSizeBoxConstraintsWidgetBuilder? topNavigationBuilder;

  /// Builds the body pane. Called with the pane constraints, which change
  /// while the divider is dragged.
  final BoxConstraintsNullableWidgetBuilder bodyBuilder;

  /// Builds the secondary body pane, or returns null when there is nothing to
  /// show there.
  ///
  /// Without [hasSecondaryBody], the scaffold calls it once per build just to
  /// find out whether it returns null, with the scaffold size, and again to
  /// build the pane with the pane constraints. Set [hasSecondaryBody] to avoid
  /// the extra call.
  final BoxConstraintsNullableWidgetBuilder? secondaryBodyBuilder;

  /// Whether there is a secondary body to show.
  ///
  /// When set, [secondaryBodyBuilder] is only called to build the pane, once
  /// per layout, and never to probe for null. When null, the scaffold probes
  /// the builder on every build, so the builder must be cheap and free of side
  /// effects.
  final bool? hasSecondaryBody;

  /// Builds the navigation shown at the start of the row (a [NavigationRail],
  /// usually). Hidden when there is no room for it.
  final PrimaryNavigationBuilder? primaryNavigationBuilder;

  /// Builds the bottom navigation, shown below [FoldableBreakpoints.rail]
  /// only.
  final BoxConstraintsNullableWidgetBuilder? bottomNavigationBuilder;

  /// Called when the system back press is refused because the secondary body
  /// is open.
  final PopInvokedWithResultCallback<dynamic>? onSecondBodyClose;

  /// Forwarded to [Scaffold.floatingActionButton].
  final Widget? floatingActionButton;

  /// Forwarded to [Scaffold.floatingActionButtonLocation].
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Forwarded to [Scaffold.drawer].
  final Widget? drawer;

  /// Forwarded to [Scaffold.endDrawer].
  final Widget? endDrawer;

  /// Forwarded to [Scaffold.bottomSheet].
  final Widget? bottomSheet;

  /// Forwarded to [Scaffold.backgroundColor].
  final Color? backgroundColor;

  /// Forwarded to [Scaffold.resizeToAvoidBottomInset].
  final bool? resizeToAvoidBottomInset;

  @override
  State<FoldableScaffold> createState() => _FoldableScaffoldState();
}

class _FoldableScaffoldState extends State<FoldableScaffold> {
  final _ratioSecondaryBody = ValueNotifier(0.5);
  final _isHoveringDivider = ValueNotifier(false);
  bool _wasSinglePane = false;
  bool _wasPrimaryVisible = false;

  /// Whether the user dragged the divider since the fold last changed. Until
  /// then, a flat fold decides where the divider starts.
  bool _userResized = false;
  FoldableFold? _fold;

  double get _minWidthNavigation => widget.minWidthNavigation;
  double get _maxWidthNavigation => widget.maxWidthNavigation;
  double get _minBodySize => widget.minBodySize;
  double get _dividerSize => widget.dividerSize;
  bool get _focusOnPrimaryBody => widget.focusOnPrimaryBody;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Folding or unfolding the device moves the crease: start over from it.
    final fold = FoldableFold.maybeOf(context);
    if (fold != _fold) {
      _fold = fold;
      _userResized = false;
    }
  }

  @override
  void dispose() {
    _ratioSecondaryBody.dispose();
    _isHoveringDivider.dispose();
    super.dispose();
  }

  Widget _body() {
    return LayoutBuilder(
      key: const Key('body_builder'),
      builder: (context, constraints) =>
          widget.bodyBuilder.call(context, constraints) ??
          const SizedBox.shrink(),
    );
  }

  Widget _secondaryBody() {
    return LayoutBuilder(
      key: const Key('secondary_body_builder'),
      builder: (context, constraints) =>
          widget.secondaryBodyBuilder?.call(context, constraints) ??
          const SizedBox.shrink(),
    );
  }

  /// The ratio is relative to [screenWidth], the width of the whole scaffold,
  /// while the panes share a narrower area: [minSecondarySize] and
  /// [maxSecondarySize] bound the secondary pane inside that area.
  Widget _buildResizableDivider({
    required BoxConstraints constraints,
    required double minSecondarySize,
    required double maxSecondarySize,
    required double screenWidth,
    required double currentRatio,
    required bool atFold,
  }) {
    // The hinge area between two screens is not a handle.
    if (atFold) {
      return ColoredBox(
        key: const Key('pane_divider'),
        color: Theme.of(context).scaffoldBackgroundColor,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        key: const Key('pane_divider'),
        onHorizontalDragStart: (_) {
          // Continue from where the divider is, which may be on the fold.
          _ratioSecondaryBody.value = currentRatio;
          _userResized = true;
          _isHoveringDivider.value = true;
        },
        onHorizontalDragUpdate: (update) {
          // Keep the stored ratio in range, so dragging back after going past
          // an edge moves the divider right away.
          final currentSecondarySize = _ratioSecondaryBody.value * screenWidth;
          final newSecondarySize = (currentSecondarySize - update.delta.dx)
              .clamp(minSecondarySize, maxSecondarySize);
          _ratioSecondaryBody.value = newSecondarySize / screenWidth;
        },
        onHorizontalDragEnd: (_) {
          _snapToWidths(
            screenWidth: screenWidth,
            splitWidth: constraints.maxWidth - _dividerSize,
            minSecondarySize: minSecondarySize,
            maxSecondarySize: maxSecondarySize,
          );
          _isHoveringDivider.value = false;
        },
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: _dividerSize,
          height: constraints.maxHeight,
          child: Center(
            child: ValueListenableBuilder(
              valueListenable: _isHoveringDivider,
              builder: (context, value, _) {
                return AnimatedContainer(
                  height: 50,
                  width: value ? 12 : 4,
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: value
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(value ? 6 : 2),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Moves the divider to the nearest of [FoldableScaffold.snapWidths], if one
  /// is within [FoldableScaffold.snapThreshold] of either pane.
  void _snapToWidths({
    required double screenWidth,
    required double splitWidth,
    required double minSecondarySize,
    required double maxSecondarySize,
  }) {
    if (widget.snapWidths.isEmpty || screenWidth <= 0) return;
    final secondary = (_ratioSecondaryBody.value * screenWidth).clamp(
      minSecondarySize,
      maxSecondarySize,
    );
    double? best;
    var bestDistance = widget.snapThreshold;
    for (final width in widget.snapWidths) {
      // The secondary body takes the width, or the body does.
      for (final candidate in [width, splitWidth - width]) {
        if (candidate < minSecondarySize || candidate > maxSecondarySize) {
          continue;
        }
        final distance = (secondary - candidate).abs();
        if (distance <= bestDistance) {
          best = candidate;
          bestDistance = distance;
        }
      }
    }
    if (best != null) _ratioSecondaryBody.value = best / screenWidth;
  }

  @override
  Widget build(BuildContext context) {
    final paneAnimationDuration = FoldableMotion.of(
      context,
      widget.paneAnimationDuration,
    );

    final breakpoints =
        widget.breakpoints ??
        FoldableBreakpoints.forPlatform(Theme.of(context).platform);
    // The window, not the scaffold, tells a phone held sideways (wide but
    // short) from a foldable or a tablet.
    final windowSize = MediaQuery.sizeOf(context);
    final displayFeatures = MediaQuery.displayFeaturesOf(context);

    return LayoutBuilder(
      builder: (context, scaffoldConstraints) {
        final padding = MediaQuery.paddingOf(context);

        final scaffoldWidth = scaffoldConstraints.maxWidth;
        final isMediumSize = scaffoldWidth >= breakpoints.rail;
        final isMediumLargeSize = breakpoints.canSplit(
          scaffoldWidth,
          windowSize,
        );
        final navigationWidth = scaffoldWidth > breakpoints.wideRail
            ? _maxWidthNavigation + padding.left
            : isMediumSize
            ? _minWidthNavigation + padding.left
            : 0.0;
        // What the navigation really takes: nothing without a builder.
        final railWidth = widget.primaryNavigationBuilder == null
            ? 0.0
            : navigationWidth;
        final paneAreaWidth = scaffoldWidth - railWidth;
        // The fold is in window coordinates: it only means something to a
        // scaffold that spans the window.
        final fold =
            widget.followFold && (scaffoldWidth - windowSize.width).abs() < 1
            ? FoldableFold.fromFeatures(displayFeatures, windowSize)
            : null;
        final foldLeft = fold == null ? 0.0 : fold.bounds.left - railWidth;
        final foldRight = fold == null ? 0.0 : fold.bounds.right - railWidth;
        // One pane on each side of a fold that cuts the screen, as long as both
        // are big enough to be useful.
        final splitsAtFold =
            fold != null &&
            fold.isSeparating &&
            foldLeft >= _minBodySize &&
            paneAreaWidth - foldRight >= _minBodySize;
        // Where the secondary pane ends up if the divider sits on a flat fold.
        final foldSecondaryRatio = fold == null || fold.isSeparating
            ? null
            : (scaffoldWidth - fold.center - _dividerSize / 2) / scaffoldWidth;
        final hasSecondaryBody =
            widget.secondaryBodyBuilder != null &&
            (widget.hasSecondaryBody ??
                widget.secondaryBodyBuilder!(
                      context,
                      BoxConstraints(
                        maxWidth: scaffoldWidth,
                        maxHeight: scaffoldConstraints.maxHeight,
                      ),
                    ) !=
                    null);

        return PopScope(
          canPop: !hasSecondaryBody,
          onPopInvokedWithResult: widget.onSecondBodyClose,
          child: FoldableScaffoldScope(
            canSplit: isMediumLargeSize || splitsAtFold,
            child: Scaffold(
              primary: widget.primary,
              extendBody: widget.extendBody,
              extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
              floatingActionButton: widget.floatingActionButton,
              floatingActionButtonLocation: widget.floatingActionButtonLocation,
              drawer: widget.drawer,
              endDrawer: widget.endDrawer,
              bottomSheet: widget.bottomSheet,
              backgroundColor: widget.backgroundColor,
              resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
              appBar: widget.topNavigationBuilder?.call(
                context,
                BoxConstraints(
                  maxWidth: scaffoldWidth,
                  maxHeight: kToolbarHeight,
                ),
              ),
              body: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: navigationWidth),
                    duration: paneAnimationDuration,
                    curve: Curves.fastOutSlowIn,
                    builder: (context, animatedWidth, _) {
                      final primaryNavigationBuilder =
                          widget.primaryNavigationBuilder;
                      if (animatedWidth == 0 ||
                          primaryNavigationBuilder == null) {
                        return const SizedBox.shrink(
                          key: Key('primary_navigation_builder'),
                        );
                      }

                      return SizedBox(
                        width: animatedWidth,
                        child: LayoutBuilder(
                          key: const Key('primary_navigation_builder'),
                          builder: (context, constraints) {
                            return primaryNavigationBuilder(
                              context,
                              constraints,
                              padding,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (innerContext, constraints) {
                        final totalWidth = constraints.maxWidth;

                        final canSplitPanel =
                            (isMediumLargeSize || splitsAtFold) &&
                            hasSecondaryBody;

                        // The panes share the width left by the navigation and
                        // the divider. Each keeps at least minBodySize, or half
                        // of that width when it cannot hold two of them.
                        final splitWidth = (totalWidth - _dividerSize).clamp(
                          0.0,
                          double.infinity,
                        );
                        final minPaneSize = _minBodySize < splitWidth / 2
                            ? _minBodySize
                            : splitWidth / 2;
                        final minSecondarySize = minPaneSize;
                        final maxSecondarySize = splitWidth - minPaneSize;

                        // The panes see what the Scaffold made of the window
                        // for its body: the app bar took the top inset, the
                        // keyboard resized the body, and with extendBody the
                        // bottom padding is the height of the bottom bar.
                        final bodyMedia = MediaQuery.of(innerContext);
                        // The Scaffold takes the bottom inset away from its body
                        // as soon as it has a bottom bar, even a hidden one, and
                        // gives it back as the bar's height (extendBody). With
                        // no bar on screen the inset is the system's.
                        final hasBottomBar =
                            widget.bottomNavigationBuilder != null &&
                            navigationWidth == 0;
                        return MediaQuery(
                          data: bodyMedia.copyWith(
                            padding: bodyMedia.padding.copyWith(
                              // The navigation rail already took the left inset.
                              left: navigationWidth > 0 ? 0 : null,
                              bottom: hasBottomBar ? null : padding.bottom,
                            ),
                          ),
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              _ratioSecondaryBody,
                              _isHoveringDivider,
                            ]),
                            builder: (context, _) {
                              final ratioSecondaryBody =
                                  _userResized || foldSecondaryRatio == null
                                  ? _ratioSecondaryBody.value
                                  : foldSecondaryRatio;
                              final isHoveringDivider =
                                  _isHoveringDivider.value;
                              double secondaryTargetWidth = 0.0;
                              double primaryTargetWidth = totalWidth;
                              double dividerTargetWidth = 0.0;

                              if (canSplitPanel && splitsAtFold) {
                                // Around the hinge: its area is the divider.
                                primaryTargetWidth = foldLeft;
                                dividerTargetWidth = foldRight - foldLeft;
                                secondaryTargetWidth = totalWidth - foldRight;
                              } else if (canSplitPanel) {
                                // The window may have been resized since the
                                // ratio was stored.
                                secondaryTargetWidth =
                                    (ratioSecondaryBody * scaffoldWidth).clamp(
                                      minSecondarySize,
                                      maxSecondarySize,
                                    );
                                dividerTargetWidth = _dividerSize;
                                primaryTargetWidth =
                                    splitWidth - secondaryTargetWidth;
                              } else {
                                if (!_focusOnPrimaryBody && hasSecondaryBody) {
                                  secondaryTargetWidth = totalWidth;
                                  primaryTargetWidth = 0.0;
                                } else {
                                  secondaryTargetWidth = 0.0;
                                  primaryTargetWidth = totalWidth;
                                }
                              }

                              // A collapsed pane gives its room, and the
                              // divider's, to the other one.
                              if (!isHoveringDivider) {
                                if (primaryTargetWidth < _minBodySize) {
                                  secondaryTargetWidth +=
                                      primaryTargetWidth + dividerTargetWidth;
                                  primaryTargetWidth = 0;
                                  dividerTargetWidth = 0;
                                }

                                if (secondaryTargetWidth < _minBodySize) {
                                  primaryTargetWidth +=
                                      secondaryTargetWidth + dividerTargetWidth;
                                  secondaryTargetWidth = 0;
                                  dividerTargetWidth = 0;
                                }
                              }

                              final targetGeometry = _PaneGeometry(
                                primaryWidth: primaryTargetWidth.clamp(
                                  0.0,
                                  totalWidth,
                                ),
                                dividerWidth: dividerTargetWidth.clamp(
                                  0.0,
                                  totalWidth,
                                ),
                                secondaryWidth: secondaryTargetWidth.clamp(
                                  0.0,
                                  totalWidth,
                                ),
                              );

                              final primaryVisible =
                                  targetGeometry.primaryWidth > 0;
                              final secondaryVisible =
                                  targetGeometry.secondaryWidth > 0;
                              final isSinglePane =
                                  !primaryVisible || !secondaryVisible;
                              // Switching the one visible pane is instant so
                              // only the page slide is seen: while pages slide,
                              // and when a single-pane layout switches panes on
                              // its own (a cancelled swipe back).
                              final snapPanes =
                                  isSinglePane &&
                                  _wasSinglePane &&
                                  (_isTransitioning(context) ||
                                      primaryVisible != _wasPrimaryVisible);
                              _wasSinglePane = isSinglePane;
                              _wasPrimaryVisible = primaryVisible;

                              return ValueListenableBuilder(
                                valueListenable: _isHoveringDivider,
                                builder: (context, isDraggingDivider, _) {
                                  return TweenAnimationBuilder<_PaneGeometry>(
                                    tween: _PaneGeometryTween(
                                      end: targetGeometry,
                                    ),
                                    duration: isDraggingDivider || snapPanes
                                        ? Duration.zero
                                        : paneAnimationDuration,
                                    curve: Curves.fastOutSlowIn,
                                    builder: (context, geometry, _) {
                                      final panes = CustomMultiChildLayout(
                                        delegate: _FoldablePaneLayoutDelegate(
                                          geometry: geometry,
                                        ),
                                        children: [
                                          LayoutId(
                                            id: _PaneSlot.primary,
                                            child: _body(),
                                          ),
                                          LayoutId(
                                            id: _PaneSlot.divider,
                                            child: _buildResizableDivider(
                                              constraints: constraints,
                                              minSecondarySize:
                                                  minSecondarySize,
                                              maxSecondarySize:
                                                  maxSecondarySize,
                                              screenWidth:
                                                  scaffoldConstraints.maxWidth,
                                              currentRatio: ratioSecondaryBody,
                                              atFold:
                                                  canSplitPanel && splitsAtFold,
                                            ),
                                          ),
                                          LayoutId(
                                            id: _PaneSlot.secondary,
                                            child: _secondaryBody(),
                                          ),
                                        ],
                                      );
                                      return FoldablePaneLayout(
                                        primaryVisible: primaryVisible,
                                        secondaryVisible: secondaryVisible,
                                        // Keep sliding pages off the
                                        // navigation rail.
                                        child: ClipRect(child: panes),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: AnimatedSwitcher(
                duration: paneAnimationDuration,
                switchInCurve: Curves.fastOutSlowIn,
                child: navigationWidth > 0
                    ? const SizedBox.shrink(
                        key: Key('bottom_navigation_hidden'),
                      )
                    : LayoutBuilder(
                        key: const Key('bottom_navigation_builder'),
                        builder: (context, constraints) {
                          return widget.bottomNavigationBuilder?.call(
                                context,
                                constraints,
                              ) ??
                              const SizedBox.shrink();
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Whether page transitions are running, from [FoldableScaffold.paneTransition]
  /// or the closest [FoldablePaneTransitionScope].
  bool _isTransitioning(BuildContext context) {
    final transition = widget.paneTransition;
    if (transition != null) return transition.value;
    return FoldablePaneTransitionScope.isTransitioningOf(context);
  }
}

/// Builds a widget with the constraints of a pane. Returning null hides the
/// pane.
typedef BoxConstraintsNullableWidgetBuilder =
    Widget? Function(BuildContext context, BoxConstraints constraints);

/// Builds the navigation shown at the start of the scaffold row.
typedef PrimaryNavigationBuilder =
    Widget Function(
      BuildContext context,
      BoxConstraints constraints,
      EdgeInsets padding,
    );

/// Builds a [PreferredSizeWidget] with the scaffold width.
typedef PreferredSizeBoxConstraintsWidgetBuilder =
    PreferredSizeWidget? Function(
      BuildContext context,
      BoxConstraints constraints,
    );

enum _PaneSlot { primary, divider, secondary }

class _PaneGeometry {
  const _PaneGeometry({
    required this.primaryWidth,
    required this.dividerWidth,
    required this.secondaryWidth,
  });

  final double primaryWidth;
  final double dividerWidth;
  final double secondaryWidth;
}

class _PaneGeometryTween extends Tween<_PaneGeometry> {
  _PaneGeometryTween({required _PaneGeometry end}) : super(end: end);

  @override
  _PaneGeometry lerp(double t) {
    final beginValue = begin ?? end!;
    final endValue = end!;
    return _PaneGeometry(
      primaryWidth:
          beginValue.primaryWidth +
          (endValue.primaryWidth - beginValue.primaryWidth) * t,
      dividerWidth:
          beginValue.dividerWidth +
          (endValue.dividerWidth - beginValue.dividerWidth) * t,
      secondaryWidth:
          beginValue.secondaryWidth +
          (endValue.secondaryWidth - beginValue.secondaryWidth) * t,
    );
  }
}

class _FoldablePaneLayoutDelegate extends MultiChildLayoutDelegate {
  _FoldablePaneLayoutDelegate({required this.geometry});

  final _PaneGeometry geometry;

  @override
  void performLayout(Size size) {
    final totalTargetWidth =
        geometry.primaryWidth + geometry.dividerWidth + geometry.secondaryWidth;
    final scale = totalTargetWidth > size.width && totalTargetWidth > 0
        ? size.width / totalTargetWidth
        : 1.0;

    final primaryWidth = geometry.primaryWidth * scale;
    final dividerWidth = geometry.dividerWidth * scale;
    final secondaryWidth = geometry.secondaryWidth * scale;

    var xOffset = 0.0;

    if (hasChild(_PaneSlot.primary)) {
      layoutChild(
        _PaneSlot.primary,
        BoxConstraints.tightFor(width: primaryWidth, height: size.height),
      );
      positionChild(_PaneSlot.primary, Offset.zero);
      xOffset += primaryWidth;
    }

    if (hasChild(_PaneSlot.divider)) {
      layoutChild(
        _PaneSlot.divider,
        BoxConstraints.tightFor(width: dividerWidth, height: size.height),
      );
      positionChild(_PaneSlot.divider, Offset(xOffset, 0));
      xOffset += dividerWidth;
    }

    if (hasChild(_PaneSlot.secondary)) {
      layoutChild(
        _PaneSlot.secondary,
        BoxConstraints.tightFor(width: secondaryWidth, height: size.height),
      );
      positionChild(_PaneSlot.secondary, Offset(xOffset, 0));
    }
  }

  @override
  bool shouldRelayout(covariant _FoldablePaneLayoutDelegate oldDelegate) {
    return geometry.primaryWidth != oldDelegate.geometry.primaryWidth ||
        geometry.dividerWidth != oldDelegate.geometry.dividerWidth ||
        geometry.secondaryWidth != oldDelegate.geometry.secondaryWidth;
  }
}
