import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

class _HomeRoute extends FoldableRoute {
  const _HomeRoute();

  @override
  String get path => '/home';

  @override
  Widget build(BuildContext context) => const Text('home');
}

class _SecondRoute extends FoldableRoute {
  const _SecondRoute();

  @override
  String get path => '/second';

  @override
  Widget build(BuildContext context) => const Text('second');
}

class _DetailRoute extends FoldableRoute {
  const _DetailRoute({this.id});

  final String? id;

  @override
  String get path => '/detail';

  @override
  Map<String, Object?> get query => {'id': id};

  @override
  Widget build(BuildContext context) => Text('detail ${id ?? ''}');
}

class _NotFoundRoute extends FoldableRoute {
  const _NotFoundRoute(this.uri);

  final Uri uri;

  @override
  String get path => uri.path;

  @override
  String get location => uri.toString();

  @override
  Widget build(BuildContext context) => const Text('not found');
}

FoldableRoute? _match(Uri uri) {
  return switch (uri.path) {
    '/home' => const _HomeRoute(),
    '/second' => const _SecondRoute(),
    '/detail' => _DetailRoute(id: RouteQuery.fromUri(uri).string('id')),
    _ => null,
  };
}

class _Recorder extends FoldableRouterObserver {
  final events = <FoldableNavigationEvent>[];

  List<FoldableNavigationKind> get kinds => [
    for (final event in events) event.kind,
  ];

  @override
  void onNavigation(FoldableNavigationEvent event) => events.add(event);
}

FoldableRouter _router(_Recorder recorder, {FoldableRedirect? redirect}) {
  return FoldableRouter.branches(
    branches: const [_HomeRoute(), _SecondRoute()],
    config: FoldableRouterConfig(
      matcher: _match,
      notFound: _NotFoundRoute.new,
      redirect: redirect,
      backTarget: (router) =>
          router.currentIndex == 0 ? null : const _HomeRoute(),
      observers: [recorder],
    ),
  );
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return context;
}

