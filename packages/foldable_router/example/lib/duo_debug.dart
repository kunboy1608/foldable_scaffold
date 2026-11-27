import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Debug logs for running `with_scaffold.dart` on a device (iPhone Duo): what
/// the platform reports, which shell is on screen, and where each tab puts its
/// navigation. Every line starts with `[duo]`; a log is only printed when its
/// text changed since the last time, so the console stays readable.
abstract final class DuoLog {
  static final Map<String, String> _last = <String, String>{};

  /// Prints [text] under [key] unless it is what [key] printed last.
  static void log(String key, String text) {
    if (_last[key] == text) return;
    _last[key] = text;
    final String body = text
        .split('\n')
        .map((line) => '[duo] $line')
        .join('\n');
    debugPrint('[duo] ---- $key ----\n$body');
  }
}

/// Logs the platform data each time it changes. Put it right below
/// [FoldablePlatformScope].
class DuoPlatformLogger extends StatefulWidget {
  const DuoPlatformLogger({super.key, required this.child});

  final Widget child;

  @override
  State<DuoPlatformLogger> createState() => _DuoPlatformLoggerState();
}

class _DuoPlatformLoggerState extends State<DuoPlatformLogger> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    DuoLog.log('platform', describeDuoPlatform(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Logs the stack of [router] (which shell is on screen) when it changes.
void logDuoStack(FoldableRouter router) {
  void report() {
    final stack = router.stack;
    DuoLog.log(
      'router',
      'shell: ${stack.isEmpty ? 'none' : stack.first.runtimeType}\n'
          'stack: ${stack.map((r) => r is FoldableShellRoute ? '[${r.runtimeType}]' : r.uri.toString()).join(' > ')}',
    );
  }

  router.addListener(report);
  report();
}

/// What the platform scope gave to [context], as text.
String describeDuoPlatform(BuildContext context) {
  final media = MediaQuery.of(context);
  final platform = FoldablePlatformScope.maybeOf(context);
  final lines = <String>[
    'platform: ${defaultTargetPlatform.name}${kIsWeb ? ' (web: the platform scope is off)' : ''}',
    'MediaQuery.size: ${_size(media.size)}',
    'MediaQuery.padding: ${media.padding}',
    'MediaQuery.viewPadding: ${media.viewPadding}',
    'MediaQuery.displayFeatures:',
    ..._features(media.displayFeatures),
    'FoldableVerticalBarScope.edge: '
        '${FoldableVerticalBarScope.maybeOf(context)?.name ?? 'null'}',
  ];
  if (platform == null) {
    lines.add('platform state: none (the scope only works natively on iOS)');
    return lines.join('\n');
  }
  lines
    ..add(
      'platform state: protocol version ${platform.version}'
      '${platform.version == 0 ? ' (0: no answer from the iOS plugin yet)' : ''}',
    )
    ..add('  view size: ${_size(platform.viewSize)}')
    ..add('  verticalBarEdge: ${platform.verticalBarEdge?.name ?? 'null'}')
    ..add('  divisions (${platform.divisions.length}):')
    ..addAll(_regions(platform.divisions))
    ..add('  occlusions (${platform.occlusions.length}):')
    ..addAll(_regions(platform.occlusions));
  return lines.join('\n');
}

/// Logs what the scaffold of tab [tab] sees where `buildPanes` runs.
void logDuoTab(BuildContext context, String tab, FoldablePanes panes) {
  final media = MediaQuery.of(context);
  DuoLog.log(
    'tab $tab',
    'constraints: ${panes.constraints}\n'
        'hasSecondary: ${panes.hasSecondary}\n'
        'MediaQuery.size: ${_size(media.size)}\n'
        'MediaQuery.padding: ${media.padding}\n'
        'MediaQuery.displayFeatures:\n'
        '${_features(media.displayFeatures).join('\n')}\n'
        'FoldableVerticalBarScope.edge: '
        '${FoldableVerticalBarScope.maybeOf(context)?.name ?? 'null'}',
  );
}

/// Logs where the scaffold of tab [tab] put its navigation.
void logDuoNavigation(
  String tab,
  FoldableNavigationPlacement placement,
  BoxConstraints constraints,
  EdgeInsets padding,
) {
  DuoLog.log(
    'navigation $tab',
    'placement: ${placement.edge.name}, alignment ${placement.alignment.name}, '
        'insideInset ${placement.insideInset}, extent ${placement.extent}\n'
        'widget: ${placement.isSide ? 'NavigationRail' : 'NavigationBar'}\n'
        'constraints: $constraints\n'
        'padding: $padding',
  );
}

String _size(Size size) =>
    '${size.width.toStringAsFixed(2)} x ${size.height.toStringAsFixed(2)}';

String _rect(Rect rect) =>
    'L${rect.left.toStringAsFixed(2)} T${rect.top.toStringAsFixed(2)} '
    'R${rect.right.toStringAsFixed(2)} B${rect.bottom.toStringAsFixed(2)} '
    '(${_size(rect.size)})';

Iterable<String> _features(List<DisplayFeature> features) => features.isEmpty
    ? const ['  none']
    : [
        for (final f in features)
          '  ${f.type.name}, ${f.state.name}: ${_rect(f.bounds)}',
      ];

Iterable<String> _regions(List<FoldableReservedRegion> regions) =>
    regions.isEmpty
    ? const ['    none']
    : [
        for (final r in regions)
          '    ${r.isActive ? 'active' : 'inactive'}: ${_rect(r.frame)}'
              '${r.margins == EdgeInsets.zero ? '' : ', margins ${r.margins}'}',
      ];
