import 'package:material_ui/material_ui.dart';

import 'foldable_router.dart';

/// Back button that closes the session on screen, for the app bar of a shell.
///
/// Shown only while the router has more than one session open and the one on
/// screen can be closed (see [FoldableRouterBase.canCloseSession]); otherwise
/// it takes no space. It always closes the session, never a page inside it, so
/// use [FoldableBackButton] for the pages.
///
/// ```dart
/// AppBar(leading: const FoldableSessionBackButton(), title: Text('Checkout'))
/// ```
class FoldableSessionBackButton extends StatelessWidget {
  const FoldableSessionBackButton({
    super.key,
    this.color,
    this.style,
    this.onPressed,
  });

  /// Color of the icon.
  final Color? color;

  /// Customizes this button's appearance, like [BackButton.style].
  final ButtonStyle? style;

  /// Called before the session is closed.
  final VoidCallback? onPressed;

  /// Whether the button would be shown at [context]. Does not subscribe
  /// [context] to changes.
  static bool isVisible(BuildContext context) {
    return FoldableRouterScope.maybeOf(context)?.canCloseSession ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouterScope.maybeOf(context);
    if (router == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: router,
      builder: (context, _) {
        if (!router.canCloseSession) return const SizedBox.shrink();
        return BackButton(
          color: color,
          style: style,
          onPressed: () {
            onPressed?.call();
            router.closeSession();
          },
        );
      },
    );
  }
}
