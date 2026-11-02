/// Query parameters of a deep link. Values are strings, read as a string, int,
/// double or bool; a key may be repeated (`?tag=a&tag=b`).
///
/// A key given once is read with [string], [integer], [decimal] and
/// [boolean]. A key that may be repeated is read with [strings], [integers],
/// [decimals] and [booleans], which keep the order of the URL. The single
/// getters are also fine on a repeated key: they read the **last** value, as
/// `Uri.queryParameters` does.
class RouteQuery {
  /// A query with one value per key.
  const RouteQuery(Map<String, String> values)
    : _values = values,
      _allValues = null;

  /// A query with any number of values per key, in order.
  const RouteQuery.all(Map<String, List<String>> values)
    : _values = null,
      _allValues = values;

  /// Reads the query parameters of [uri], repeated keys included.
  RouteQuery.fromUri(Uri uri)
    : _values = null,
      _allValues = uri.queryParametersAll;

  final Map<String, String>? _values;
  final Map<String, List<String>>? _allValues;

  // Plain integers only: an optional minus sign and ASCII digits. `int.parse`
  // would also accept `0x10`, and a leading `+` or spaces.
  static final RegExp _integerPattern = RegExp(r'^-?[0-9]+$');

  // Plain decimals: `1`, `-1.5`, `.5`, `1.`, `1e3`, `2.5E-3`. No sign `+`, no
  // spaces, no hex, and none of `NaN` or `Infinity` that `double.parse`
  // accepts.
  static final RegExp _decimalPattern = RegExp(
    r'^-?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$',
  );

  /// Every value of [name], in URL order. Empty when [name] is missing.
  List<String> strings(String name) {
    final all = _allValues;
    if (all != null) return all[name] ?? const [];
    final value = _values![name];
    return value == null ? const [] : [value];
  }

  /// The values of [name] that are ints (see [integer]), in URL order.
  /// Values that are not ints are skipped.
  List<int> integers(String name) => [
    for (final value in strings(name))
      if (_parseInteger(value) case final parsed?) parsed,
  ];

  /// The values of [name] that are doubles (see [decimal]), in URL order.
  /// Values that are not doubles are skipped.
  List<double> decimals(String name) => [
    for (final value in strings(name))
      if (_parseDecimal(value) case final parsed?) parsed,
  ];

  /// The values of [name] that are `true` or `false`, in URL order. Other
  /// values are skipped.
  List<bool> booleans(String name) => [
    for (final value in strings(name))
      if (_parseBoolean(value) case final parsed?) parsed,
  ];

  /// The raw value of [name], or null. When [name] is repeated, the last
  /// value; use [strings] for all of them.
  String? string(String name) {
    final all = _allValues;
    if (all == null) return _values![name];
    final list = all[name];
    return list == null || list.isEmpty ? null : list.last;
  }

  /// [name] as an int, or null when it is missing or not an int.
  ///
  /// Only plain decimal integers are accepted: digits with an optional leading
  /// `-` (`42`, `-7`, `007`). `0x10`, `+3`, ` 3`, `1.5` and `` give null.
  int? integer(String name) => _parseInteger(string(name));

  /// [name] as a double, or null when it is missing or not a finite double.
  ///
  /// Plain decimals and exponents are accepted (`1.5`, `-2`, `.5`, `1e3`).
  /// `NaN`, `Infinity`, `-Infinity`, hex, `+1`, spaces and values that
  /// overflow a double (`1e999`) give null.
  double? decimal(String name) => _parseDecimal(string(name));

  /// [name] as a bool, or null when it is missing or not `true`/`false`.
  bool? boolean(String name) => _parseBoolean(string(name));

  static int? _parseInteger(String? value) {
    if (value == null || !_integerPattern.hasMatch(value)) return null;
    return int.tryParse(value);
  }

  static double? _parseDecimal(String? value) {
    if (value == null || !_decimalPattern.hasMatch(value)) return null;
    final parsed = double.tryParse(value);
    return parsed == null || !parsed.isFinite ? null : parsed;
  }

  static bool? _parseBoolean(String? value) {
    return switch (value) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  /// Builds `path?key=value`. Null values are left out.
  ///
  /// A value may be an [Iterable] to repeat the key:
  /// `{'tag': ['a', 'b']}` gives `?tag=a&tag=b`. Null elements are skipped, and
  /// an iterable with no elements is left out like a null. Other values are
  /// written with `toString()`.
  static String build(String path, Map<String, Object?> params) {
    final query = <String, Object>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Iterable) {
        final items = [
          for (final item in value)
            if (item != null) '$item',
        ];
        if (items.isNotEmpty) query[entry.key] = items;
      } else {
        query[entry.key] = '$value';
      }
    }
    return Uri(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }
}
