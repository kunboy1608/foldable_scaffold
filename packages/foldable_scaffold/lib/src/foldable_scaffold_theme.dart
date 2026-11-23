import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// The look of the divider of a [FoldableScaffold], as a [ThemeExtension].
///
/// Put it in the [ThemeData] of the app to style every divider below it:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       FoldableScaffoldThemeData(dividerActiveColor: Colors.teal),
///     ],
///   ),
///   // ...
/// )
/// ```
///
/// `FoldableScaffold.theme` overrides it for one scaffold. Every field is
/// nullable: a field left null falls back to the inherited extension, then to
/// the default taken from the [ThemeData] of the scaffold, which is the same
/// look the divider always had. An empty instance changes nothing that is
/// seen.
///
/// Only the handle is themed. To replace the handle itself, use
/// `FoldableScaffold.dividerBuilder`.
@immutable
class FoldableScaffoldThemeData
    extends ThemeExtension<FoldableScaffoldThemeData>
    with Diagnosticable {
  /// Creates a divider theme. A null field keeps the inherited look, or the
  /// default.
  const FoldableScaffoldThemeData({
    this.dividerColor,
    this.dividerActiveColor,
    this.dividerBackgroundColor,
    this.handleSize,
    this.handleActiveWidth,
    this.handleBorderRadius,
    this.animationDuration,
  });

  /// The color of the handle at rest.
  ///
  /// Defaults to [ThemeData.dividerColor].
  final Color? dividerColor;

  /// The color of the handle while it is hovered, dragged or focused.
  ///
  /// Defaults to [ColorScheme.primary].
  final Color? dividerActiveColor;

  /// The color behind the handle, filling the divider slot.
  ///
  /// Defaults to [ThemeData.scaffoldBackgroundColor].
  final Color? dividerBackgroundColor;

  /// The size of the handle at rest.
  ///
  /// Defaults to `Size(4, 50)`. The handle is centered in the divider slot,
  /// which is `FoldableScaffold.dividerSize` wide.
  final Size? handleSize;

  /// The width of the handle while it is hovered, dragged or focused. Its
  /// height stays [handleSize]'s.
  ///
  /// Defaults to 12.
  final double? handleActiveWidth;

  /// The corners of the handle.
  ///
  /// Defaults to a pill: half of the width the handle has in the current
  /// state (2 at rest, 6 when active), which is what the divider looked like
  /// before it could be themed.
  final BorderRadius? handleBorderRadius;

  /// How long the handle takes to go from its rest look to its active look,
  /// when it is hovered, dragged or focused.
  ///
  /// Defaults to 200 milliseconds.
  final Duration? animationDuration;

  /// The theme in effect for [theme]: every field of [override] that is not
  /// null wins over the [FoldableScaffoldThemeData] that the [theme] carries
  /// as an extension, and the fields that are still null are left for the
  /// divider to default.
  static FoldableScaffoldThemeData resolve(
    ThemeData theme, {
    FoldableScaffoldThemeData? override,
  }) {
    final inherited = theme.extension<FoldableScaffoldThemeData>();
    if (inherited == null) {
      return override ?? const FoldableScaffoldThemeData();
    }
    return inherited.merge(override);
  }

  /// This theme with the fields of [other] that are not null put on top.
  ///
  /// Used to put one theme over another: the theme of a widget over the one
  /// it inherits from its [ThemeData].
  FoldableScaffoldThemeData merge(FoldableScaffoldThemeData? other) {
    if (other == null) return this;
    return FoldableScaffoldThemeData(
      dividerColor: other.dividerColor ?? dividerColor,
      dividerActiveColor: other.dividerActiveColor ?? dividerActiveColor,
      dividerBackgroundColor:
          other.dividerBackgroundColor ?? dividerBackgroundColor,
      handleSize: other.handleSize ?? handleSize,
      handleActiveWidth: other.handleActiveWidth ?? handleActiveWidth,
      handleBorderRadius: other.handleBorderRadius ?? handleBorderRadius,
      animationDuration: other.animationDuration ?? animationDuration,
    );
  }

  @override
  FoldableScaffoldThemeData copyWith({
    Color? dividerColor,
    Color? dividerActiveColor,
    Color? dividerBackgroundColor,
    Size? handleSize,
    double? handleActiveWidth,
    BorderRadius? handleBorderRadius,
    Duration? animationDuration,
  }) {
    return FoldableScaffoldThemeData(
      dividerColor: dividerColor ?? this.dividerColor,
      dividerActiveColor: dividerActiveColor ?? this.dividerActiveColor,
      dividerBackgroundColor:
          dividerBackgroundColor ?? this.dividerBackgroundColor,
      handleSize: handleSize ?? this.handleSize,
      handleActiveWidth: handleActiveWidth ?? this.handleActiveWidth,
      handleBorderRadius: handleBorderRadius ?? this.handleBorderRadius,
      animationDuration: animationDuration ?? this.animationDuration,
    );
  }

  @override
  FoldableScaffoldThemeData lerp(
    covariant FoldableScaffoldThemeData? other,
    double t,
  ) {
    if (other == null) return this;
    return FoldableScaffoldThemeData(
      dividerColor: _lerpField(dividerColor, other.dividerColor, Color.lerp, t),
      dividerActiveColor: _lerpField(
        dividerActiveColor,
        other.dividerActiveColor,
        Color.lerp,
        t,
      ),
      dividerBackgroundColor: _lerpField(
        dividerBackgroundColor,
        other.dividerBackgroundColor,
        Color.lerp,
        t,
      ),
      handleSize: _lerpField(handleSize, other.handleSize, Size.lerp, t),
      handleActiveWidth: _lerpField(
        handleActiveWidth,
        other.handleActiveWidth,
        lerpDouble,
        t,
      ),
      handleBorderRadius: _lerpField(
        handleBorderRadius,
        other.handleBorderRadius,
        BorderRadius.lerp,
        t,
      ),
      animationDuration: _lerpField(
        animationDuration,
        other.animationDuration,
        (a, b, t) => a + (b - a) * t,
        t,
      ),
    );
  }

  /// [lerp] of the two values, keeping the one that is known when only one
  /// side sets the field, so a field of one theme does not fade out to null.
  static T? _lerpField<T>(
    T? a,
    T? b,
    T? Function(T a, T b, double t) lerp,
    double t,
  ) {
    if (a == null) return b;
    if (b == null) return a;
    return lerp(a, b, t);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoldableScaffoldThemeData &&
        other.dividerColor == dividerColor &&
        other.dividerActiveColor == dividerActiveColor &&
        other.dividerBackgroundColor == dividerBackgroundColor &&
        other.handleSize == handleSize &&
        other.handleActiveWidth == handleActiveWidth &&
        other.handleBorderRadius == handleBorderRadius &&
        other.animationDuration == animationDuration;
  }

  @override
  int get hashCode => Object.hash(
    dividerColor,
    dividerActiveColor,
    dividerBackgroundColor,
    handleSize,
    handleActiveWidth,
    handleBorderRadius,
    animationDuration,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('dividerColor', dividerColor))
      ..add(ColorProperty('dividerActiveColor', dividerActiveColor))
      ..add(ColorProperty('dividerBackgroundColor', dividerBackgroundColor))
      ..add(DiagnosticsProperty<Size>('handleSize', handleSize))
      ..add(DoubleProperty('handleActiveWidth', handleActiveWidth))
      ..add(
        DiagnosticsProperty<BorderRadius>(
          'handleBorderRadius',
          handleBorderRadius,
        ),
      )
      ..add(
        DiagnosticsProperty<Duration>('animationDuration', animationDuration),
      );
  }
}
