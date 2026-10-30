// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

FoldableRouter _router() {
  return FoldableRouter(
    config: FoldableRouterConfig(
      roots: const [_HomeRoute(), _SecondRoute()],
      matcher: _match,
      notFound: _NotFoundRoute.new,
      backTarget: (router) =>
          router.currentIndex == 0 ? null : const _HomeRoute(),
    ),
  );
}

void main() {
  group('FoldablePath', () {
    test('reads path segments and query parameters', () {
      const path = FoldablePath('/record/:id');

      expect(path.match(Uri.parse('/record/42'))?.string('id'), '42');
      expect(
        path.match(Uri.parse('/record/42?tab=notes'))?.string('tab'),
        'notes',
      );
      expect(path.match(Uri.parse('/record/42/')), isNotNull);
      expect(path.match(Uri.parse('/record')), isNull);
      expect(path.match(Uri.parse('/other/42')), isNull);
      expect(path.match(Uri.parse('/record/42/extra')), isNull);
    });

    test('matches a root path', () {
      expect(const FoldablePath('/').match(Uri.parse('/')), isNotNull);
      expect(const FoldablePath('/').match(Uri.parse('/home')), isNull);
    });
  });

  group('FoldableRouter', () {
    testWidgets('going to a branch root switches branch', (tester) async {
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
      final router = _router();
      addTearDown(router.dispose);

      router.go(context, const _SecondRoute());

      expect(router.currentIndex, 1);
      expect(router.canPop, isFalse);
      expect(router.currentUri.toString(), '/second');
      expect(router.backGoesToRoot, isTrue);
    });

    testWidgets('pushing keeps the branch and names the page URL', (
      tester,
    ) async {
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
      final router = _router()..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.go(context, const _SecondRoute());
      router.push<void>(const _DetailRoute(id: '7'));

      expect(router.currentIndex, 1);
      expect(router.pages, hasLength(2));
      expect(router.currentUri.toString(), '/detail?id=7');
      expect(router.canPop, isTrue);
      expect(router.backGoesToRoot, isFalse);
    });

    testWidgets('back pops, then shows the back target', (tester) async {
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
      final router = _router()..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.go(context, const _SecondRoute());
      router.push<void>(const _DetailRoute(id: '7'));
      router.back();
      expect(router.currentIndex, 1);
      expect(router.pages, hasLength(1));

      router.back();
      expect(router.currentIndex, 0);
      expect(router.currentUri.toString(), '/home');
    });

    testWidgets('an unknown URL keeps its address and shows not found', (
      tester,
    ) async {
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
      final router = _router()..rootContextOf = () => context;
      addTearDown(router.dispose);

      router.goUri(Uri.parse('/nothing?a=1'));

      expect(router.pages, hasLength(2));
      expect(router.currentUri.toString(), '/nothing?a=1');
    });

    testWidgets('resolve follows redirects', (tester) async {
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
      final router = FoldableRouter(
        config: FoldableRouterConfig(
          roots: const [_HomeRoute()],
          matcher: _match,
          notFound: _NotFoundRoute.new,
          redirect: (context, state) =>
              state.route is _DetailRoute ? const _HomeRoute() : null,
        ),
      );
      addTearDown(router.dispose);

      expect(
        router.resolve(const _DetailRoute(), context: context),
        isA<_HomeRoute>(),
      );
    });
  });
}
