import 'package:flutter/widgets.dart';

/// Scales the duration of the animations of the widgets below it.
///
/// `foldable_dev_tools` uses it for slow motion, and tests can use it to make
/// transitions instant:
///
/// ```dart
/// FoldableMotion(
///   scale: (duration) => duration * 5,
///   child: const MyApp(),
/// )
/// ```
///
/// The closest `FoldableMotion` above a caller is read with
/// [FoldableMotion.of] or [FoldableMotion.readOf]; when there is none the
/// duration is returned unchanged.
class FoldableMotion extends InheritedWidget {
  const FoldableMotion({required this.scale, required super.child, super.key});

  /// Turns a configured duration into the one to run.
  final Duration Function(Duration duration) scale;

  /// [duration] scaled by the closest [FoldableMotion], or unchanged.
  static Duration of(BuildContext context, Duration duration) {
    final motion = context.dependOnInheritedWidgetOfExactType<FoldableMotion>();
    return motion == null ? duration : motion.scale(duration);
  }

  /// [duration] scaled by the closest [FoldableMotion], or unchanged, without
  /// subscribing [context] to it.
  ///
  /// For widgets that resolve the duration outside `build`.
  static Duration readOf(BuildContext context, Duration duration) {
    final motion = context.getInheritedWidgetOfExactType<FoldableMotion>();
    return motion == null ? duration : motion.scale(duration);
  }

  @override
  bool updateShouldNotify(FoldableMotion oldWidget) => scale != oldWidget.scale;
}
