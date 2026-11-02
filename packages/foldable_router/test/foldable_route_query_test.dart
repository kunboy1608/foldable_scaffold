import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

void main() {
  group('RouteQuery repeated keys', () {
    final query = RouteQuery.fromUri(
      Uri.parse('/x?tag=b&tag=a&n=3&n=x&n=-1&n=3&on=true&on=no&on=false&one=1'),
    );

    test('strings keeps every value in URL order', () {
      expect(query.strings('tag'), ['b', 'a']);
      expect(query.strings('one'), ['1']);
      expect(query.strings('missing'), isEmpty);
    });

    test('string reads the last value, as Uri.queryParameters does', () {
      final uri = Uri.parse('/x?tag=b&tag=a&one=1&empty=');
      final read = RouteQuery.fromUri(uri);

      expect(read.string('tag'), 'a');
      for (final key in ['tag', 'one', 'empty', 'missing']) {
        expect(read.string(key), uri.queryParameters[key]);
      }
    });

    test('integers keeps order and skips values that are not ints', () {
      expect(query.integers('n'), [3, -1, 3]);
      expect(query.integers('missing'), isEmpty);
      expect(query.integer('n'), 3);
    });

    test('decimals and booleans skip what they cannot read', () {
      final read = RouteQuery.fromUri(Uri.parse('/x?d=1.5&d=NaN&d=2&d=1e3'));

      expect(read.decimals('d'), [1.5, 2.0, 1000.0]);
      expect(query.booleans('on'), [true, false]);
      expect(query.booleans('missing'), isEmpty);
    });

    test('the map constructor reads as one value per key', () {
      const direct = RouteQuery({'id': '7'});

      expect(direct.strings('id'), ['7']);
      expect(direct.integers('id'), [7]);
      expect(direct.strings('other'), isEmpty);
    });

    test('RouteQuery.all holds many values per key', () {
      const direct = RouteQuery.all({
        'tag': ['a', 'b'],
        'none': [],
      });

      expect(direct.strings('tag'), ['a', 'b']);
      expect(direct.string('tag'), 'b');
      expect(direct.string('none'), isNull);
      expect(direct.string('missing'), isNull);
    });

    test('an empty value is kept', () {
      final read = RouteQuery.fromUri(Uri.parse('/x?a=&a=1'));

      expect(read.strings('a'), ['', '1']);
      expect(read.integers('a'), [1]);
    });
  });

  group('RouteQuery.build with iterables', () {
    test('repeats the key', () {
      expect(
        RouteQuery.build('/p', {
          'tag': ['a', 'b'],
        }),
        '/p?tag=a&tag=b',
      );
    });

    test('skips null elements and writes other types', () {
      expect(
        RouteQuery.build('/p', {
          'n': [1, null, 2.5, true],
          'id': 3,
        }),
        '/p?n=1&n=2.5&n=true&id=3',
      );
    });

    test('leaves out empty iterables and iterables of nulls', () {
      expect(RouteQuery.build('/p', {'tag': <String>[], 'x': null}), '/p');
      expect(
        RouteQuery.build('/p', {
          'tag': [null, null],
          'id': 1,
        }),
        '/p?id=1',
      );
    });

    test('accepts any iterable', () {
      expect(
        RouteQuery.build('/p', {
          'n': {1, 2},
          'm': Iterable.generate(2),
        }),
        '/p?n=1&n=2&m=0&m=1',
      );
    });

    test('output reads back through strings', () {
      final location = RouteQuery.build('/p', {
        'tag': ['a b', 'c&d', 'é', ''],
      });
      final read = RouteQuery.fromUri(Uri.parse(location));

      expect(read.strings('tag'), ['a b', 'c&d', 'é', '']);
    });

    test('a plain string is a single value, not an iterable', () {
      expect(RouteQuery.build('/p', {'q': 'abc'}), '/p?q=abc');
    });
  });

  group('RouteQuery parsing', () {
    RouteQuery one(String value) => RouteQuery({'v': value});

    test('integer accepts plain decimal integers', () {
      expect(one('-4').integer('v'), -4);
      expect(one('42').integer('v'), 42);
      expect(one('0').integer('v'), 0);
      expect(one('007').integer('v'), 7);
    });

    test('integer rejects everything else', () {
      for (final value in [
        '0x10',
        '0X1F',
        '1.5',
        '',
        ' 3',
        '3 ',
        '+3',
        '--3',
        '-',
        '1e3',
        '1_000',
        'abc',
        '٣',
      ]) {
        expect(one(value).integer('v'), isNull, reason: 'value "$value"');
      }
    });

    test('decimal accepts decimals and exponents', () {
      expect(one('1e3').decimal('v'), 1000.0);
      expect(one('2.5E-3').decimal('v'), 0.0025);
      expect(one('.5').decimal('v'), 0.5);
      expect(one('-.5').decimal('v'), -0.5);
      expect(one('1.5').decimal('v'), 1.5);
      expect(one('42').decimal('v'), 42.0);
      expect(one('-7').decimal('v'), -7.0);
    });

    test('decimal rejects NaN, infinities and non numbers', () {
      for (final value in [
        'NaN',
        'Infinity',
        '-Infinity',
        'infinity',
        '1e999',
        '-1e999',
        '0x10',
        '+1.5',
        ' 1.5',
        '1.5 ',
        '',
        '.',
        'e3',
        '1e',
        'abc',
      ]) {
        expect(one(value).decimal('v'), isNull, reason: 'value "$value"');
      }
    });
  });

  group('FoldablePath wildcard', () {
    const files = FoldablePath('/files/*rest');

    test('captures the remaining segments joined with a slash', () {
      expect(files.match(Uri.parse('/files/a/b/c'))?.string('rest'), 'a/b/c');
      expect(files.match(Uri.parse('/files/a'))?.string('rest'), 'a');
      expect(files.match(Uri.parse('/files/a/b/'))?.string('rest'), 'a/b');
    });

    test('decodes each segment', () {
      expect(files.match(Uri.parse('/files/a%20b/c'))?.string('rest'), 'a b/c');
    });

    test('needs at least one segment', () {
      expect(files.match(Uri.parse('/files')), isNull);
      expect(files.match(Uri.parse('/files/')), isNull);
      expect(files.match(Uri.parse('/files//')), isNull);
    });

    test('static segments still have to match', () {
      expect(files.match(Uri.parse('/other/a/b')), isNull);
      expect(files.match(Uri.parse('/a')), isNull);
      expect(files.match(Uri.parse('/')), isNull);
    });

    test('merges query parameters, repeated ones included', () {
      final match = files.match(Uri.parse('/files/a/b?tab=1&tag=x&tag=y'));

      expect(match?.string('rest'), 'a/b');
      expect(match?.string('tab'), '1');
      expect(match?.strings('tag'), ['x', 'y']);
    });

    test('works after a named segment', () {
      const path = FoldablePath('/u/:id/files/*rest');
      final match = path.match(Uri.parse('/u/7/files/x/y'));

      expect(match?.integer('id'), 7);
      expect(match?.string('rest'), 'x/y');
      expect(path.match(Uri.parse('/u/7/files')), isNull);
    });

    test('a wildcard alone matches any non empty path', () {
      const path = FoldablePath('/*all');

      expect(path.match(Uri.parse('/a/b'))?.string('all'), 'a/b');
      expect(path.match(Uri.parse('/')), isNull);
    });

    test('a wildcard in the middle or without a name asserts', () {
      expect(
        () => const FoldablePath('/a/*x/b').match(Uri.parse('/a/1/b')),
        throwsAssertionError,
      );
      expect(
        () => const FoldablePath('/a/*').match(Uri.parse('/a/1')),
        throwsAssertionError,
      );
    });

    test('the path value wins over a query key of the same name', () {
      expect(files.match(Uri.parse('/files/a?rest=q'))?.strings('rest'), ['a']);
    });
  });

  group('FoldablePath without wildcard', () {
    test('behaves as before', () {
      const path = FoldablePath('/record/:id');

      expect(path.match(Uri.parse('/record/42'))?.string('id'), '42');
      expect(
        path.match(Uri.parse('/record/42?tab=notes'))?.string('tab'),
        'notes',
      );
      expect(path.match(Uri.parse('/record/a%20b'))?.string('id'), 'a b');
      expect(path.match(Uri.parse('/record/42/')), isNotNull);
      expect(path.match(Uri.parse('/record')), isNull);
      expect(path.match(Uri.parse('/record/42/extra')), isNull);
      expect(path.match(Uri.parse('/other/42')), isNull);
      expect(const FoldablePath('/').match(Uri.parse('/')), isNotNull);
      expect(const FoldablePath('/').match(Uri.parse('/home')), isNull);
    });

    test('a star inside a segment is literal text of a static segment', () {
      // Only a segment that starts with a star is a wildcard.
      expect(const FoldablePath('/a*b').match(Uri.parse('/a*b')), isNotNull);
    });

    test('reads repeated query keys', () {
      final match = const FoldablePath(
        '/record/:id',
      ).match(Uri.parse('/record/1?tag=a&tag=b'));

      expect(match?.strings('tag'), ['a', 'b']);
      expect(match?.string('tag'), 'b');
    });
  });
}
