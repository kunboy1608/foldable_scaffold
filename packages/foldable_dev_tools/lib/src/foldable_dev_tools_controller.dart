import 'dart:collection';

import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A screen size [FoldableDevTools] can pretend the app runs in.
@immutable
class FoldableViewport {
  const FoldableViewport({required this.name, required this.size});

  /// Label shown in the dev tools panel.
  final String name;

  /// The simulated logical size.
  final Size size;

  /// A phone, 360×800.
  static const phone = FoldableViewport(name: 'Phone', size: Size(360, 800));

  /// A large phone, 412×915.
  static const phoneLarge = FoldableViewport(
    name: 'Phone large',
    size: Size(412, 915),
  );

  /// A foldable, closed: 320×800.
  static const foldableClosed = FoldableViewport(
    name: 'Foldable closed',
    size: Size(320, 800),
  );

  /// A foldable, unfolded: 717×800 (Surface Duo is 540+540 wide).
  static const foldableOpen = FoldableViewport(
    name: 'Foldable open',
    size: Size(717, 800),
  );

  /// A tablet, 834×1112.
  static const tablet = FoldableViewport(name: 'Tablet', size: Size(834, 1112));

  /// A small window, 1000×800 (the scaffold's navigation gets wider here).
  static const laptop = FoldableViewport(name: 'Laptop', size: Size(1000, 800));

  /// A window wide enough for the two panes, 1280×800.
  static const desktop = FoldableViewport(
    name: 'Desktop',
    size: Size(1280, 800),
  );

  /// Every preset, smallest first.
  static const presets = <FoldableViewport>[
    phone,
    phoneLarge,
    foldableClosed,
    foldableOpen,
    tablet,
    laptop,
    desktop,
  ];
}

/// The pane layout reported by `FoldablePaneLayoutObserver`.
@immutable
class FoldablePaneInfo {
  const FoldablePaneInfo({
    required this.primaryVisible,
    required this.secondaryVisible,
    required this.canSplit,
    required this.width,
    required this.height,
  });

  /// Whether the body pane is visible.
  final bool primaryVisible;

  /// Whether the secondary body pane is visible.
  final bool secondaryVisible;

  /// Whether the scaffold has room for two panes.
  final bool canSplit;

  /// Width of the simulated screen when the report was made.
  final double width;

  /// Height of the simulated screen when the report was made.
  final double height;
}

/// State of a [FoldableDevTools] overlay, and the navigation log it collects.
///
/// Create one to change the simulated screen from code or a test:
///
/// ```dart
/// final controller = FoldableDevToolsController()
///   ..viewport = FoldableViewport.foldableOpen
///   ..slowMotion = true;
/// FoldableDevTools(controller: controller, router: router, child: app);
/// ```
class FoldableDevToolsController extends ChangeNotifier
    implements FoldableRouterObserver {
  bool _open = false;
  FoldableViewport? _viewport;
  bool _slowMotion = false;
  bool _showHinge = false;
  double _hingePosition = 0.5;
  double _hingeThickness = 24;
  FoldablePaneInfo? _pane;
  final List<FoldableNavigationEvent> _events = [];

  /// Whether the panel is open.
  bool get isOpen => _open;
  set isOpen(bool value) {
    if (_open == value) return;
    _open = value;
    notifyListeners();
  }

  /// The simulated screen, or null to use the real window size.
  FoldableViewport? get viewport => _viewport;
  set viewport(FoldableViewport? value) {
    if (_viewport?.size == value?.size && _viewport?.name == value?.name) {
      return;
    }
    _viewport = value;
    notifyListeners();
  }

  /// The simulated width and height, keeping the current preset label.
  void setViewportSize(Size size) {
    final name = _viewport?.name ?? 'Custom';
    _viewport = FoldableViewport(name: name, size: size);
    notifyListeners();
  }

  /// Whether animations run [slowMotionFactor] times slower.
  bool get slowMotion => _slowMotion;
  set slowMotion(bool value) {
    if (_slowMotion == value) return;
    _slowMotion = value;
    notifyListeners();
  }

  /// How much [slowMotion] slows animations down.
  double get slowMotionFactor => 6;

  /// Whether a hinge is drawn over the simulated screen.
  bool get showHinge => _showHinge;
  set showHinge(bool value) {
    if (_showHinge == value) return;
    _showHinge = value;
    notifyListeners();
  }

  /// Where the hinge sits, from 0 (left) to 1 (right).
  double get hingePosition => _hingePosition;
  set hingePosition(double value) {
    if (_hingePosition == value) return;
    _hingePosition = value;
    notifyListeners();
  }

  /// How wide the hinge is drawn.
  double get hingeThickness => _hingeThickness;
  set hingeThickness(double value) {
    if (_hingeThickness == value) return;
    _hingeThickness = value;
    notifyListeners();
  }

  /// The last pane layout reported by `FoldablePaneLayoutObserver`, if one is
  /// in the tree.
  FoldablePaneInfo? get pane => _pane;

  /// The navigations seen so far, oldest first.
  List<FoldableNavigationEvent> get events => UnmodifiableListView(_events);

  /// Records [pane] as the current layout.
  void reportPane(FoldablePaneInfo pane) {
    final old = _pane;
    if (old != null &&
        old.primaryVisible == pane.primaryVisible &&
        old.secondaryVisible == pane.secondaryVisible &&
        old.canSplit == pane.canSplit &&
        old.width == pane.width &&
        old.height == pane.height) {
      return;
    }
    _pane = pane;
    notifyListeners();
  }

  /// Empties the navigation log.
  void clearEvents() {
    if (_events.isEmpty) return;
    _events.clear();
    notifyListeners();
  }

  @override
  void onNavigation(FoldableNavigationEvent event) {
    _events.add(event);
    if (_events.length > 100) _events.removeAt(0);
    notifyListeners();
  }
}
