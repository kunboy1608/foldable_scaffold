import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const ScaffoldExample());

/// What the demo pretends the device has, in place of the real one.
enum SimulatedFold {
  /// Whatever the device reports: nothing on a phone or a desktop, the crease
  /// on a real foldable.
  device('This device'),

  /// A hinge between two screens, like a dual-screen device.
  hinge('Hinge (two screens)'),

  /// The crease of a foldable that is fully open.
  flat('Fold, flat'),

  /// The crease of a foldable that is half open, like a book.
  halfOpen('Fold, half open');

  const SimulatedFold(this.label);

  final String label;

  /// The feature the platform would report for a window of [size], or null to
  /// keep the real ones.
  DisplayFeature? featureFor(Size size) {
    final middle = size.width / 2;
    return switch (this) {
      SimulatedFold.device => null,
      SimulatedFold.hinge => DisplayFeature(
        bounds: Rect.fromLTRB(middle - 20, 0, middle + 20, size.height),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      ),
      SimulatedFold.flat => DisplayFeature(
        bounds: Rect.fromLTRB(middle, 0, middle, size.height),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      ),
      SimulatedFold.halfOpen => DisplayFeature(
        bounds: Rect.fromLTRB(middle, 0, middle, size.height),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    };
  }
}

/// A mail app: the body lists messages, the secondary body reads one.
///
/// Resize the window: one pane in a narrow window, both panes in a wide one
/// (1200 on desktop, 600 on the inner screen of a foldable or a tablet), and the
/// divider can be dragged.
///
/// The fold button in the app bar pretends the device has a fold, so you can
/// see how the panes follow it without owning a foldable:
///
/// * **Hinge** and **half open fold**: one pane on each side, whatever the
///   width, and the divider cannot be dragged.
/// * **Flat fold**: the divider starts on the crease and can still be dragged.
class ScaffoldExample extends StatefulWidget {
  const ScaffoldExample({super.key});

  @override
  State<ScaffoldExample> createState() => _ScaffoldExampleState();
}

class _ScaffoldExampleState extends State<ScaffoldExample> {
  static const _destinations = <(IconData, String)>[
    (Icons.inbox, 'Inbox'),
    (Icons.send, 'Sent'),
    (Icons.settings, 'Settings'),
  ];

  int _tab = 0;
  String? _message = 'The first message';
  SimulatedFold _fold = SimulatedFold.device;

  /// Phone rules show two panes from 600 wide, which a desktop window with a
  /// simulated flat fold needs to be seen.
  bool _handheldRules = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      // The fake fold goes where the real one would come from.
      builder: (context, child) {
        final feature = _fold.featureFor(MediaQuery.sizeOf(context));
        if (feature == null) return child!;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(displayFeatures: [feature]),
          child: child!,
        );
      },
      home: FoldableScaffold(
        breakpoints: _handheldRules
            ? const FoldableBreakpoints.handheld()
            : null,
        topNavigationBuilder: (context, constraints) => AppBar(
          title: Text(_destinations[_tab].$2),
          actions: [
            _FoldMenu(
              fold: _fold,
              handheldRules: _handheldRules,
              onFold: (fold) => setState(() => _fold = fold),
              onHandheldRules: (value) =>
                  setState(() => _handheldRules = value),
            ),
          ],
        ),
        primaryNavigationBuilder: (context, constraints, padding) {
          return NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final (icon, label) in _destinations)
                NavigationRailDestination(icon: Icon(icon), label: Text(label)),
            ],
          );
        },
        bottomNavigationBuilder: (context, constraints) {
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: [
              for (final (icon, label) in _destinations)
                NavigationDestination(icon: Icon(icon), label: label),
            ],
          );
        },
        bodyBuilder: (context, constraints) {
          return ListView(
            children: [
              const _LayoutCard(),
              for (final message in ['The first message', 'A second one'])
                ListTile(
                  selected: message == _message,
                  title: Text(message),
                  onTap: () => setState(() => _message = message),
                ),
            ],
          );
        },
        hasSecondaryBody: _message != null,
        secondaryBodyBuilder: (context, constraints) {
          final message = _message;
          if (message == null) return null;
          return Scaffold(
            appBar: AppBar(title: Text(message)),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading "$message".'),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: () => setState(() => _message = null),
                    child: const Text('Close the message'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The app bar button that picks the fold to pretend and the layout rules.
class _FoldMenu extends StatelessWidget {
  const _FoldMenu({
    required this.fold,
    required this.handheldRules,
    required this.onFold,
    required this.onHandheldRules,
  });

  final SimulatedFold fold;
  final bool handheldRules;
  final ValueChanged<SimulatedFold> onFold;
  final ValueChanged<bool> onHandheldRules;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: 'Pretend the device has a fold',
      icon: Icon(
        fold == SimulatedFold.device ? Icons.devices_fold : Icons.view_column,
      ),
      onSelected: (value) {
        if (value is SimulatedFold) onFold(value);
        if (value is bool) onHandheldRules(value);
      },
      itemBuilder: (context) => [
        for (final option in SimulatedFold.values)
          CheckedPopupMenuItem<Object>(
            value: option,
            checked: option == fold,
            child: Text(option.label),
          ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<Object>(
          value: !handheldRules,
          checked: handheldRules,
          child: const Text('Phone and tablet rules (two panes from 600)'),
        ),
      ],
    );
  }
}

/// Says what the scaffold decided, from what the panes can ask it.
class _LayoutCard extends StatelessWidget {
  const _LayoutCard();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fold = FoldableFold.maybeOf(context);
    final layout = FoldablePaneLayout.maybeOf(context);
    final panes = switch ((layout?.primaryVisible, layout?.secondaryVisible)) {
      (true, true) => 'two panes',
      (_, _) => 'one pane',
    };
    final String foldText;
    if (fold == null) {
      foldText = 'no fold';
    } else if (fold.isSeparating) {
      foldText =
          'separating fold at ${fold.center.round()}: one pane on each side';
    } else {
      foldText =
          'flat fold at ${fold.center.round()}: the divider starts there';
    }

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Window', style: Theme.of(context).textTheme.labelMedium),
            Text('${size.width.round()} x ${size.height.round()}'),
            const SizedBox(height: 8),
            Text('Fold', style: Theme.of(context).textTheme.labelMedium),
            Text(foldText),
            const SizedBox(height: 8),
            Text('Layout', style: Theme.of(context).textTheme.labelMedium),
            Text(panes),
          ],
        ),
      ),
    );
  }
}
