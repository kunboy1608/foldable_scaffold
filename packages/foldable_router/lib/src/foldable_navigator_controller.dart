// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:material_ui/material_ui.dart';

/// Holds the page stacks (branches) of a [FoldableNavigator] and the current
/// branch.
///
/// Each change notifies listeners once, so only the navigator rebuilds; the
/// widget that owns the controller does not need `setState`.
///
/// Inside the navigator, get it with `FoldableNavigator.of(context)`.
class FoldableNavigatorController extends ChangeNotifier {
  /// One page stack per branch (e.g. per tab), each with at least one page.
  FoldableNavigatorController({
    required List<List<Page<Object?>>> branches,
    int initialIndex = 0,
  }) : assert(branches.isNotEmpty, 'Needs at least one branch.'),
       assert(
         branches.every((pages) => pages.isNotEmpty),
         'Every branch needs at least one page.',
       ),
       assert(initialIndex >= 0 && initialIndex < branches.length),
       _branches = [for (final pages in branches) List.of(pages)],
       _currentIndex = initialIndex;

  /// A controller with a single page stack.
  FoldableNavigatorController.single(List<Page<Object?>> pages)
    : this(branches: [pages]);

  final List<List<Page<Object?>>> _branches;
  final Map<Page<Object?>, Completer<Object?>> _results = {};
  int _currentIndex;
  int _batchDepth = 0;
  bool _notifyPending = false;

  /// Number of branches (page stacks).
  int get branchCount => _branches.length;

  /// Index of the branch on screen.
  int get currentIndex => _currentIndex;

  /// Pages of [branch], bottom first. Read-only view, no copy.
  List<Page<Object?>> pagesOf(int branch) =>
      UnmodifiableListView(_branches[branch]);

  /// Pages of the current branch, bottom first.
  List<Page<Object?>> get pages => pagesOf(_currentIndex);

  /// Whether [pop] would remove a page from the current branch.
  bool get canPop => _branches[_currentIndex].length > 1;

  /// Shows branch [index]. Its pages are kept as they were.
  void goBranch(int index) {
    assert(index >= 0 && index < _branches.length);
    if (index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Runs [mutations] and notifies listeners once, after all of them are
  /// applied, so the navigator renders the final stacks instead of every step.
  void batch(void Function() mutations) {
    _batchDepth++;
    try {
      mutations();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0 && _notifyPending) {
        _notifyPending = false;
        super.notifyListeners();
      }
    }
  }

  /// Inside [batch] this only remembers that something changed.
  @override
  void notifyListeners() {
    if (_batchDepth > 0) {
      _notifyPending = true;
      return;
    }
    super.notifyListeners();
  }

  /// Adds [page] on top of [branch] (default: the current one).
  ///
  /// Completes with the result given to [pop], or null when the page is
  /// removed another way.
  Future<T?> push<T extends Object?>(Page<T> page, {int? branch}) {
    final future = _track(page);
    _branches[branch ?? _currentIndex].add(page);
    notifyListeners();
    return future;
  }

  /// Removes pages from the top of [branch] until [predicate] is true for the
  /// top page, then adds [page]. One update, so one transition.
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    Page<T> page,
    bool Function(Page<Object?> page) predicate, {
    int? branch,
  }) {
    final pages = _branches[branch ?? _currentIndex];
    while (pages.isNotEmpty && !predicate(pages.last)) {
      _complete(pages.removeLast(), null);
    }
    final future = _track(page);
    pages.add(page);
    notifyListeners();
    return future;
  }

  /// Removes the top page of the current branch, unless it is the last one
  /// or its [Page.canPop] is false.
  ///
  /// Returns whether a page was removed.
  bool pop<T extends Object?>([T? result]) {
    if (!canPop) return false;
    final top = _branches[_currentIndex].last;
    if (!top.canPop) {
      top.onPopInvoked(false, result);
      return false;
    }
    _branches[_currentIndex].removeLast();
    top.onPopInvoked(true, result);
    _complete(top, result);
    notifyListeners();
    return true;
  }

  /// Removes [page] and every page above it from the branch that holds it.
  ///
  /// Unlike [pop], [page] does not have to be the top page, so a page that is
  /// not the last one (the body page of a split view) can pop itself. The
  /// first page of a branch is never removed, like [popUntil]: popping it only
  /// removes the pages above it.
  ///
  /// Returns whether a page was removed. [page] receives [result]; the pages
  /// above it are removed with a null result. Like [pop], nothing is removed
  /// when [page] cannot be popped ([Page.canPop] is false).
  bool popPage<T extends Object?>(Page<Object?> page, [T? result]) {
    for (final pages in _branches) {
      final index = pages.lastIndexWhere((p) => identical(p, page));
      if (index < 0) continue;
      // Popping the top page is what [pop] already does.
      if (index == pages.length - 1) return pop(result);
      if (!page.canPop) {
        page.onPopInvoked(false, result);
        return false;
      }
      // Keep the first page of the branch, so it can never be emptied.
      final from = index == 0 ? 1 : index;
      while (pages.length > from) {
        final removed = pages.removeLast();
        final removedResult = identical(removed, page) ? result : null;
        removed.onPopInvoked(true, removedResult);
        _complete(removed, removedResult);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Removes pages from the top of [branch] until [predicate] is true for the
  /// top page. The first page is never removed.
  void popUntil(bool Function(Page<Object?> page) predicate, {int? branch}) {
    final pages = _branches[branch ?? _currentIndex];
    var changed = false;
    while (pages.length > 1 && !predicate(pages.last)) {
      _complete(pages.removeLast(), null);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Removes every page of [branch] except the first one.
  void popToRoot({int? branch}) {
    final pages = _branches[branch ?? _currentIndex];
    popUntil((page) => identical(page, pages.first), branch: branch);
  }

  /// Replaces all pages of [branch] at once.
  void setPages(List<Page<Object?>> pages, {int? branch}) {
    assert(pages.isNotEmpty, 'A branch needs at least one page.');
    final index = branch ?? _currentIndex;
    for (final old in _branches[index]) {
      if (!pages.contains(old)) _complete(old, null);
    }
    _branches[index] = List.of(pages);
    notifyListeners();
  }

  Future<T?> _track<T extends Object?>(Page<T> page) {
    final completer = Completer<T?>();
    _results[page] = completer;
    return completer.future;
  }

  void _complete(Page<Object?> page, Object? result) {
    final completer = _results.remove(page);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  @override
  void dispose() {
    for (final completer in _results.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _results.clear();
    super.dispose();
  }
}
