// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:material_ui/material_ui.dart';

import 'foldable_navigator.dart';

/// Builds [child] the first time branch [branch] of the closest
/// [FoldableNavigator] is shown, and keeps it afterwards.
///
/// A [FoldableRouter] wraps every branch but the first one in it when
/// [FoldableRouterConfig.lazyBranches] is true, so a tab that is never opened
/// costs nothing at startup.
class LazyBranch extends StatefulWidget {
  const LazyBranch({required this.branch, required this.child, super.key});

  /// The branch that must be shown before [child] builds.
  final int branch;

  /// The branch's screen.
  final Widget child;

  @override
  State<LazyBranch> createState() => _LazyBranchState();
}

class _LazyBranchState extends State<LazyBranch> {
  bool _visited = false;

  @override
  Widget build(BuildContext context) {
    final current = FoldableNavigator.of(context, listen: true).currentIndex;
    _visited = _visited || current == widget.branch;
    return _visited ? widget.child : const SizedBox.shrink();
  }
}
