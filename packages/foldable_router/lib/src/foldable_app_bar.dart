import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import 'route/branch_route.dart';

/// An [AppBar] that leaves out its automatic back button on the page of a
/// [BranchRoute].
///
/// Flutter's `AppBar` decides on its back button from the route it sits in, and
/// every page of a foldable navigator shares one route, so the bar cannot tell
/// a branch root from a pushed page. This one can: in a [BranchRoute] page
/// (see [BranchRoute.hideBackButton]) it behaves like
/// `AppBar(automaticallyImplyLeading: false)`, with no empty room or tap area
/// where the button would be. Everywhere else it is an [AppBar]; all
/// parameters are the same.
///
/// ```dart
/// Scaffold(appBar: FoldableAppBar(title: const Text('Inbox')))
/// ```
///
/// An explicit [leading] always wins.
class FoldableAppBar extends StatelessWidget implements PreferredSizeWidget {
  FoldableAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.automaticallyImplyActions = true,
    this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.backgroundColor,
    this.foregroundColor,
    this.iconTheme,
    this.actionsIconTheme,
    this.primary = true,
    this.centerTitle,
    this.excludeHeaderSemantics = false,
    this.titleSpacing,
    this.toolbarOpacity = 1.0,
    this.bottomOpacity = 1.0,
    this.toolbarHeight,
    this.leadingWidth,
    this.toolbarTextStyle,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.forceMaterialTransparency = false,
    this.useDefaultSemanticsOrder = true,
    this.clipBehavior,
    this.actionsPadding,
    this.animateColor = false,
  }) : preferredSize = AppBar(
         toolbarHeight: toolbarHeight,
         bottom: bottom,
       ).preferredSize;

  /// See [AppBar.leading].
  final Widget? leading;

  /// See [AppBar.automaticallyImplyLeading]. Treated as false in the page of a
  /// [BranchRoute].
  final bool automaticallyImplyLeading;

  /// See [AppBar.title].
  final Widget? title;

  /// See [AppBar.actions].
  final List<Widget>? actions;

  /// See [AppBar.automaticallyImplyActions].
  final bool automaticallyImplyActions;

  /// See [AppBar.flexibleSpace].
  final Widget? flexibleSpace;

  /// See [AppBar.bottom].
  final PreferredSizeWidget? bottom;

  /// See [AppBar.elevation].
  final double? elevation;

  /// See [AppBar.scrolledUnderElevation].
  final double? scrolledUnderElevation;

  /// See [AppBar.notificationPredicate].
  final ScrollNotificationPredicate notificationPredicate;

  /// See [AppBar.shadowColor].
  final Color? shadowColor;

  /// See [AppBar.surfaceTintColor].
  final Color? surfaceTintColor;

  /// See [AppBar.shape].
  final ShapeBorder? shape;

  /// See [AppBar.backgroundColor].
  final Color? backgroundColor;

  /// See [AppBar.foregroundColor].
  final Color? foregroundColor;

  /// See [AppBar.iconTheme].
  final IconThemeData? iconTheme;

  /// See [AppBar.actionsIconTheme].
  final IconThemeData? actionsIconTheme;

  /// See [AppBar.primary].
  final bool primary;

  /// See [AppBar.centerTitle].
  final bool? centerTitle;

  /// See [AppBar.excludeHeaderSemantics].
  final bool excludeHeaderSemantics;

  /// See [AppBar.titleSpacing].
  final double? titleSpacing;

  /// See [AppBar.toolbarOpacity].
  final double toolbarOpacity;

  /// See [AppBar.bottomOpacity].
  final double bottomOpacity;

  /// See [AppBar.toolbarHeight].
  final double? toolbarHeight;

  /// See [AppBar.leadingWidth].
  final double? leadingWidth;

  /// See [AppBar.toolbarTextStyle].
  final TextStyle? toolbarTextStyle;

  /// See [AppBar.titleTextStyle].
  final TextStyle? titleTextStyle;

  /// See [AppBar.systemOverlayStyle].
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// See [AppBar.forceMaterialTransparency].
  final bool forceMaterialTransparency;

  /// See [AppBar.useDefaultSemanticsOrder].
  final bool useDefaultSemanticsOrder;

  /// See [AppBar.clipBehavior].
  final Clip? clipBehavior;

  /// See [AppBar.actionsPadding].
  final EdgeInsetsGeometry? actionsPadding;

  /// See [AppBar.animateColor].
  final bool animateColor;

  /// The same size as the [AppBar] it builds, so a [Scaffold] lays it out the
  /// same way.
  @override
  final Size preferredSize;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      automaticallyImplyLeading:
          automaticallyImplyLeading &&
          !FoldableBranchRoot.hidesBackButton(context),
      title: title,
      actions: actions,
      automaticallyImplyActions: automaticallyImplyActions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      notificationPredicate: notificationPredicate,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      shape: shape,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      iconTheme: iconTheme,
      actionsIconTheme: actionsIconTheme,
      primary: primary,
      centerTitle: centerTitle,
      excludeHeaderSemantics: excludeHeaderSemantics,
      titleSpacing: titleSpacing,
      toolbarOpacity: toolbarOpacity,
      bottomOpacity: bottomOpacity,
      toolbarHeight: toolbarHeight,
      leadingWidth: leadingWidth,
      toolbarTextStyle: toolbarTextStyle,
      titleTextStyle: titleTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: forceMaterialTransparency,
      useDefaultSemanticsOrder: useDefaultSemanticsOrder,
      clipBehavior: clipBehavior,
      actionsPadding: actionsPadding,
      animateColor: animateColor,
    );
  }
}
