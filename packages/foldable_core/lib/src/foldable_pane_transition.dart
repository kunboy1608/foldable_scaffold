// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Whether pages are sliding right now, so `FoldableScaffold` switches the
/// visible pane instantly instead of animating the pane resize on top of the
/// slide.
///
/// `FoldableNavigator` (in `foldable_router`) provides this scope around the
/// widget its builder returns, so a `FoldableScaffold` built there picks the
/// signal up without wiring. Use `FoldableScaffold.paneTransition` to supply
/// your own signal instead.
class FoldablePaneTransitionScope
    extends InheritedNotifier<ValueListenable<bool>> {
  const FoldablePaneTransitionScope({
    required ValueListenable<bool> transition,
    required super.child,
    super.key,
  }) : super(notifier: transition);

  /// Whether a page transition is running in the closest scope.
  static bool isTransitioningOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<FoldablePaneTransitionScope>()
            ?.notifier
            ?.value ??
        false;
  }

  /// The transition signal of the closest scope, if any.
  static ValueListenable<bool>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FoldablePaneTransitionScope>()
        ?.notifier;
  }

  @override
  bool updateShouldNotify(FoldablePaneTransitionScope oldWidget) {
    return super.updateShouldNotify(oldWidget) ||
        notifier != oldWidget.notifier;
  }
}
