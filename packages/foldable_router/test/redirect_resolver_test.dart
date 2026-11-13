import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_router/src/redirect_resolver.dart';

typedef Redirect =
    FutureOr<FoldableRoute?> Function(BuildContext context, RouteState state);

class R extends FoldableRoute {
  const R(this.path, {this.parent, this.onRedirect, this.id});

  @override
  final String path;
  @override
  final FoldableRoute? parent;
  final Redirect? onRedirect;
  final String? id;

  @override
  Map<String, Object?> get params => {'id': id};

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) =>
      onRedirect?.call(context, state);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Pumps the smallest tree that yields a mounted [BuildContext], which the
/// resolver now needs (as the router does) to call redirects.
Future<BuildContext> pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    Builder(
      builder: (BuildContext c) {
        context = c;
        return const SizedBox.shrink();
      },
    ),
  );
  return context;
}

void main() {
  group('FoldableRoute', () {
    test('uri is path plus non-null params', () {
      expect(const R('/a').uri.toString(), '/a');
      expect(const R('/a', id: '7').uri.toString(), '/a?id=7');
    });

    test('equality uses path and params', () {
      expect(const R('/a', id: '7'), R('/a', id: '7', onRedirect: (_, _) => null));
      expect(const R('/a', id: '7').hashCode, const R('/a', id: '7').hashCode);
      expect(const R('/a', id: '7'), isNot(const R('/a', id: '8')));
      expect(const R('/a'), isNot(const R('/b')));
    });
  });

  group('RedirectResolver', () {
    testWidgets('no redirect returns the parent chain, root first', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      const root = R('/root');
      const mid = R('/mid', parent: root);
      const leaf = R('/leaf', parent: mid);
      expect(await RedirectResolver().resolve(leaf, context: context), [
        root,
        mid,
        leaf,
      ]);
    });

    testWidgets('sync redirect', (tester) async {
      final context = await pumpContext(tester);
      const login = R('/login');
      final guarded = R('/guarded', onRedirect: (_, _) => login);
      expect(await RedirectResolver().resolve(guarded, context: context), [
        login,
      ]);
    });

    testWidgets('async redirect', (tester) async {
      final context = await pumpContext(tester);
      const login = R('/login');
      final guarded = R(
        '/guarded',
        onRedirect: (_, _) async {
          await Future<void>.value();
          return login;
        },
      );
      expect(await RedirectResolver().resolve(guarded, context: context), [
        login,
      ]);
    });

    testWidgets('parents are checked before children, sequentially', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final log = <String>[];
      Redirect logging(String name) => (_, state) async {
        log.add('$name start (target ${state.target.path})');
        await Future<void>.value();
        log.add('$name end');
        return null;
      };
      final root = R('/root', onRedirect: logging('root'));
      final mid = R('/mid', parent: root, onRedirect: logging('mid'));
      final leaf = R('/leaf', parent: mid, onRedirect: logging('leaf'));

      await RedirectResolver().resolve(leaf, context: context);

      expect(log, [
        'root start (target /leaf)',
        'root end',
        'mid start (target /leaf)',
        'mid end',
        'leaf start (target /leaf)',
        'leaf end',
      ]);
    });

    testWidgets('a redirecting parent stops the run before the child', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      const login = R('/login');
      var childChecked = false;
      final root = R('/root', onRedirect: (_, _) => login);
      final leaf = R(
        '/leaf',
        parent: root,
        onRedirect: (_, _) {
          childChecked = true;
          return null;
        },
      );
      expect(await RedirectResolver().resolve(leaf, context: context), [login]);
      expect(childChecked, isFalse);
    });

    testWidgets('redirect chain is followed and state describes the target', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final states = <RouteState>[];
      const cParent = R('/c-parent');
      final c = R(
        '/c',
        parent: cParent,
        onRedirect: (_, s) {
          states.add(s);
          return null;
        },
      );
      final b = R('/b', onRedirect: (_, _) => c);
      final a = R('/a', id: '1', onRedirect: (_, _) => b);

      expect(await RedirectResolver().resolve(a, context: context), [
        cParent,
        c,
      ]);
      expect(states.single.route, c);
      expect(states.single.target, c);
      expect(states.single.uri, Uri.parse('/c'));
    });

    testWidgets('loop is detected', (tester) async {
      final context = await pumpContext(tester);
      late final R a;
      final b = R('/b', onRedirect: (_, _) => a);
      a = R('/a', onRedirect: (_, _) => b);

      await expectLater(
        RedirectResolver().resolve(a, context: context),
        throwsA(
          isA<RedirectLoopException>().having(
            (e) => e.trail.map((r) => r.path),
            'trail',
            ['/a', '/b', '/a'],
          ),
        ),
      );
    });

    testWidgets('max redirects exceeded', (tester) async {
      final context = await pumpContext(tester);
      R numbered(int n) =>
          R('/n', id: '$n', onRedirect: (_, _) => numbered(n + 1));

      await expectLater(
        RedirectResolver(maxRedirects: 3).resolve(numbered(0), context: context),
        throwsA(
          isA<RedirectLimitException>()
              .having((e) => e.maxRedirects, 'maxRedirects', 3)
              .having((e) => e.trail.length, 'trail length', 5),
        ),
      );
    });

    testWidgets('exactly maxRedirects redirects are allowed', (tester) async {
      final context = await pumpContext(tester);
      R numbered(int n) => R(
        '/n',
        id: '$n',
        onRedirect: (_, _) => n < 3 ? numbered(n + 1) : null,
      );

      final chain = await RedirectResolver(
        maxRedirects: 3,
      ).resolve(numbered(0), context: context);
      expect(chain!.single.params['id'], '3');
    });

    testWidgets('a throwing redirect fails the navigation', (tester) async {
      final context = await pumpContext(tester);
      final sync = R(
        '/sync',
        onRedirect: (_, _) => throw StateError('sync'),
      );
      final async = R(
        '/async',
        onRedirect: (_, _) async => throw StateError('async'),
      );

      await expectLater(
        RedirectResolver().resolve(sync, context: context),
        throwsStateError,
      );
      await expectLater(
        RedirectResolver().resolve(async, context: context),
        throwsStateError,
      );
    });

    testWidgets('a newer navigation supersedes an older pending one', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final gate = Completer<FoldableRoute?>();
      final slow = R('/slow', onRedirect: (_, _) => gate.future);
      const fast = R('/fast');
      final resolver = RedirectResolver();

      final older = resolver.resolve(slow, context: context);
      final newer = resolver.resolve(fast, context: context);
      expect(await newer, [fast]);

      gate.complete(const R('/elsewhere'));
      expect(await older, isNull);
    });

    testWidgets('a superseded navigation swallows its redirect error', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final gate = Completer<FoldableRoute?>();
      final slow = R('/slow', onRedirect: (_, _) => gate.future);
      final resolver = RedirectResolver();

      final older = resolver.resolve(slow, context: context);
      await resolver.resolve(const R('/fast'), context: context);
      gate.completeError(StateError('late'));
      expect(await older, isNull);
    });
  });
}
