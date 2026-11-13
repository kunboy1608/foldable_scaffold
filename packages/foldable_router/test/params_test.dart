import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

/// A route whose parameter map is set directly, used to test the URL encoding.
class RawRoute extends FoldableRoute {
  const RawRoute(this.values, {this.path = '/raw'});

  final Map<String, Object?> values;

  @override
  final String path;

  @override
  Map<String, Object?> get params => values;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A route holding one value of each supported type.
class AllTypesRoute extends FoldableRoute {
  const AllTypesRoute({
    required this.s,
    required this.i,
    required this.d,
    required this.b,
    required this.t,
  });

  final String s;
  final int i;
  final double d;
  final bool b;
  final DateTime t;

  @override
  String get path => '/all';

  @override
  Map<String, Object?> get params => {
    's': s,
    'i': i,
    'd': d,
    'b': b,
    't': t,
  };

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class HomeStub extends FoldableRoute {
  const HomeStub();

  @override
  String get path => '/';

  @override
  Widget build(BuildContext context) => const Text('home');
}

FoldableRouter buildRouter() {
  final router = FoldableRouter(
    initial: const HomeStub(),
    routes: {
      '/all': (params) => AllTypesRoute(
        s: params.getString('s'),
        i: params.getInt('i'),
        d: params.getDouble('d'),
        b: params.getBool('b'),
        t: params.getDateTime('t'),
      ),
    },
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  return router;
}

Future<FoldableRouter> pumpDeepLink(WidgetTester tester, String link) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = link;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
  final router = buildRouter();
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('writing params to the URL', () {
    test('encodes String, int, double and bool', () {
      const route = RawRoute({
        's': 'a b/c',
        'i': 42,
        'd': 1.5,
        'b': true,
        'f': false,
      });
      expect(route.uri.queryParameters, {
        's': 'a b/c',
        'i': '42',
        'd': '1.5',
        'b': 'true',
        'f': 'false',
      });
    });

    test('omits null values', () {
      const route = RawRoute({'a': null, 'b': 'x'});
      expect(route.uri.queryParameters, {'b': 'x'});
    });

    test('writes DateTime in UTC so the URL does not depend on the zone', () {
      final plusTwo = DateTime.parse('2020-01-01T10:00:00+02:00');
      expect(
        RawRoute({'t': plusTwo}).uri.queryParameters['t'],
        '2020-01-01T08:00:00.000Z',
      );
      expect(
        RawRoute({'t': DateTime.utc(2020, 1, 1)}).uri.queryParameters['t'],
        '2020-01-01T00:00:00.000Z',
      );
    });

    test('rejects a non-finite double in release too', () {
      for (final bad in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => RawRoute({'x': bad}).uri,
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'x')
                .having((e) => e.message.toString(), 'message', contains('double')),
          ),
        );
      }
    });