void main() {
  group('FoldableRouter observers', () {
    testWidgets('push, open and back each emit one event', (tester) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.open(context, const _SecondRoute());
      expect(recorder.kinds, [FoldableNavigationKind.open]);

      router.push<void>(const _DetailRoute(id: '7'));
      expect(recorder.kinds, [
        FoldableNavigationKind.open,
        FoldableNavigationKind.push,
      ]);
      expect(recorder.events.last.route, isA<_DetailRoute>());
      expect(recorder.events.last.uri.toString(), '/detail?id=7');
      expect(recorder.events.last.depth, 2);

      router.back();
      expect(recorder.kinds, [
        FoldableNavigationKind.open,
        FoldableNavigationKind.push,
        FoldableNavigationKind.pop,
      ]);
      expect(recorder.events.last.uri.toString(), '/second');
      expect(recorder.events.last.depth, 1);
    });

    testWidgets('pushAndRemoveUntil emits one push', (tester) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.push<void>(const _DetailRoute(id: '1'));
      router.push<void>(const _DetailRoute(id: '2'));
      recorder.events.clear();

      router.pushAndRemoveUntil<void>(
        const _DetailRoute(id: '3'),
        (page) => page == router.pages.first,
      );

      expect(recorder.kinds, [FoldableNavigationKind.push]);
      expect(recorder.events.single.depth, 2);
      expect(recorder.events.single.uri.toString(), '/detail?id=3');
    });

    testWidgets('pushAndReplace emits one push without growing the stack', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.push<void>(const _DetailRoute(id: '1'));
      recorder.events.clear();

      router.pushAndReplace<void>(const _DetailRoute(id: '2'));

      expect(recorder.kinds, [FoldableNavigationKind.push]);
      expect(recorder.events.single.depth, 2);
      expect(recorder.events.single.uri.toString(), '/detail?id=2');
    });

    testWidgets('openUri emits one open, or one pop when it returns', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.openUri(Uri.parse('/detail?id=1'));
      expect(recorder.kinds, [FoldableNavigationKind.open]);
      expect(recorder.events.single.uri.toString(), '/detail?id=1');

      // The URL of the page below: the browser went back.
      router.openUri(Uri.parse('/home'));
      expect(recorder.kinds, [
        FoldableNavigationKind.open,
        FoldableNavigationKind.pop,
      ]);
      expect(recorder.events.last.uri.toString(), '/home');
    });

    testWidgets('opening a tab root emits a single open', (tester) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.push<void>(const _DetailRoute(id: '7'));
      recorder.events.clear();

      router.open(context, const _SecondRoute());

      expect(recorder.kinds, [FoldableNavigationKind.open]);
      expect(recorder.events.single.branch, 1);
      expect(recorder.events.single.depth, 1);
      expect(recorder.events.single.uri.toString(), '/second');
      expect(recorder.events.single.route, isA<_SecondRoute>());
    });

    testWidgets('a pop through the controller emits one pop', (tester) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.push<void>(const _DetailRoute(id: '7'));
      recorder.events.clear();

      expect(router.controller.pop(), isTrue);

      expect(recorder.kinds, [FoldableNavigationKind.pop]);
      expect(recorder.events.single.route, isNull);
      expect(recorder.events.single.uri.toString(), '/home');
      expect(recorder.events.single.depth, 1);
      expect(recorder.events.single.branch, 0);

      // Nothing left to pop: nothing to report.
      expect(router.controller.pop(), isFalse);
      expect(recorder.events, hasLength(1));
    });

    testWidgets('popPage, popUntil and popToRoot emit one pop each', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      for (final id in ['1', '2', '3', '4', '5']) {
        router.push<void>(_DetailRoute(id: id));
      }
      recorder.events.clear();

      router.controller.popPage(router.pages[4]);
      expect(recorder.kinds, [FoldableNavigationKind.pop]);
      expect(recorder.events.last.depth, 4);

      router.controller.popUntil((page) => page == router.pages[2]);
      expect(recorder.kinds, hasLength(2));
      expect(recorder.events.last.depth, 3);

      router.controller.popToRoot();
      expect(recorder.kinds, everyElement(FoldableNavigationKind.pop));
      expect(recorder.kinds, hasLength(3));
      expect(recorder.events.last.depth, 1);

      // Already at the root: nothing changed, nothing reported.
      router.controller.popToRoot();
      expect(recorder.events, hasLength(3));
    });

    testWidgets('openBranch through the controller emits one branch', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.controller.openBranch(1);

      expect(recorder.kinds, [FoldableNavigationKind.branch]);
      expect(recorder.events.single.branch, 1);
      expect(recorder.events.single.uri.toString(), '/second');
      expect(recorder.events.single.route, isNull);

      // The same branch again changes nothing.
      router.controller.openBranch(1);
      expect(recorder.events, hasLength(1));

      router.controller.openBranch(0);
      expect(recorder.kinds, [
        FoldableNavigationKind.branch,
        FoldableNavigationKind.branch,
      ]);
      expect(recorder.events.last.branch, 0);
    });

    testWidgets('a change in a branch that is not on screen is silent', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.controller.push(
        const _DetailRoute(id: '1').toPage<void>(),
        branch: 1,
      );

      expect(recorder.events, isEmpty);
    });

    testWidgets('a controller batch emits one event', (tester) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.push<void>(const _DetailRoute(id: '1'));
      router.push<void>(const _DetailRoute(id: '2'));
      recorder.events.clear();

      router.controller.batch(() {
        router.controller.popToRoot();
        router.controller.openBranch(1);
      });

      expect(recorder.kinds, [FoldableNavigationKind.branch]);
      expect(recorder.events.single.branch, 1);
    });

    testWidgets('a pop and a router push in one batch emit both once', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(recorder)..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.push<void>(const _DetailRoute(id: '1'));
      recorder.events.clear();

      router.batch(() {
        router.controller.pop();
        router.push<void>(const _DetailRoute(id: '2'));
      });

      expect(recorder.kinds, [
        FoldableNavigationKind.pop,
        FoldableNavigationKind.push,
      ]);
    });

    testWidgets('an observer added later hears the controller too', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final router = _router(_Recorder())..rootContextOf = () => context;
      addTearDown(router.dispose);
      final extra = _Recorder();

      router.addObserver(extra);
      router.controller.openBranch(1);
      router.removeObserver(extra);
      router.controller.openBranch(0);

      expect(extra.kinds, [FoldableNavigationKind.branch]);
    });
  });

  group('FoldableRouter redirect errors', () {
    testWidgets('a throwing redirect is reported and abandons the navigation', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(
        recorder,
        redirect: (context, state) {
          if (state.route is _DetailRoute) throw StateError('sync boom');
          return null;
        },
      )..rootContextOf = () => context;
      addTearDown(router.dispose);

      // Does not throw out of open.
      router.open(context, const _DetailRoute(id: '1'));

      expect(tester.takeException(), isA<StateError>());
      expect(router.pages, hasLength(1));
      expect(router.currentUri.toString(), '/home');
      expect(recorder.events, isEmpty);

      // Later navigations still work.
      router.open(context, const _SecondRoute());
      expect(tester.takeException(), isNull);
      expect(router.currentIndex, 1);
      expect(recorder.kinds, [FoldableNavigationKind.open]);
    });

    testWidgets('an async redirect that fails is reported and abandons the '
        'navigation', (tester) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(
        recorder,
        redirect: (context, state) {
          if (state.route is _DetailRoute) {
            return Future<FoldableRoute?>.error(StateError('async boom'));
          }
          return null;
        },
      )..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.open(context, const _DetailRoute(id: '1'));
      await tester.pump();

      expect(tester.takeException(), isA<StateError>());
      expect(router.pages, hasLength(1));
      expect(router.currentUri.toString(), '/home');
      expect(recorder.events, isEmpty);

      router.open(context, const _SecondRoute());
      expect(tester.takeException(), isNull);
      expect(router.currentIndex, 1);
      expect(recorder.kinds, [FoldableNavigationKind.open]);
    });

    testWidgets('an async redirect that throws later is reported', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final recorder = _Recorder();
      final router = _router(
        recorder,
        redirect: (context, state) async {
          if (state.route is! _DetailRoute) return null;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw StateError('late boom');
        },
      )..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.open(context, const _DetailRoute(id: '1'));
      await tester.pump(const Duration(milliseconds: 20));

      expect(tester.takeException(), isA<StateError>());
      expect(router.pages, hasLength(1));
      expect(recorder.events, isEmpty);

      router.open(context, const _SecondRoute());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(router.currentIndex, 1);
      expect(recorder.kinds, [FoldableNavigationKind.open]);
    });

    testWidgets('resolve still throws to its direct caller', (tester) async {
      final context = await _pumpContext(tester);
      final router = _router(
        _Recorder(),
        redirect: (context, state) => throw StateError('boom'),
      );
      addTearDown(router.dispose);

      expect(
        () => router.resolve(const _DetailRoute(), context: context),
        throwsStateError,
      );
    });
  });
}
