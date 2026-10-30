// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
class FoldablePath {
  const FoldablePath(this.pattern);

  /// The pattern, e.g. `/record/:id`.
  final String pattern;

  /// The parameters of [uri], or null when [uri] does not match [pattern].
  ///
  /// Path segments are read with the same names as in the pattern.
  RouteQuery? match(Uri uri) {
    final patternSegments = _segments(pattern);
    final uriSegments = _segments(uri.path);
    if (patternSegments.length != uriSegments.length) return null;

    final values = <String, String>{...uri.queryParameters};
    for (var index = 0; index < patternSegments.length; index++) {
      final expected = patternSegments[index];
      final actual = uriSegments[index];
      if (expected.startsWith(':')) {
        if (actual.isEmpty) return null;
        values[expected.substring(1)] = actual;
      } else if (expected != actual) {
        return null;
      }
    }
    return RouteQuery(values);
  }

  static List<String> _segments(String path) {
    final value = path.isEmpty ? '/' : path;
    return [
      for (final segment in value.split('/'))
        if (segment.isNotEmpty) segment,
    ];
  }
}
