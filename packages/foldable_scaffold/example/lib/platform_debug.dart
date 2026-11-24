import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Prints what the platform reports each time it changes, to read the numbers
/// of a device (say, an iPhone Duo in the simulator) in the console.
///
/// Put it below [FoldablePlatformScope]. It also prints the first state it sees.
class PlatformDebugLogger extends StatefulWidget {
  const PlatformDebugLogger({super.key, required this.child});

  final Widget child;

  @override
  State<PlatformDebugLogger> createState() => _PlatformDebugLoggerState();
}

class _PlatformDebugLoggerState extends State<PlatformDebugLogger> {
  String? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final report = describePlatformData(context);
    if (report != _last) {
      _last = report;
      debugPrint('[foldable_scaffold] platform data changed\n$report');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// What the platform scope gave to [context], as text: the window, the display
/// features of the `MediaQuery` and the platform state with its numbers.
String describePlatformData(BuildContext context) {
  final media = MediaQuery.of(context);
  final platform = FoldablePlatformScope.maybeOf(context);
  final lines = <String>[
    'platform: ${defaultTargetPlatform.name}${kIsWeb ? ' (web)' : ''}',
    'MediaQuery.size: ${_size(media.size)}',
    'MediaQuery.padding: ${media.padding}',
    'MediaQuery.displayFeatures:',
    ..._features(media.displayFeatures),
    'FoldableVerticalBarScope.edge: '
        '${FoldableVerticalBarScope.maybeOf(context)?.name ?? 'null'}',
  ];
  if (platform == null) {
    lines.add('platform state: none (the scope only works on iOS)');
    return lines.join('\n');
  }
  lines
    ..add('platform state: protocol version ${platform.version}')
    ..add('  view size: ${_size(platform.viewSize)}')
    ..add('  verticalBarEdge: ${platform.verticalBarEdge?.name ?? 'null'}')
    ..add('  divisions (${platform.divisions.length}):')
    ..addAll(_regions(platform.divisions))
    ..add('  occlusions (${platform.occlusions.length}):')
    ..addAll(_regions(platform.occlusions));
  return lines.join('\n');
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

/// The button of the app bar: opens [PlatformDebugDialog].
class PlatformDebugButton extends StatelessWidget {
  const PlatformDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.developer_board),
      tooltip: 'Platform data',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => const PlatformDebugDialog(),
      ),
    );
  }
}

/// Shows [describePlatformData], live: it is rebuilt when the data changes.
class PlatformDebugDialog extends StatelessWidget {
  const PlatformDebugDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Platform data'),
      content: SingleChildScrollView(
        child: SelectableText(
          describePlatformData(context),
          key: const Key('platform_data'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
