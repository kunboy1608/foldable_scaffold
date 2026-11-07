import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// Gives the screens of the example the app's [FoldableRouter].
///
/// Wraps `MaterialApp.router`, so every route, redirect and page can read the
/// router from its context without importing the router itself.
class AppRouterScope extends InheritedWidget {
  const AppRouterScope({required this.router, required super.child, super.key});

  final FoldableRouter router;

  /// The router of the example. Does not subscribe [context] to changes; the
  /// navigator and the controller already rebuild what movement changes.
  static FoldableRouter of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppRouterScope>();
    assert(scope != null, 'No AppRouterScope found in context.');
    return scope!.router;
  }

  @override
  bool updateShouldNotify(AppRouterScope oldWidget) =>
      router != oldWidget.router;
}
