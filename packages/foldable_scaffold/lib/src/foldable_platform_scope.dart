import 'dart:async';
import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'foldable_navigation.dart';
import 'foldable_platform_source.dart';
import 'foldable_platform_state.dart';

/// Brings what the platform knows about the display into Flutter: the fold, the
/// cameras and the side of the system's vertical bars.
///
/// On iPhone Duo the hinge, the cameras and the Dynamic Island are reserved
/// regions of the UIKit view, and the system says on which side it puts its
/// vertical bars (`verticalBarEdge`). Flutter puts none of it in `MediaQuery`,
/// so the iOS plugin of this package reads it and this widget gives it to the
/// tree:
///
/// * `MediaQuery.displayFeatures` gets the active reserved regions (see
///   [FoldablePlatformState.displayFeatures]), merged with the features the
///   engine already reported, without duplicates. The [FoldableScaffold]s below
///   then split at the fold, as they do on Android.
/// * A [FoldableVerticalBarScope] gets the edge of the vertical bars, so the
///   default navigation placement follows it.
/// * [FoldablePlatformScope.maybeOf] gives the whole [FoldablePlatformState].
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => FoldablePlatformScope(child: child!),
///   home: const MyHome(),
/// )
/// ```
///
/// **Where to put it.** Below the `WidgetsApp` (so in `MaterialApp.builder`,
/// `CupertinoApp.builder` or `WidgetsApp.builder`), where a `MediaQuery`
/// exists: `WidgetsApp` makes its own `MediaQuery` from the view, which would
/// replace one made above it. Without a `MediaQuery` above, the display
/// features are not provided, only the vertical bar edge. Anything in the
/// builder that rewrites `displayFeatures` (a fold simulator, say) goes below
/// this widget to win over the platform, or above it to be merged.
///
/// **Other platforms.** On every platform but iOS (and on the web, whatever the
/// browser), this widget returns [child] untouched: no `MediaQuery`, no scope,
/// no channel. [maybeOf] is null there.
///
/// **On iOS** the data comes from the plugin, which reads
/// `UIView.ReservedRegion` and `UITraitCollection.verticalBarEdge` (iOS 27.1).
/// Building the plugin needs an Xcode with that SDK; read the README of this
/// package. On an iOS older than 27.1 the state is
/// [FoldablePlatformState.empty]: no features, no vertical bar, the widget is
/// harmless.
///
/// The state is read when the widget starts, when the metrics of the window
/// change, and each time the plugin reports a change.
class FoldablePlatformScope extends StatefulWidget {
  /// Provides the platform state to [child] (on iOS).
  ///
  /// [source] replaces the plugin as the origin of the data (for tests, or
  /// another way of knowing); it is only used on iOS.
  const FoldablePlatformScope({super.key, this.source, required this.child});

  /// Where the state comes from. Null (the default) is the iOS plugin, a
  /// [ChannelFoldablePlatformSource].
  final FoldablePlatformSource? source;

  /// The tree that gets the features and the vertical bar edge.
  final Widget child;

  /// The platform state of the closest scope, or null when there is none (the
  /// platform is not iOS). Rebuilds the caller when the state changes.
  static FoldablePlatformState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_FoldablePlatformData>()
      ?.state;

  @override
  State<FoldablePlatformScope> createState() => _FoldablePlatformScopeState();
}

class _FoldablePlatformScopeState extends State<FoldablePlatformScope>
    with WidgetsBindingObserver {
  late final bool _active =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  FoldablePlatformSource? _source;
  StreamSubscription<FoldablePlatformState>? _subscription;
  FoldablePlatformState _state = FoldablePlatformState.empty;

  /// Counts the answers asked for and the events received: an answer that is
  /// not the latest is older than what is on screen, and is dropped.
  int _generation = 0;
  bool _reading = false;
  bool _readAgain = false;

  @override
  void initState() {
    super.initState();
    if (!_active) return;
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  @override
  void didUpdateWidget(FoldablePlatformScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_active && oldWidget.source != widget.source) {
      _disconnect();
      _connect();
    }
  }

  @override
  void dispose() {
    if (_active) {
      WidgetsBinding.instance.removeObserver(this);
      _disconnect();
    }
    super.dispose();
  }

  void _connect() {
    final source = widget.source ?? ChannelFoldablePlatformSource();
    _source = source;
    _subscription = source.stateChanges.listen(_accept, onError: (Object _) {});
    _read();
  }

  void _disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _source = null;
    _generation++;
  }

  /// A change reported by the platform.
  void _accept(FoldablePlatformState state) {
    _generation++;
    _apply(state);
  }

  void _apply(FoldablePlatformState state) {
    if (!mounted || state == _state) return;
    setState(() => _state = state);
  }

  /// Asks the platform for the state now. Calls that come while one is in
  /// flight are folded into one more.
  Future<void> _read() async {
    final source = _source;
    if (source == null) return;
    if (_reading) {
      _readAgain = true;
      return;
    }
    _reading = true;
    try {
      final generation = ++_generation;
      final state = await source.getState();
      if (generation == _generation && identical(source, _source)) {
        _apply(state);
      }
    } on Object {
      // The source breaks its contract: keep the last state.
    } finally {
      _reading = false;
      if (_readAgain && mounted) {
        _readAgain = false;
        unawaited(_read());
      }
    }
  }

  @override
  void didChangeMetrics() => _read();

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    final media = MediaQuery.maybeOf(context);
    final child = media == null
        ? widget.child
        : MediaQuery(
            data: media.copyWith(
              displayFeatures: mergeDisplayFeatures(
                media.displayFeatures,
                _state.displayFeatures,
              ),
            ),
            child: widget.child,
          );
    // The wrappers stay the same whatever the state, so the tree below keeps
    // its state when a fold appears.
    return _FoldablePlatformData(
      state: _state,
      child: FoldableVerticalBarScope(
        edge: _state.verticalBarEdge,
        child: child,
      ),
    );
  }
}

class _FoldablePlatformData extends InheritedWidget {
  const _FoldablePlatformData({required this.state, required super.child});

  final FoldablePlatformState state;

  @override
  bool updateShouldNotify(_FoldablePlatformData oldWidget) =>
      oldWidget.state != state;
}

/// [base] followed by the features of [extra] that [base] does not have yet.
///
/// A feature is a duplicate when its type, state and bounds are the same.
List<DisplayFeature> mergeDisplayFeatures(
  List<DisplayFeature> base,
  List<DisplayFeature> extra,
) {
  if (extra.isEmpty) return base;
  final merged = [...base];
  for (final feature in extra) {
    final duplicate = merged.any(
      (other) =>
          other.type == feature.type &&
          other.state == feature.state &&
          other.bounds == feature.bounds,
    );
    if (!duplicate) merged.add(feature);
  }
  return merged;
}
