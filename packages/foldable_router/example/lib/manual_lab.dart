// Manual test lab for the things widget tests cannot prove: typed params in a
// real address bar, and redirects that read the router's BuildContext while
// the window is resized, the device is rotated or the keyboard opens.
//
// Run with: tool/manual_test.sh lab-linux | lab-web | lab-android
// The steps are in MANUAL_TESTS.md.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:foldable_router/foldable_router.dart';

/// Lines written by the redirects, newest last.
final ValueNotifier<List<String>> labLog = ValueNotifier<List<String>>(const []);
int _redirectRuns = 0;

/// Redirects may run while the framework is building (a dependency of the
/// Router changed), so the log is updated in a microtask.
void _log(String line) {
  final int run = ++_redirectRuns;
  scheduleMicrotask(() {
    final next = [...labLog.value, '#$run $line'];
    labLog.value = next.length > 6 ? next.sublist(next.length - 6) : next;
  });
}

class LabHomeRoute extends FoldableRoute {
  const LabHomeRoute();

  @override
  String get path => '/';

  @override
  Widget build(BuildContext context) => const LabHomePage();
}

/// One parameter of every supported type.
class TypedRoute extends FoldableRoute {
  const TypedRoute({
    required this.count,
    required this.ratio,
    required this.flag,
    required this.at,
    this.note,
  });

  final int count;
  final double ratio;
  final bool flag;
  final DateTime at;
  final String? note;

  @override
  String get path => '/typed';

  @override
  Map<String, Object?> get params => {
    'count': count,
    'ratio': ratio,
    'flag': flag,
    'at': at,
    'note': note,
  };

  @override
  FoldableRoute? get parent => const LabHomeRoute();

  @override
  Widget build(BuildContext context) => TypedPage(route: this);
}

/// A slow redirect that depends on MediaQuery (all of it: size, keyboard
/// insets, orientation). Any such change while it is on the stack makes the
/// router re-check it.
class SlowRoute extends FoldableRoute {
  const SlowRoute();

  @override
  String get path => '/slow';

  @override
  FoldableRoute? get parent => const LabHomeRoute();

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    final Size size = MediaQuery.of(context).size;
    _log('Slow.redirect started at ${size.width.round()}x${size.height.round()}');
    await Future<void>.delayed(const Duration(seconds: 4));
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      const LabPage(title: 'Slow', pageKey: Key('slow-page'));
}

/// Only allowed while the window is at least 700 wide.
class WideOnlyRoute extends FoldableRoute {
  const WideOnlyRoute();

  static const double minWidth = 700;

  @override
  String get path => '/wide';

  @override
  FoldableRoute? get parent => const LabHomeRoute();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool allowed = width >= minWidth;
    _log('WideOnly.redirect at width ${width.round()}: '
        '${allowed ? 'allowed' : 'go Home'}');
    return allowed ? null : const LabHomeRoute();
  }

  @override
  Widget build(BuildContext context) =>
      const LabPage(title: 'Wide only (>= 700)', pageKey: Key('wide-page'));
}

/// A page with state (text + counter), pushed above whatever is shown.
class NoteRoute extends FoldableRoute {
  const NoteRoute();

  @override
  String get path => '/note';

  @override
  Widget build(BuildContext context) => const NotePage();
}

final Map<String, FoldableRouteFactory> labRoutes = {
  '/typed': (params) => TypedRoute(
    count: params.getInt('count'),
    ratio: params.getDouble('ratio'),
    flag: params.getBool('flag'),
    at: params.getDateTime('at'),
    note: params.getStringOrNull('note'),
  ),
  '/slow': (params) => const SlowRoute(),
  '/wide': (params) => const WideOnlyRoute(),
  '/note': (params) => const NoteRoute(),
};

FoldableRouter createLabRouter() => FoldableRouter(
  initial: const LabHomeRoute(),
  routes: labRoutes,
  notFoundBuilder: (context, uri) => Scaffold(
    appBar: AppBar(title: const Text('Not found')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No route for $uri', key: const Key('not-found')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                FoldableRouter.of(context).open(const LabHomeRoute()),
            child: const Text('Go home'),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  usePathUrlStrategy();
  runApp(LabApp(router: createLabRouter()));
}

class LabApp extends StatelessWidget {
  const LabApp({super.key, required this.router});

  final FoldableRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'foldable_router manual lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      routerConfig: router.routerConfig,
      builder: (context, child) => Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: child!,
            ),
          ),
          LabStatus(router: router),
        ],
      ),
    );
  }
}

