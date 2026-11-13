import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

/// What a redirect saw: the context itself and what can be read from it.
class Seen {
  Seen(this.context, this.marker, this.brightness, this.size, this.locale);

  final BuildContext context;
  final int? marker;
  final Brightness brightness;
  final Size size;
  final Locale locale;
}

final List<Seen> seen = <Seen>[];

void record(BuildContext context) {
  seen.add(
    Seen(
      context,
      context.getInheritedWidgetOfExactType<Marker>()?.value,
      Theme.of(context).brightness,
      MediaQuery.of(context).size,
      Localizations.localeOf(context),
    ),
  );
}

/// An InheritedWidget placed above `MaterialApp.router`.
class Marker extends InheritedWidget {
  const Marker({super.key, required this.value, required super.child});

  final int value;

  @override
  bool updateShouldNotify(Marker oldWidget) => value != oldWidget.value;
}

class RecordingRoute extends FoldableRoute {
  const RecordingRoute(this.path);

  @override
  final String path;

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    record(context);
    return null;
  }

  @override
  Widget build(BuildContext context) => Text('recording $path');
}

class RecordShell extends FoldableShellRoute {
  const RecordShell();

  @override
  List<FoldableRoute> get branches =>
      const [RecordBranch('a'), RecordBranch('b')];

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    record(context);
    return null;
  }

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Scaffold(
    body: shell.child,
    bottomNavigationBar: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < branches.length; i++)
            TextButton(
              key: Key('tab-$i'),
              onPressed: () => shell.goBranch(i),
              child: Text('tab $i'),
            ),
        ],
      ),
    ),
  );
}

class RecordBranch extends FoldableRoute {
  const RecordBranch(this.segment);

  final String segment;

  @override
  String get path => '/$segment';

  @override
  FoldableRoute? get parent => const RecordShell();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    record(context);
    return null;
  }

  @override
  Widget build(BuildContext context) => Text('branch $segment');
}

class HomeStub extends FoldableRoute {
  const HomeStub();

  @override
  String get path => '/';

  @override
  Widget build(BuildContext context) => const Text('home');
}

Completer<void>? gate;

/// Redirects only after [gate] completes.
class GatedParent extends FoldableRoute {
  const GatedParent();

  @override
  String get path => '/gated';

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) async {
    await gate!.future;
    return null;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Counts how many times its redirect ran.
class CountingChild extends FoldableRoute {
  const CountingChild();

  static int redirects = 0;

  @override
  String get path => '/gated/child';

  @override
  FoldableRoute? get parent => const GatedParent();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    redirects++;
    record(context);
    return null;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

FoldableRouter buildShellRouter() {
  final router = FoldableRouter(
    initial: const RecordShell(),
    routes: {
      '/u': (_) => const RecordingRoute('/u'),
      '/deep': (_) => const RecordingRoute('/deep'),
    },
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  return router;
}

FoldableRouter buildFlatRouter() {
  final router = FoldableRouter(
    initial: const HomeStub(),
    routes: const {},
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  return router;
}

Future<void> platformPushesUrl(WidgetTester tester, String location) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', <String, Object?>{
        'location': location,
        'state': null,
      }),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    seen.clear();
    gate = null;
    CountingChild.redirects = 0;
  });

  testWidgets('redirect gets the Router context on every way in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildShellRouter();
    await tester.pumpWidget(
      Marker(
        value: 42,
        child: MaterialApp.router(
          theme: ThemeData(brightness: Brightness.dark),
          routerConfig: router.routerConfig,
        ),
      ),
    );
    await tester.pumpAndSettle();

    void checkSince(int from) {
      expect(seen.length, greaterThan(from));
      for (var i = from; i < seen.length; i++) {
        final Seen s = seen[i];
        expect(s.marker, 42);
        expect(s.brightness, Brightness.dark);
        expect(s.size, const Size(1000, 700));
        expect(s.locale.languageCode, 'en');
        expect(identical(s.context, seen.first.context), isTrue);
      }
    }

    // 1. Launch: the redirects of the shell and of its first branch.
    checkSince(0);

    // 2. A tab switch re-checks the redirects of the shell and the branch.
    var from = seen.length;
    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    checkSince(from);

    // 3. open.
    from = seen.length;
    await router.open(const RecordingRoute('/o'));
    await tester.pumpAndSettle();
    checkSince(from);

    // 4. push.
    from = seen.length;
    final pushed = router.push<void>(const RecordingRoute('/p'));
    await tester.pumpAndSettle();
    checkSince(from);
    router.pop();
    await pushed;
    await tester.pumpAndSettle();

    // 5. openUri.
    from = seen.length;
    await router.openUri(Uri.parse('/u'));
    await tester.pumpAndSettle();
    checkSince(from);

    // 6. A URL from the platform.
    from = seen.length;
    await platformPushesUrl(tester, '/deep');
    checkSince(from);

    // 7. refresh.
    from = seen.length;
    await router.refresh();
    await tester.pumpAndSettle();
    checkSince(from);
  });

  group('edge cases', () {
    testWidgets('a deep link at launch sees the same Router context', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/deep';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );

      final router = buildShellRouter();
      await tester.pumpWidget(
        Marker(
          value: 42,
          child: MaterialApp.router(
            theme: ThemeData(brightness: Brightness.dark),
            routerConfig: router.routerConfig,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(seen, isNotEmpty);
      for (final Seen s in seen) {
        expect(s.marker, 42);
        expect(s.brightness, Brightness.dark);
        expect(s.size, const Size(1000, 700));
        expect(s.locale.languageCode, 'en');
        expect(identical(s.context, seen.first.context), isTrue);
      }
      expect(router.stack.last, const RecordingRoute('/deep'));
    });

    testWidgets('navigating before the router is mounted fails with '
        'StateError', (tester) async {
      final router = buildShellRouter();

      await expectLater(
        router.open(const RecordingRoute('/x')),
        throwsStateError,
      );
      await expectLater(
        router.push<void>(const RecordingRoute('/x')),
        throwsStateError,
      );
      await expectLater(router.openUri(Uri.parse('/u')), throwsStateError);
      await expectLater(router.refresh(), throwsStateError);

      expect(router.stack, isEmpty);
      expect(router.location, isNull);
      expect(seen, isEmpty);
      expect(router.isNavigating.value, isFalse);
    });

    testWidgets('a redirect resumed after the router is unmounted is '
        'dropped without calling the next redirect', (tester) async {
      gate = Completer<void>();
      final router = buildFlatRouter();
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.routerConfig),
      );
      await tester.pumpAndSettle();

      final before = router.stack;
      var completed = false;
      final future = router.open(const CountingChild()).then(
        (_) => completed = true,
      );
      await tester.pump();
      expect(router.isNavigating.value, isTrue);
      expect(completed, isFalse);

      // Remove the Router widget while the redirect is pending.
      await tester.pumpWidget(const SizedBox());
      gate!.complete();

      await expectLater(future, completes);
      expect(completed, isTrue);
      expect(router.stack, before);
      // The child's redirect was never called with the dead context.
      expect(CountingChild.redirects, 0);
    });
  });
}
