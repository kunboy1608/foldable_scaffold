import 'package:material_ui/material_ui.dart';

/// A [Page] that can be shown inside a [FoldableNavigator].
///
/// It is a regular [Page], so the same page can also be handed to a normal
/// [Navigator] (it creates a [MaterialPageRoute]).
class FoldablePage<T> extends Page<T> {
  const FoldablePage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.canPop,
    super.onPopInvoked,
  });

  /// The widget shown for this page.
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return MaterialPageRoute<T>(settings: this, builder: (_) => child);
  }
}