/// Stack, location, isNavigating, window size and the redirect log.
class LabStatus extends StatelessWidget {
  const LabStatus({super.key, required this.router});

  final FoldableRouter router;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall,
            child: ListenableBuilder(
              listenable: Listenable.merge([
                router,
                router.isNavigating,
                labLog,
              ]),
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 4,
                    child: router.isNavigating.value
                        ? const LinearProgressIndicator(key: Key('navigating'))
                        : null,
                  ),
                  Text(
                    'stack: ${router.stack.map((r) => r.uri).join('  >  ')}',
                    key: const Key('stack'),
                  ),
                  Text('location: ${router.location}', key: const Key('location')),
                  Text(
                    'window: ${size.width.round()} x ${size.height.round()}'
                    '   isNavigating: ${router.isNavigating.value}',
                  ),
                  for (final line in labLog.value) Text(line),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LabHomePage extends StatelessWidget {
  const LabHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Manual lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            key: const Key('open-typed'),
            onPressed: () => router.open(
              TypedRoute(
                count: 42,
                ratio: 1.5,
                flag: true,
                at: DateTime(2026, 1, 2, 3, 4, 5),
                note: 'xin chào & tạm biệt',
              ),
            ),
            child: const Text('open(TypedRoute) - one param per type'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('open-slow'),
            onPressed: () => router.open(const SlowRoute()),
            child: const Text('open(SlowRoute) - redirect takes 4 s'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('push-slow'),
            onPressed: () => router.push<void>(const SlowRoute()),
            child: const Text('push(SlowRoute) - redirect takes 4 s'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('open-wide'),
            onPressed: () => router.open(const WideOnlyRoute()),
            child: const Text('open(WideOnlyRoute) - needs width >= 700'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('push-note'),
            onPressed: () => router.push<void>(const NoteRoute()),
            child: const Text('push(NoteRoute) - page with state'),
          ),
        ],
      ),
    );
  }
}

/// A plain page with the buttons needed to build deeper stacks.
class LabPage extends StatelessWidget {
  const LabPage({super.key, required this.title, required this.pageKey});

  final String title;
  final Key pageKey;

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    return Scaffold(
      key: pageKey,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('push-note'),
              onPressed: () => router.push<void>(const NoteRoute()),
              child: const Text('push(NoteRoute) - page with state'),
            ),
            TextButton(
              onPressed: () => router.open(const LabHomeRoute()),
              child: const Text('open(LabHomeRoute)'),
            ),
          ],
        ),
      ),
    );
  }
}

class TypedPage extends StatelessWidget {
  const TypedPage({super.key, required this.route});

  final TypedRoute route;

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    Widget row(String name, Object? value) => ListTile(
      dense: true,
      title: Text('$name = $value'),
      subtitle: Text('${value.runtimeType}'),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Typed params')),
      body: ListView(
        children: [
          row('count', route.count),
          row('ratio', route.ratio),
          row('flag', route.flag),
          row('at', route.at),
          row('at (isUtc)', route.at.isUtc),
          row('note', route.note),
          ListTile(title: SelectableText('uri: ${route.uri}')),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const Key('open-typed-other'),
              onPressed: () => router.open(
                TypedRoute(
                  count: -7,
                  ratio: 0.1 + 0.2,
                  flag: false,
                  at: DateTime.utc(1999, 12, 31, 23, 59, 59),
                ),
              ),
              child: const Text('open with other values (no note)'),
            ),
          ),
        ],
      ),
    );
  }
}

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Note (has state)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TextField(
              key: Key('note-field'),
              decoration: InputDecoration(labelText: 'Type something'),
            ),
            const SizedBox(height: 16),
            Text('Counter: $_count', key: const Key('note-count')),
            FilledButton(
              key: const Key('note-increment'),
              onPressed: () => setState(() => _count++),
              child: const Text('Counter + 1'),
            ),
            TextButton(
              onPressed: () => FoldableRouter.of(context).pop(),
              child: const Text('pop()'),
            ),
          ],
        ),
      ),
    );
  }
}
