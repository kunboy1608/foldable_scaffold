import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import 'foldable_scaffold_theme.dart';

/// What the divider of a [FoldableScaffold] is doing, for a custom handle.
///
/// Passed to `FoldableScaffold.dividerBuilder`, which replaces the look of the
/// handle only: the scaffold keeps dragging, the mouse cursor, the keyboard
/// shortcuts and the screen reader semantics, so a custom handle does not have
/// to do any of it.
@immutable
class FoldableDividerState with Diagnosticable {
  /// Creates the state of the divider for a builder.
  const FoldableDividerState({
    required this.isHovering,
    required this.isDragging,
    required this.isFocused,
    required this.atFold,
    required this.textDirection,
    this.axis = Axis.horizontal,
  });

  /// Whether the pointer is over the divider.
  final bool isHovering;

  /// Whether the divider is being dragged.
  final bool isDragging;

  /// Whether the divider has the keyboard focus, which is how it looks once it
  /// has been reached with Tab.
  final bool isFocused;

  /// Whether the divider sits on a fold or hinge that separates the screen and
  /// cannot be moved. A builder is not called then: there is no handle.
  final bool atFold;

  /// The direction in which dragging the divider grows the secondary pane.
  final TextDirection textDirection;

  /// The axis along which the divider is moved: [Axis.horizontal] for the
  /// horizontal divider of this scaffold.
  final Axis axis;

  /// Whether the divider looks active: hovered, dragged or focused.
  bool get isActive => isHovering || isDragging || isFocused;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoldableDividerState &&
        other.isHovering == isHovering &&
        other.isDragging == isDragging &&
        other.isFocused == isFocused &&
        other.atFold == atFold &&
        other.textDirection == textDirection &&
        other.axis == axis;
  }

  @override
  int get hashCode => Object.hash(
    isHovering,
    isDragging,
    isFocused,
    atFold,
    textDirection,
    axis,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('isHovering', value: isHovering, ifTrue: 'hovering'))
      ..add(FlagProperty('isDragging', value: isDragging, ifTrue: 'dragging'))
      ..add(FlagProperty('isFocused', value: isFocused, ifTrue: 'focused'))
      ..add(FlagProperty('atFold', value: atFold, ifTrue: 'at a fold'))
      ..add(EnumProperty<TextDirection>('textDirection', textDirection))
      ..add(EnumProperty<Axis>('axis', axis));
  }
}

/// Builds the look of the divider handle of a [FoldableScaffold].
///
/// Called with the [FoldableDividerState] of the divider. Dragging, the mouse
/// cursor, the keyboard shortcuts and the semantics stay with the scaffold.
typedef FoldableDividerBuilder =
    Widget Function(BuildContext context, FoldableDividerState state);

/// Moves the divider one step towards [direction]: -1 for the start of the
/// line (left in LTR), 1 for the end.
class _ResizeDividerIntent extends Intent {
  const _ResizeDividerIntent(this.direction, {this.large = false});

  final int direction;
  final bool large;
}

/// Puts the divider at the start ([toEnd] false) or at the end of its range.
class _MoveDividerToEdgeIntent extends Intent {
  const _MoveDividerToEdgeIntent({required this.toEnd});

  final bool toEnd;
}

/// The drag handle between the two panes.
///
/// The scaffold state owns the ratio, the hover, focus and drag flags; this
/// widget only reports what happens to the divider through its callbacks, and
/// draws the handle: the default one from the theme, or the one from
/// `FoldableScaffold.dividerBuilder`.
class PaneDivider extends StatelessWidget {
  const PaneDivider({
    super.key,
    required this.constraints,
    required this.dividerSize,
    required this.atFold,
    required this.visible,
    required this.isHovering,
    required this.isDragging,
    required this.isFocused,
    required this.textDirection,
    required this.theme,
    required this.dividerBuilder,
    required this.semanticLabel,
    required this.semanticValue,
    required this.semanticIncreasedValue,
    required this.semanticDecreasedValue,
    required this.focusNode,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onHoverChanged,
    required this.onKeyboardResize,
    required this.onKeyboardEdge,
    required this.onIncrease,
    required this.onDecrease,
  });

  final BoxConstraints constraints;
  final double dividerSize;

  /// Whether the divider is the gap of a fold or hinge, which is not a handle.
  final bool atFold;

  /// Whether two panes are shown, so there is a divider to drag at all.
  final bool visible;

  final bool isHovering;
  final bool isDragging;
  final bool isFocused;
  final TextDirection textDirection;

  /// The theme of the divider, from the widget or inherited, with the fields
  /// that are set only; the rest is defaulted from the [ThemeData].
  final FoldableScaffoldThemeData? theme;

  final FoldableDividerBuilder? dividerBuilder;
  final String semanticLabel;
  final String semanticValue;
  final String semanticIncreasedValue;
  final String semanticDecreasedValue;
  final FocusNode focusNode;

  final VoidCallback onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<bool> onHoverChanged;

