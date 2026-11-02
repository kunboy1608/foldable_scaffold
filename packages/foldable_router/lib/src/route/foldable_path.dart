import 'route_query.dart';

/// A path pattern like `/record/:id`, for `FoldableRouterConfig.matcher`.
///
/// ```dart
/// const record = FoldablePath('/record/:id');
///
/// FoldableRoute? match(Uri uri) {
///   final query = record.match(uri);
///   return query == null ? null : RecordRoute(id: query.string('id'));
/// }
/// ```
///
/// `:name` segments match one path segment each; every other segment must be
/// equal. Query parameters are merged into the result, so a pattern can read
/// both `/record/3` and `/record/3?tab=notes`.
///
/// A last segment `*name` is a wildcard: it matches **one or more** remaining
/// segments and captures them under `name`, joined with `/` (each segment
/// percent-decoded first). `/files/*rest` matches `/files/a/b` with
/// `rest == 'a/b'`, but not `/files` or `/files/`. A wildcard is only allowed
/// as the last segment, and needs a name; `match` asserts otherwise. Empty
/// path segments are ignored, so `/files/a//b` gives `a/b`.
class FoldablePath {
  const FoldablePath(this.pattern);

  /// The pattern, e.g. `/record/:id`.
  final String pattern;

  /// The parameters of [uri], or null when [uri] does not match [pattern].
  ///
  /// Path segments are read with the same names as in the pattern, and are
  /// percent-decoded.
  RouteQuery? match(Uri uri) {
    final patternSegments = _segments(pattern);
    // `pathSegments` is already percent-decoded: `/record/a%20b` gives `a b`.
    final uriSegments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    final lastIndex = patternSegments.length - 1;
    for (var index = 0; index < patternSegments.length; index++) {
      assert(
        !patternSegments[index].startsWith('*') ||
            (index == lastIndex && patternSegments[index].length > 1),
        'FoldablePath "$pattern": a wildcard must be the last segment and '
        'have a name, like "/files/*rest".',
      );
    }
    final hasWildcard =
        patternSegments.isNotEmpty && patternSegments.last.startsWith('*');
    final fixedCount = hasWildcard ? lastIndex : patternSegments.length;
    if (hasWildcard
        ? uriSegments.length <= fixedCount
        : uriSegments.length != fixedCount) {
      return null;
    }

    // Repeated query keys are kept; a path parameter replaces a query key of
    // the same name.
    final values = <String, List<String>>{...uri.queryParametersAll};
    for (var index = 0; index < fixedCount; index++) {
      final expected = patternSegments[index];
      final actual = uriSegments[index];
      if (expected.startsWith(':')) {
        if (actual.isEmpty) return null;
        values[expected.substring(1)] = [actual];
      } else if (expected != actual) {
        return null;
      }
    }
    if (hasWildcard) {
      values[patternSegments.last.substring(1)] = [
        uriSegments.sublist(fixedCount).join('/'),
      ];
    }
    return RouteQuery.all(values);
  }

  static List<String> _segments(String path) {
    final value = path.isEmpty ? '/' : path;
    return [
      for (final segment in value.split('/'))
        if (segment.isNotEmpty) segment,
    ];
  }
}
