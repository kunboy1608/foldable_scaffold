import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
    ..add(
      'platform displayFeatures (all, as the scope gives them; a dialog or a '
      'sub-screen only keeps the features of the half it is in, so '
      'MediaQuery.displayFeatures above may have fewer):',
    )
    ..addAll(_features(platform.displayFeatures));
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
///
/// The **Copy** button puts the text on the clipboard, with the name of the pose
/// typed in the field on top, so each pose of a device can be pasted as one
/// block.
class PlatformDebugDialog extends StatefulWidget {
  const PlatformDebugDialog({super.key});

  @override
  State<PlatformDebugDialog> createState() => _PlatformDebugDialogState();
}

class _PlatformDebugDialogState extends State<PlatformDebugDialog> {
  final _pose = TextEditingController();
  bool _copied = false;

  @override
  void dispose() {
    _pose.dispose();
    super.dispose();
  }

  Future<void> _copy(String report) async {
    final pose = _pose.text.trim();
    await Clipboard.setData(
      ClipboardData(text: pose.isEmpty ? report : 'pose: $pose\n$report'),
    );
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final report = describePlatformData(context);
    return AlertDialog(
      title: const Text('Platform data'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('platform_data_pose'),
              controller: _pose,
              decoration: const InputDecoration(
                labelText: 'Pose (optional)',
                hintText: 'outer, inner portrait, half folded...',
              ),
              onChanged: (_) => setState(() => _copied = false),
            ),
            const SizedBox(height: 12),
            SelectableText(
              report,
              key: const Key('platform_data'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('platform_data_copy'),
          onPressed: () => _copy(report),
          icon: Icon(_copied ? Icons.check : Icons.copy),
          label: Text(_copied ? 'Copied' : 'Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
