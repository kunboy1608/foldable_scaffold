import 'package:flutter/widgets.dart';
import 'package:foldable_router/foldable_router.dart';

/// A small host used by router tests and the standalone router example.
///
/// [secondaryExtent] is expressed in the split axis; when it is null, the
/// host uses an even split after reserving [dividerExtent].
class RectsTestHarness extends StatelessWidget {
  const RectsTestHarness({
    super.key,
    required this.child,
    required this.enabled,
    this.emptySecondary,
    this.axis = Axis.horizontal,
    this.secondaryExtent,
    this.secondaryFraction,
    this.dividerExtent = 24,
    this.textDirection = TextDirection.ltr,
  });

  final Widget child;
  final bool enabled;

  /// Drawn in the secondary rectangle when no top page is shown there.
  final Widget? emptySecondary;
  final Axis axis;
  final double? secondaryExtent;
  final double? secondaryFraction;
  final double dividerExtent;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final FoldablePaneRects rects;
      if (!enabled) {
        rects = FoldablePaneRects(
          primary: Offset.zero & size,
          secondary: null,
          axis: axis,
        );
      } else if (axis == Axis.horizontal) {
        rects = FoldablePaneRects.sideBySide(
          size,
          secondaryExtent: secondaryExtent,
          secondaryFraction:
              secondaryFraction ?? (secondaryExtent == null ? 0.5 : null),
          dividerExtent: dividerExtent,
          textDirection: textDirection,
        );
      } else {
        rects = FoldablePaneRects.stacked(
          size,
          secondaryExtent: secondaryExtent,
          secondaryFraction:
              secondaryFraction ?? (secondaryExtent == null ? 0.5 : null),
          dividerExtent: dividerExtent,
          textDirection: textDirection,
        );
      }
      return FoldablePaneRectsScope(
        rects: rects,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (rects.primary case final primary?)
              Positioned.fromRect(
                rect: primary,
                child: const IgnorePointer(
                  child: SizedBox.expand(key: Key('primary-frame')),
                ),
              ),
            if (rects.secondary case final secondary?) ...[
              if (emptySecondary case final empty?)
                Positioned.fromRect(rect: secondary, child: empty),
              Positioned.fromRect(
                rect: secondary,
                child: const IgnorePointer(
                  child: SizedBox.expand(key: Key('secondary-frame')),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
