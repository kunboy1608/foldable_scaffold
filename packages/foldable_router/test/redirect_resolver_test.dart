import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_router/src/redirect_resolver.dart';

typedef Redirect = FutureOr<FoldableRoute?> Function(RouteState state);

class R extends FoldableRoute {
  const R(this.path, {this.parent, this.onRedirect, this.id});

  @override
  final String path;
  @override
  final FoldableRoute? parent;
  final Redirect? onRedirect;
  final String? id;

  @override
  Map<String, String?> get params => {'id': id};

  @override
  FutureOr<FoldableRoute?> redirect(RouteState state) =>
      onRedirect?.call(state);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  group('FoldableRoute', () {
    test('uri is path plus non-null params', () {
      expect(const R('/a').uri.toString(), '/a');
      expect(const R('/a', id: '7').uri.toString(), '/a?id=7');
    });

    test('equality uses path and params', () {
      expect(const R('/a', id: '7'), R('/a', id: '7', onRedirect: (_) => null));
      expect(const R('/a', id: '7').hashCode, const R('/a', id: '7').hashCode);
      expect(const R('/a', id: '7'), isNot(const R('/a', id: '8')));
      expect(const R('/a'), isNot(const R('/b')));
    });
  });

  group('RedirectResolver', () {
    test('no redirect returns the parent chain, root first', () async {
      const root = R('/root');
      const mid = R('/mid', parent: root);
      const leaf = R('/leaf', parent: mid);
      expect(await RedirectResolver().resolve(leaf), [root, mid, leaf]);
    });

    test('sync redirect', () async {
      const login = R('/login');
      final guarded = R('/guarded', onRedirect: (_) => login);
      expect(await RedirectResolver().resolve(guarded), [login]);
    });

    test('async redirect', () async {
      const login = R('/login');
      final guarded = R(
        '/guarded',
        onRedirect: (_) async {
          await Future<void>.delayed(Duration.zero);
          return login;
        },
      );
      expect(await RedirectResolver().resolve(guarded), [login]);
    });

    test('parents are checked before children, sequentially', () async {
      final log = <String>[];
      Redirect logging(String name) => (state) async {
        log.add('$name start (target ${state.target.path})');
        await Future<void>.delayed(Duration.zero);
        log.add('$name end');
        return null;
      };
      final root = R('/root', onRedirect: logging('root'));
      final mid = R('/mid', parent: root, onRedirect: logging('mid'));
      final leaf = R('/leaf', parent: mid, onRedirect: logging('leaf'));

      await RedirectResolver().resolve(leaf);

      expect(log, [
        'root start (target /leaf)',
        'root end',
        'mid start (target /leaf)',
        'mid end',
        'leaf start (target /leaf)',
        'leaf end',
      ]);
    });

    test('a redirecting parent stops the run before the child', () async {
      const login = R('/login');
      var childChecked = false;
      final root = R('/root', onRedirect: (_) => login);
      final leaf = R(
        '/leaf',
        parent: root,
        onRedirect: (_) {
          childChecked = true;
          return null;
        },
      );
      expect(await RedirectResolver().resolve(leaf), [login]);
      expect(childChecked, isFalse);
    });

    test('redirect chain is followed and state describes the target', () async {
      final states = <RouteState>[];
      const cParent = R('/c-parent');
      final c = R(
        '/c',
        parent: cParent,
        onRedirect: (s) {
          states.add(s);
          return null;
        },
      );
      final b = R('/b', onRedirect: (_) => c);
      final a = R('/a', id: '1', onRedirect: (_) => b);

      expect(await RedirectResolver().resolve(a), [cParent, c]);
      expect(states.single.route, c);
      expect(states.single.target, c);
      expect(states.single.uri, Uri.parse('/c'));
    });

    test('loop is detected', () async {
      late final R a;
      final b = R('/b', onRedirect: (_) => a);
      a = R('/a', onRedirect: (_) => b);

      await expectLater(
        RedirectResolver().resolve(a),
        throwsA(
          isA<RedirectLoopException>().having(
            (e) => e.trail.map((r) => r.path),
            'trail',
            ['/a', '/b', '/a'],
          ),
        ),
      );
    });

    test('max redirects exceeded', () async {
      R numbered(int n) =>
          R('/n', id: '$n', onRedirect: (_) => numbered(n + 1));

      await expectLater(
        RedirectResolver(maxRedirects: 3).resolve(numbered(0)),
        throwsA(
          isA<RedirectLimitException>()
              .having((e) => e.maxRedirects, 'maxRedirects', 3)
              .having((e) => e.trail.length, 'trail length', 5),
        ),
      );
    });

    test('exactly maxRedirects redirects are allowed', () async {
      R numbered(int n) =>
          R('/n', id: '$n', onRedirect: (_) => n < 3 ? numbered(n + 1) : null);

      final chain = await RedirectResolver(
        maxRedirects: 3,
      ).resolve(numbered(0));
      expect(chain!.single.params['id'], '3');
    });

    test('a throwing redirect fails the navigation', () async {
      final sync = R('/sync', onRedirect: (_) => throw StateError('sync'));
      final async = R(
        '/async',
        onRedirect: (_) async => throw StateError('async'),
      );

      await expectLater(RedirectResolver().resolve(sync), throwsStateError);
      await expectLater(RedirectResolver().resolve(async), throwsStateError);
    });

    test('a newer navigation supersedes an older pending one', () async {
      final gate = Completer<FoldableRoute?>();
      final slow = R('/slow', onRedirect: (_) => gate.future);
      const fast = R('/fast');
      final resolver = RedirectResolver();

      final older = resolver.resolve(slow);
      final newer = resolver.resolve(fast);
      expect(await newer, [fast]);

      gate.complete(const R('/elsewhere'));
      expect(await older, isNull);
    });

    test('a superseded navigation swallows its redirect error', () async {
      final gate = Completer<FoldableRoute?>();
      final slow = R('/slow', onRedirect: (_) => gate.future);
      final resolver = RedirectResolver();

      final older = resolver.resolve(slow);
      await resolver.resolve(const R('/fast'));
      gate.completeError(StateError('late'));
      expect(await older, isNull);
    });
  });
}
