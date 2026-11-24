import 'package:flutter/services.dart';

import 'foldable_platform_state.dart';

/// Where [FoldablePlatformScope] gets the platform state from.
///
/// [ChannelFoldablePlatformSource] is the real one, talking to the iOS plugin.
/// A test or an app with another way of knowing implements this interface and
/// gives it to the scope.
abstract interface class FoldablePlatformSource {
  /// The state now. Never throws: without an answer, it is
  /// [FoldablePlatformState.empty].
  Future<FoldablePlatformState> getState();

  /// A new state each time the data changes. Listening starts whatever the
  /// platform does to watch (on iOS, a light timer that is stopped when the
  /// last listener cancels).
  Stream<FoldablePlatformState> get stateChanges;
}

/// The [FoldablePlatformSource] of the iOS plugin, over a [MethodChannel] and an
/// [EventChannel].
///
/// The protocol, version 1:
///
/// * The method `getState` returns a map, and the event channel sends the same
///   map each time something changes.
/// * The map has `version` (1), `width` and `height` (the Flutter view, in
///   points), `divisions` and `occlusions` (lists of regions) and
///   `verticalBarEdge` (`"leading"`, `"trailing"` or `"unspecified"`). A region
///   is a map with `left`, `top`, `right`, `bottom` (its frame in the view, in
///   points), `isActive` and `margins` (a map with `left`, `top`, `right`,
///   `bottom`).
///
/// A platform without the plugin, or a plugin that fails, gives
/// [FoldablePlatformState.empty]: no exception reaches the caller.
class ChannelFoldablePlatformSource implements FoldablePlatformSource {
  /// Talks to the channels of the plugin, or to [methodChannel] and
  /// [eventChannel] (for tests).
  ChannelFoldablePlatformSource({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _method = methodChannel ?? const MethodChannel(methodChannelName),
       _events = eventChannel ?? const EventChannel(eventChannelName);

  /// The name of the method channel: `foldable_scaffold/platform`.
  static const String methodChannelName = 'foldable_scaffold/platform';

  /// The name of the event channel: `foldable_scaffold/platform/events`.
  static const String eventChannelName = 'foldable_scaffold/platform/events';

  final MethodChannel _method;
  final EventChannel _events;

  @override
  Future<FoldablePlatformState> getState() async {
    try {
      final data = await _method.invokeMethod<Object?>('getState');
      return FoldablePlatformState.fromMap(data);
    } on PlatformException {
      return FoldablePlatformState.empty;
    } on MissingPluginException {
      return FoldablePlatformState.empty;
    }
  }

  @override
  late final Stream<FoldablePlatformState> stateChanges = _events
      .receiveBroadcastStream()
      .map(FoldablePlatformState.fromMap)
      // A platform without the plugin fails when listened to: no events.
      .handleError((Object _) {});
}