    test('rejects an unsupported type, naming key and type', () {
      expect(
        () => const RawRoute({
          'x': <int>[1, 2],
        }).uri,
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'x')
              .having(
                (e) => e.message.toString(),
                'message',
                contains('List<int>'),
              ),
        ),
      );
      expect(
        () => RawRoute({'y': Duration.zero}).uri,
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'y')
              .having(
                (e) => e.message.toString(),
                'message',
                contains('Duration'),
              ),
        ),
      );
    });

    test('equality compares the encoded query', () {
      // int 1 and String '1' both encode to "1".
      expect(const RawRoute({'id': 1}), const RawRoute({'id': '1'}));
      expect(
        const RawRoute({'id': 1}).hashCode,
        const RawRoute({'id': '1'}).hashCode,
      );

      // The same instant written in two time zones encodes to one string.
      final utc = DateTime.parse('2020-01-01T00:00:00Z');
      final plusTwo = DateTime.parse('2020-01-01T02:00:00+02:00');
      expect(RawRoute({'t': utc}), RawRoute({'t': plusTwo}));
      expect(RawRoute({'t': utc}).hashCode, RawRoute({'t': plusTwo}).hashCode);
    });
  });

  group('FoldableParams', () {
    final params = FoldableParams({
      's': 'hello',
      'i': '42',
      'd': '1.5',
      'b': 'true',
      't': '2020-01-01T10:00:00+02:00',
    });

    test('raw access keeps the string', () {
      expect(params['s'], 'hello');
      expect(params['missing'], isNull);
      expect(params.contains('s'), isTrue);
      expect(params.contains('missing'), isFalse);
      expect(params.values, {
        's': 'hello',
        'i': '42',
        'd': '1.5',
        'b': 'true',
        't': '2020-01-01T10:00:00+02:00',
      });
    });

    test('values is raw and cannot be modified', () {
      expect(() => params.values['x'] = 'y', throwsUnsupportedError);
    });

    test('typed getters', () {
      expect(params.getString('s'), 'hello');
      expect(params.getInt('i'), 42);
      expect(params.getDouble('d'), 1.5);
      expect(params.getBool('b'), isTrue);
      final t = params.getDateTime('t');
      expect(t.isUtc, isTrue);
      expect(t, DateTime.parse('2020-01-01T08:00:00Z'));
    });

    test('a required getter throws when the parameter is missing', () {
      final empty = FoldableParams(const {});
      expect(() => empty.getString('k'), throwsFormatException);
      expect(() => empty.getInt('k'), throwsFormatException);
      expect(() => empty.getDouble('k'), throwsFormatException);
      expect(() => empty.getBool('k'), throwsFormatException);
      expect(() => empty.getDateTime('k'), throwsFormatException);
    });

    test('an OrNull getter returns null only when the parameter is missing', () {
      final empty = FoldableParams(const {});
      expect(empty.getStringOrNull('k'), isNull);
      expect(empty.getIntOrNull('k'), isNull);
      expect(empty.getDoubleOrNull('k'), isNull);
      expect(empty.getBoolOrNull('k'), isNull);
      expect(empty.getDateTimeOrNull('k'), isNull);

      // Present but malformed still throws.
      expect(
        () => FoldableParams({'i': 'x'}).getIntOrNull('i'),
        throwsFormatException,
      );
      expect(
        () => FoldableParams({'d': 'x'}).getDoubleOrNull('d'),
        throwsFormatException,
      );
      expect(
        () => FoldableParams({'b': 'x'}).getBoolOrNull('b'),
        throwsFormatException,
      );
      expect(
        () => FoldableParams({'t': 'x'}).getDateTimeOrNull('t'),
        throwsFormatException,
      );
      // A String has no format to fail.
      expect(FoldableParams({'s': 'x'}).getStringOrNull('s'), 'x');
    });

    test('parsing rules', () {
      expect(FoldableParams({'d': '42'}).getDouble('d'), 42.0);
      expect(
        () => FoldableParams({'i': '1.5'}).getInt('i'),
        throwsFormatException,
      );
      expect(
        () => FoldableParams({'b': 'True'}).getBool('b'),
        throwsFormatException,
      );
      expect(
        () => FoldableParams({'b': '1'}).getBool('b'),
        throwsFormatException,
      );
      expect(
        () => FoldableParams({'t': 'nope'}).getDateTime('t'),
        throwsFormatException,
      );
      expect(
        () => FoldableParams({'d': 'NaN'}).getDouble('d'),
        throwsFormatException,
      );
    });

    test('FormatException names the key and the value', () {
      try {
        FoldableParams({'i': 'abc'}).getInt('i');
        fail('should have thrown');
      } on FormatException catch (error) {
        expect(error.message, contains('i'));
        expect(error.message, contains('abc'));
      }
      try {
        FoldableParams(const {}).getString('id');
        fail('should have thrown');
      } on FormatException catch (error) {
        expect(error.message, contains('id'));
      }
    });
  });

  group('round trip', () {
    test('every supported type survives route -> URI -> route', () {
      final router = buildRouter();
      final route = AllTypesRoute(
        s: 'a b/c?d',
        i: -42,
        d: 3.5,
        b: false,
        t: DateTime.parse('2021-05-06T07:08:09.123+05:30'),
      );

      final back = router.routeFor(route.uri) as AllTypesRoute;

      expect(back, route);
      expect(back.s, 'a b/c?d');
      expect(back.i, -42);
      expect(back.d, 3.5);
      expect(back.b, isFalse);
      expect(back.t.isUtc, isTrue);
      expect(back.t.isAtSameMomentAs(route.t), isTrue);
    });

    test('a deep link reads the same values', () {
      final router = buildRouter();
      final route = router.routeFor(
        Uri.parse('/all?s=hi&i=1&d=42&b=true&t=2020-01-01T00:00:00Z'),
      ) as AllTypesRoute;

      expect(route.s, 'hi');
      expect(route.i, 1);
      expect(route.d, 42.0);
      expect(route.b, isTrue);
      expect(route.t, DateTime.utc(2020, 1, 1));
    });
  });

  group('a malformed URL shows the not-found page', () {
    testWidgets('getInt rejects "1.5"', (tester) async {
      await pumpDeepLink(
        tester,
        '/all?s=x&i=1.5&d=1&b=true&t=2020-01-01T00:00:00Z',
      );
      expect(
        find.text('not found: /all?s=x&i=1.5&d=1&b=true&t=2020-01-01T00:00:00Z'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a missing required parameter', (tester) async {
      await pumpDeepLink(
        tester,
        '/all?s=x&d=1&b=true&t=2020-01-01T00:00:00Z',
      );
      expect(find.textContaining('not found: /all'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('getBool rejects anything but true/false', (tester) async {
      await pumpDeepLink(
        tester,
        '/all?s=x&i=1&d=1&b=yes&t=2020-01-01T00:00:00Z',
      );
      expect(find.textContaining('not found: /all'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('getDateTime rejects a non date-time', (tester) async {
      await pumpDeepLink(tester, '/all?s=x&i=1&d=1&b=true&t=nope');
      expect(find.textContaining('not found: /all'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
