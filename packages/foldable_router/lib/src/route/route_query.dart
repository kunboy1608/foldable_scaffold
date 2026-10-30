/// Query parameters of a deep link. Only primitive values are supported:
/// string, int, double and bool.
class RouteQuery {
  const RouteQuery(this._values);

  /// Reads the query parameters of [uri].
  RouteQuery.fromUri(Uri uri) : _values = uri.queryParameters;

  final Map<String, String> _values;

  /// The raw value of [name], or null.
  String? string(String name) => _values[name];

  /// [name] as an int, or null when it is missing or not an int.
  int? integer(String name) => int.tryParse(_values[name] ?? '');

  /// [name] as a double, or null when it is missing or not a double.
  double? decimal(String name) => double.tryParse(_values[name] ?? '');

  /// [name] as a bool, or null when it is missing or not `true`/`false`.
  bool? boolean(String name) {
    return switch (_values[name]) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  /// Builds `path?key=value`. Null values are left out.
  static String build(String path, Map<String, Object?> params) {
    final query = <String, String>{
      for (final entry in params.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    return Uri(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }
}
