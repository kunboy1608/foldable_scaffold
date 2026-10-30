// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:foldable_core/foldable_core.dart';
import 'package:material_ui/material_ui.dart';

/// A [Scaffold] with two panes: a body and a secondary body.
///
/// The scaffold only takes care of the layout. Who fills the panes is up to
/// you: `FoldableNavigator` in `foldable_router` puts a page stack in them,
/// but any two widgets work.
///
/// Layout, by available width:
///
/// * Below 600: one pane at a time, no navigation rail.
/// * From 600: the primary navigation is shown sideways, one pane at a time.
/// * From 1200: the body and the secondary body are shown side by side, with
///   a divider that can be dragged to resize them.
///
/// When only one pane is shown, the secondary body replaces the body, unless
/// [focusOnPrimaryBody] is true. A pane narrower than [minBodySize] collapses
/// into the other one.
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
    this.minWidthNavigation = 72.0,
    this.maxWidthNavigation = 192.0,
    this.minBodySize = 200.0,
    this.dividerSize = 24.0,
    this.paneAnimationDuration = const Duration(milliseconds: 250),
    this.paneTransition,
    this.topNavigationBuilder,
    this.secondaryBodyBuilder,
    this.primaryNavigationBuilder,
    this.bottomNavigationBuilder,
    this.onSecondBodyClose,
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

  /// Width of the primary navigation when it is shown sideways (from 600).
  final double minWidthNavigation;

  /// Width of the primary navigation when the window is wide (over 1000).
  final double maxWidthNavigation;

  /// A pane narrower than this collapses into the other one.
  final double minBodySize;

  /// Width of the drag handle between the two panes.
  final double dividerSize;

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
  final BoxConstraintsNullableWidgetBuilder? secondaryBodyBuilder;

  /// Builds the navigation shown at the start of the row (a [NavigationRail],
  /// usually). Hidden when there is no room for it.
  final PrimaryNavigationBuilder? primaryNavigationBuilder;

  /// Builds the bottom navigation, shown below 600 only.
  final BoxConstraintsNullableWidgetBuilder? bottomNavigationBuilder;

  /// Called when the system back press is refused because the secondary body
  /// is open.
  final PopInvokedWithResultCallback<dynamic>? onSecondBodyClose;

  @override
  State<FoldableScaffold> createState() => _FoldableScaffoldState();
}

class _FoldableScaffoldState extends State<FoldableScaffold> {
  final _ratioSecondaryBody = ValueNotifier(0.5);
  final _isHoveringDivider = ValueNotifier(false);
  bool _wasSinglePane = false;
  bool _wasPrimaryVisible = false;

  double get _minWidthNavigation => widget.minWidthNavigation;
  double get _maxWidthNavigation => widget.maxWidthNavigation;
  double get _minBodySize => widget.minBodySize;
  double get _dividerSize => widget.dividerSize;
  bool get _focusOnPrimaryBody => widget.focusOnPrimaryBody;

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

  Widget _buildResizableDivider({
    required BoxConstraints constraints,
    required double minExtendedSize,
    required double maxExtendedSize,
    required double halfTotalWidth,
    required double screenWidth,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          _isHoveringDivider.value = true;
        },
        onHorizontalDragUpdate: (update) {
          final currentSecondarySize = _ratioSecondaryBody.value * screenWidth;
          final newSecondarySize = currentSecondarySize - update.delta.dx;
          _ratioSecondaryBody.value = newSecondarySize / screenWidth;
        },
        onHorizontalDragEnd: (_) {
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

  @override
  Widget build(BuildContext context) {
    final paneAnimationDuration = FoldableMotion.of(
      context,
      widget.paneAnimationDuration,
    );

    return LayoutBuilder(
      builder: (context, scaffoldConstraints) {
        final padding = MediaQuery.paddingOf(context);

        final scaffoldWidth = scaffoldConstraints.maxWidth;
        final isMediumSize = scaffoldWidth >= 600;
        final isMediumLargeSize = scaffoldWidth > 1200;
        final navigationWidth = scaffoldWidth > 1000
            ? _maxWidthNavigation + padding.left
            : isMediumSize
            ? _minWidthNavigation + padding.left
            : 0.0;
        final hasSecondaryBody =
            widget.secondaryBodyBuilder?.call(
              context,
              BoxConstraints(
                maxWidth: scaffoldWidth,
                maxHeight: kToolbarHeight,
              ),
            ) !=
            null;

        return PopScope(
          canPop: !hasSecondaryBody,
          onPopInvokedWithResult: widget.onSecondBodyClose,
          child: FoldableScaffoldScope(
            canSplit: isMediumLargeSize,
            child: Scaffold(
              primary: widget.primary,
              extendBody: widget.extendBody,
              extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
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
                        final halfTotalWidth = totalWidth / 2;
                        final halfDividerSize = _dividerSize / 2;

                        final canSplitPanel =
                            isMediumLargeSize && hasSecondaryBody;

                        final minExtendedSize =
                            -halfTotalWidth + halfDividerSize;
                        final maxExtendedSize =
                            halfTotalWidth - halfDividerSize;

                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            padding: padding.copyWith(
                              top: MediaQuery.paddingOf(innerContext).top,
                              left: navigationWidth > 0 ? 0 : padding.left,
                            ),
                          ),
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              _ratioSecondaryBody,
                              _isHoveringDivider,
                            ]),
                            builder: (context, _) {
                              final ratioSecondaryBody =
                                  _ratioSecondaryBody.value;
                              final isHoveringDivider =
                                  _isHoveringDivider.value;
                              double secondaryTargetWidth = 0.0;
                              double primaryTargetWidth = totalWidth;

                              if (canSplitPanel) {
                                secondaryTargetWidth =
                                    ratioSecondaryBody * scaffoldWidth -
                                    halfDividerSize;

                                primaryTargetWidth =
                                    totalWidth -
                                    secondaryTargetWidth -
                                    halfDividerSize;
                              } else {
                                if (!_focusOnPrimaryBody && hasSecondaryBody) {
                                  secondaryTargetWidth = totalWidth;
                                  primaryTargetWidth = 0.0;
                                } else {
                                  secondaryTargetWidth = 0.0;
                                  primaryTargetWidth = totalWidth;
                                }
                              }

                              if (!isHoveringDivider) {
                                if (primaryTargetWidth < _minBodySize) {
                                  secondaryTargetWidth += primaryTargetWidth;
                                  primaryTargetWidth = 0;
                                }

                                if (secondaryTargetWidth < _minBodySize) {
                                  primaryTargetWidth += secondaryTargetWidth;
                                  secondaryTargetWidth = 0;
                                }
                              }

                              final targetGeometry = _PaneGeometry(
                                primaryWidth: primaryTargetWidth.clamp(
                                  0.0,
                                  totalWidth,
                                ),
                                dividerWidth: canSplitPanel
                                    ? _dividerSize
                                    : 0.0,
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
                                          showOnePanel: totalWidth <= 1200,
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
                                              minExtendedSize: minExtendedSize,
                                              maxExtendedSize: maxExtendedSize,
                                              halfTotalWidth: halfTotalWidth,
                                              screenWidth:
                                                  scaffoldConstraints.maxWidth,
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

/// Builds a widget, or returns null.
typedef NullableWidgetBuilder = Widget? Function(BuildContext context);

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
  _FoldablePaneLayoutDelegate({
    required this.geometry,
    required this.showOnePanel,
  });

  final _PaneGeometry geometry;
  final bool showOnePanel;

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
