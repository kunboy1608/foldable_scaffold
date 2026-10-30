// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// Which panes of the enclosing `FoldableScaffold` are shown, based on the
/// target layout (not the animated one).
class FoldablePaneLayout extends InheritedWidget {
  const FoldablePaneLayout({
    required this.primaryVisible,
    required this.secondaryVisible,
    required super.child,
    super.key,
  });

  /// Whether the body pane is shown.
  final bool primaryVisible;

  /// Whether the secondary body pane is shown.
  final bool secondaryVisible;

  /// The layout of the enclosing `FoldableScaffold`, if any.
  static FoldablePaneLayout? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FoldablePaneLayout>();
  }

  @override
  bool updateShouldNotify(FoldablePaneLayout oldWidget) =>
      primaryVisible != oldWidget.primaryVisible ||
      secondaryVisible != oldWidget.secondaryVisible;
}
