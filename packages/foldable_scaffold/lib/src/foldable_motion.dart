// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:material_ui/material_ui.dart';

/// Scales the duration of the animations of the widgets below it.
///
/// `foldable_dev_tools` uses it for slow motion, and tests can use it to make
/// transitions instant:
///
/// ```dart
/// FoldableMotion(
///   scale: (duration) => duration * 5,
///   child: FoldableDevTools(child: MyApp()),
/// )
/// ```
///
/// `FoldableScaffold` (and `FoldableNavigator` in `foldable_router`) read it
/// with [FoldableMotion.of].
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