  /// A keyboard step: [direction] is -1 towards the start of the line, 1
  /// towards the end, and [large] is a step with Shift held.
  final void Function(int direction, {required bool large}) onKeyboardResize;

  /// Home or End: the smallest or the largest the secondary pane can be.
  final void Function({required bool toEnd}) onKeyboardEdge;

  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowLeft): _ResizeDividerIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _ResizeDividerIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
            _ResizeDividerIntent(-1, large: true),
        SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
            _ResizeDividerIntent(1, large: true),
        SingleActivator(LogicalKeyboardKey.home): _MoveDividerToEdgeIntent(
          toEnd: false,
        ),
        SingleActivator(LogicalKeyboardKey.end): _MoveDividerToEdgeIntent(
          toEnd: true,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final style = _DividerStyle.resolve(
      FoldableScaffoldThemeData.resolve(themeData, override: theme),
      themeData,
    );

    // The gap of a hinge, or a divider with no pane on one side, is not a
    // handle: nothing to drag, no focus stop and nothing to read out.
    if (atFold || !visible) {
      return ExcludeSemantics(
        child: ColoredBox(
          key: const Key('pane_divider'),
          color: style.backgroundColor,
        ),
      );
    }

    final state = FoldableDividerState(
      isHovering: isHovering,
      isDragging: isDragging,
      isFocused: isFocused,
      atFold: atFold,
      textDirection: textDirection,
    );

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ResizeDividerIntent: CallbackAction<_ResizeDividerIntent>(
            onInvoke: (intent) {
              onKeyboardResize(intent.direction, large: intent.large);
              return null;
            },
          ),
          _MoveDividerToEdgeIntent: CallbackAction<_MoveDividerToEdgeIntent>(
            onInvoke: (intent) {
              onKeyboardEdge(toEnd: intent.toEnd);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: focusNode,
          child: Semantics(
            container: true,
            slider: true,
            label: semanticLabel,
            value: semanticValue,
            increasedValue: semanticIncreasedValue,
            decreasedValue: semanticDecreasedValue,
            onIncrease: onIncrease,
            onDecrease: onDecrease,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              onEnter: (_) => onHoverChanged(true),
              onExit: (_) => onHoverChanged(false),
              child: GestureDetector(
                key: const Key('pane_divider'),
                onHorizontalDragStart: (_) => onDragStart(),
                onHorizontalDragUpdate: onDragUpdate,
                onHorizontalDragEnd: (_) => onDragEnd(),
                child: _surface(context: context, style: style, state: state),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _surface({
    required BuildContext context,
    required _DividerStyle style,
    required FoldableDividerState state,
  }) {
    return Container(
      color: style.backgroundColor,
      width: dividerSize,
      height: constraints.maxHeight,
      child: Center(
        child:
            dividerBuilder?.call(context, state) ??
            _DefaultHandle(style: style, active: state.isActive),
      ),
    );
  }
}

/// The divider theme with the defaults of the [ThemeData] filled in, so the
/// divider does not have to check every field.
class _DividerStyle {
  const _DividerStyle({
    required this.color,
    required this.activeColor,
    required this.backgroundColor,
    required this.handleSize,
    required this.handleActiveWidth,
    required this.handleBorderRadius,
    required this.animationDuration,
  });

  factory _DividerStyle.resolve(
    FoldableScaffoldThemeData data,
    ThemeData theme,
  ) {
    return _DividerStyle(
      color: data.dividerColor ?? theme.dividerColor,
      activeColor: data.dividerActiveColor ?? theme.colorScheme.primary,
      backgroundColor:
          data.dividerBackgroundColor ?? theme.scaffoldBackgroundColor,
      handleSize: data.handleSize ?? const Size(4, 50),
      handleActiveWidth: data.handleActiveWidth ?? 12,
      handleBorderRadius: data.handleBorderRadius,
      animationDuration:
          data.animationDuration ?? const Duration(milliseconds: 200),
    );
  }

  final Color color;
  final Color activeColor;
  final Color backgroundColor;
  final Size handleSize;
  final double handleActiveWidth;
  final BorderRadius? handleBorderRadius;
  final Duration animationDuration;

  /// The corners of a handle that is [width] wide: the theme's, or a pill as
  /// the divider always was (radius 2 at rest, 6 when active).
  BorderRadius radiusFor(double width) =>
      handleBorderRadius ?? BorderRadius.circular(width / 2);
}

/// The handle of the divider when no `dividerBuilder` is passed: a small pill
/// that grows, and takes the active color, while it is hovered, dragged or
/// focused.
class _DefaultHandle extends StatelessWidget {
  const _DefaultHandle({required this.style, required this.active});

  final _DividerStyle style;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final width = active ? style.handleActiveWidth : style.handleSize.width;
    return AnimatedContainer(
      width: width,
      height: style.handleSize.height,
      duration: style.animationDuration,
      decoration: BoxDecoration(
        color: active ? style.activeColor : style.color,
        borderRadius: style.radiusFor(width),
      ),
    );
  }
}
