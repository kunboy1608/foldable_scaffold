// Control app for manual case F6: the same "page with a text field pushed
// above another page" as the lab, but with a plain MaterialApp and Navigator.
// foldable_router is not involved at all.
//
// It answers one question: when hiding the keyboard closes the pushed page in
// the lab, is that Flutter / the device keyboard, or the router?
//
// Run with: tool/manual_test.sh plain-android
// The steps are in MANUAL_TESTS.md.
import 'package:flutter/material.dart';

/// Counts the pages on the navigator, so the status bar can show it.
class _DepthObserver extends NavigatorObserver {
  final ValueNotifier<int> depth = ValueNotifier<int>(0);
  final ValueNotifier<int> pops = ValueNotifier<int>(0);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _later(() => depth.value++);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _later(() {
      depth.value--;
      pops.value++;
    });
  }

  // Observers may be called while the framework is building.
  void _later(VoidCallback change) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => change());
}

final _DepthObserver _observer = _DepthObserver();

void main() => runApp(const PlainApp());

class PlainApp extends StatelessWidget {
  const PlainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'plain Navigator control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      navigatorObservers: [_observer],
      home: const PlainHomePage(),
      builder: (context, child) => Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: child!,
            ),
          ),
          const _PlainStatus(),
        ],
      ),
    );
  }
}

class _PlainStatus extends StatelessWidget {
  const _PlainStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ListenableBuilder(
            listenable: Listenable.merge([_observer.depth, _observer.pops]),
            builder: (context, _) => Text(
              'pages on the Navigator: ${_observer.depth.value}'
              '   pops so far: ${_observer.pops.value}',
              key: const Key('plain-status'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}

class PlainHomePage extends StatelessWidget {
  const PlainHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plain Navigator (no router)')),
      body: Center(
        child: FilledButton(
          key: const Key('plain-push-note'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const PlainNotePage()),
          ),
          child: const Text('Navigator.push(note page)'),
        ),
      ),
    );
  }
}

class PlainNotePage extends StatelessWidget {
  const PlainNotePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Note (plain Navigator)')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: TextField(
          key: Key('plain-note-field'),
          decoration: InputDecoration(labelText: 'Type something'),
        ),
      ),
    );
  }
}
