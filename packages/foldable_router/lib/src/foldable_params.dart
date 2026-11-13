import 'package:flutter/foundation.dart';

/// The raw query parameters of a URL, handed to a
/// [FoldableRouteFactory] so it can build a route.
///
/// Values are the decoded query-string values, so they are always strings;
/// the typed getters parse them:
///
/// ```dart
/// '/users/detail': (params) => UserRoute(
///   id: params.getInt('id'),
///   showPosts: params.getBoolOrNull('posts') ?? false,
/// ),
/// ```
///
/// A getter throws a [FormatException] — naming the key and its value — when
/// a required parameter is missing or cannot be parsed. The `OrNull` getters
/// return `null` only when the parameter is absent; a parameter that is
/// present but malformed still throws, so a broken URL never silently becomes
/// "no parameter".
@immutable
class FoldableParams {
  /// Wraps [values]. The map is copied and cannot be modified afterwards.
  FoldableParams(Map<String, String> values)
    : values = Map<String, String>.unmodifiable(values);

  /// The raw query parameters, unmodifiable.
  final Map<String, String> values;

  /// The raw value of [key], or `null` when the URL has no such parameter.
  ///
  /// Kept as the raw string so factories written for an earlier version
  /// (`params['id']!`) keep working.
  String? operator [](String key) => values[key];

  /// Whether the URL has a parameter named [key].
  bool contains(String key) => values.containsKey(key);

  /// The raw value of [key], which must be present.
  String getString(String key) => _required(key);

  /// The value of [key] parsed as an [int], or `null` when it is absent.
  ///
  /// Accepts what [int.tryParse] accepts (`"42"`, `"-42"`); `"1.5"` is
  /// rejected.
  int? getIntOrNull(String key) {
    final value = values[key];
    if (value == null) return null;
    final parsed = int.tryParse(value);
    if (parsed == null) _invalid(key, value, 'an integer');
    return parsed;
  }

  /// The value of [key] parsed as an [int], which must be present.
  int getInt(String key) {
    final value = _required(key);
    final parsed = int.tryParse(value);
    if (parsed == null) _invalid(key, value, 'an integer');
    return parsed;
  }

  /// The value of [key] parsed as a finite [double], or `null` when it is
  /// absent.
  ///
  /// Accepts `"42"` as well as `"1.5"`; `"NaN"` and the infinities are
  /// rejected, since a route cannot be written back to a URL with them.
  double? getDoubleOrNull(String key) {
    final value = values[key];
    if (value == null) return null;
    return _double(key, value);
  }

  /// The value of [key] parsed as a finite [double], which must be present.
  double getDouble(String key) => _double(key, _required(key));

  /// The value of [key] parsed as a [bool], or `null` when it is absent.
  ///
  /// Only the exact strings `"true"` and `"false"` are accepted.
  bool? getBoolOrNull(String key) {
    final value = values[key];
    if (value == null) return null;
    return _bool(key, value);
  }

  /// The value of [key] parsed as a [bool], which must be present.
  bool getBool(String key) => _bool(key, _required(key));

  /// The value of [key] parsed as an ISO 8601 date-time in UTC, or `null`
  /// when it is absent.
  ///
  /// The result is always in UTC ([DateTime.isUtc] is `true`), whatever the
  /// offset written in the URL.
  DateTime? getDateTimeOrNull(String key) {
    final value = values[key];
    if (value == null) return null;
    return _dateTime(key, value);
  }

  /// The value of [key] parsed as an ISO 8601 date-time in UTC, which must be
  /// present.
  DateTime getDateTime(String key) => _dateTime(key, _required(key));

  /// The raw value of [key], or `null` when it is absent.
  String? getStringOrNull(String key) => values[key];

  String _required(String key) {
    final value = values[key];
    if (value == null) {
      throw FormatException('Missing required parameter "$key".', key);
    }
    return value;
  }

  double _double(String key, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) {
      _invalid(key, value, 'a finite double');
    }
    return parsed;
  }

  bool _bool(String key, String value) {
    if (value == 'true') return true;
    if (value == 'false') return false;
    _invalid(key, value, '"true" or "false"');
  }

  DateTime _dateTime(String key, String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) _invalid(key, value, 'an ISO 8601 date-time');
    return parsed.toUtc();
  }

  Never _invalid(String key, String value, String expected) {
    throw FormatException(
      'Parameter "$key" has the value "$value", which is not $expected.',
      value,
    );
  }

  @override
  String toString() => 'FoldableParams($values)';
}
