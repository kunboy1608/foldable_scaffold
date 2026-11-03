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
///
/// The tune button opens the layout options in the end drawer, to try every
/// setting of the scaffold live: snap widths, breakpoints,
/// pane sizes and animation speed. The other slots are used too: the menu button
/// opens the drawer, the compose button is the floating action button, and its
/// composer is the bottom sheet.
class ScaffoldExample extends StatefulWidget {
  const ScaffoldExample({super.key});

  @override
  State<ScaffoldExample> createState() => _ScaffoldExampleState();
}

/// The mailboxes of the navigation, with the messages each one lists.
const _mailboxes = <(IconData, String, List<String>)>[
  (Icons.inbox, 'Inbox', ['The first message', 'A second one', 'A third one']),
  (Icons.send, 'Sent', ['Re: The first message', 'Meeting notes']),
  (Icons.drafts, 'Drafts', ['Untitled draft']),
];

Duration _normalMotion(Duration duration) => duration;
Duration _slowMotion(Duration duration) => duration * 6;

/// Where the snap widths of the demo are: the M3 widths of a fixed pane.
const _snapWidths = [360.0, 412.0];

/// The settings of the scaffold that the end drawer changes.
class _Options {
  bool snap = true;
  bool focusOnPrimaryBody = false;
  bool followFold = true;

  /// Two panes from 840, the start of the M3 expanded breakpoint.
  bool splitFrom840 = false;
  double minBodySize = 200;
  double dividerSize = 24;
  bool slowMotion = false;

  void reset() {
    snap = true;
    focusOnPrimaryBody = false;
    followFold = true;
    splitFrom840 = false;
    minBodySize = 200;
    dividerSize = 24;
    slowMotion = false;
  }
}

class _ScaffoldExampleState extends State<ScaffoldExample> {
  int _tab = 0;
  String? _message = 'The first message';
  SimulatedFold _fold = SimulatedFold.device;
  bool _composing = false;
  final _options = _Options();

  /// Phone rules show two panes from 600 wide, which a desktop window with a
  /// simulated flat fold needs to be seen.
  bool _handheldRules = false;

  FoldableBreakpoints? get _breakpoints {
    if (_options.splitFrom840) return const FoldableBreakpoints(split: 840);
    if (_handheldRules) return const FoldableBreakpoints.handheld();
    return null;
  }

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final options = _options;
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
      home: FoldableMotion(
        scale: options.slowMotion ? _slowMotion : _normalMotion,
        child: FoldableScaffold(
          breakpoints: _breakpoints,
          followFold: options.followFold,
          focusOnPrimaryBody: options.focusOnPrimaryBody,
          minBodySize: options.minBodySize,
          dividerSize: options.dividerSize,
          snapWidths: options.snap ? _snapWidths : const [],
          topNavigationBuilder: (context, constraints) => AppBar(
            title: Text(_mailboxes[_tab].$2),
            // The end drawer button below replaces the implied one.
            automaticallyImplyActions: false,
            actions: [
              _FoldMenu(
                fold: _fold,
                handheldRules: _handheldRules,
                onFold: (fold) => _update(() => _fold = fold),
                onHandheldRules: (value) =>
                    _update(() => _handheldRules = value),
              ),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Layout options',
                  onPressed: Scaffold.of(context).openEndDrawer,
                ),
              ),
            ],
          ),
          drawer: _MailDrawer(
            tab: _tab,
            onTab: (index) => _update(() {
              _tab = index;
              _message = null;
            }),
          ),
          endDrawer: Drawer(
            child: _OptionsPanel(options: options, onChanged: _update),
          ),
          floatingActionButton: _composing
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _update(() => _composing = true),
                  icon: const Icon(Icons.edit),
                  label: const Text('Compose'),
                ),
          bottomSheet: _composing
              ? _ComposeSheet(onDone: () => _update(() => _composing = false))
              : null,
          primaryNavigationBuilder: (context, constraints, padding) {
            return NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (index) => _update(() {
                _tab = index;
                _message = null;
              }),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, label, _) in _mailboxes)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    label: Text(label),
                  ),
              ],
            );
          },
          bottomNavigationBuilder: (context, constraints) {
            return NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => _update(() {
                _tab = index;
                _message = null;
              }),
              destinations: [
                for (final (icon, label, _) in _mailboxes)
                  NavigationDestination(icon: Icon(icon), label: label),
              ],
            );
          },
          bodyBuilder: (context, constraints) {
            return ListView(
              children: [
                const _LayoutCard(),
                for (final message in _mailboxes[_tab].$3)
                  ListTile(
                    selected: message == _message,
                    title: Text(message),
                    onTap: () => _update(() => _message = message),
                  ),
              ],
            );
          },
          hasSecondaryBody: _message != null,
          // The system back closes the message before it leaves the app.
          onSecondBodyClose: (didPop, _) => _update(() => _message = null),
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
                    const SizedBox(height: 8),
                    Text('This pane is ${constraints.maxWidth.round()} wide.'),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: () => _update(() => _message = null),
                      child: const Text('Close the message'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The drawer: the mailboxes, for a window too narrow for the rail.
class _MailDrawer extends StatelessWidget {
  const _MailDrawer({required this.tab, required this.onTab});

  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: tab,
      onDestinationSelected: (index) {
        onTab(index);
        Navigator.of(context).pop();
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text('Mail', style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final (icon, label, _) in _mailboxes)
          NavigationDrawerDestination(icon: Icon(icon), label: Text(label)),
      ],
    );
  }
}

/// The floating action button opens it: the bottom sheet of the scaffold.
class _ComposeSheet extends StatelessWidget {
  const _ComposeSheet({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Expanded(child: Text('New message')),
              TextButton(onPressed: onDone, child: const Text('Discard')),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Message sent')));
                  onDone();
                },
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The end drawer: the settings of the scaffold, applied as they change.
class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({required this.options, required this.onChanged});

  final _Options options;
  final void Function(VoidCallback change) onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Layout options', style: textTheme.titleLarge),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Snap to 360 and 412'),
            subtitle: const Text('When the divider is released nearby'),
            value: options.snap,
            onChanged: (value) => onChanged(() => options.snap = value),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep the list on one pane'),
            subtitle: const Text('focusOnPrimaryBody'),
            value: options.focusOnPrimaryBody,
            onChanged: (value) =>
                onChanged(() => options.focusOnPrimaryBody = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Follow the fold'),
            subtitle: const Text('followFold'),
            value: options.followFold,
            onChanged: (value) => onChanged(() => options.followFold = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Two panes from 840'),
            subtitle: const Text('breakpoints, whatever the platform'),
            value: options.splitFrom840,
            onChanged: (value) => onChanged(() => options.splitFrom840 = value),
          ),
          const Divider(),
          Text(
            'Minimum pane width: ${options.minBodySize.round()}',
            style: textTheme.labelLarge,
          ),
          Slider(
            min: 100,
            max: 400,
            divisions: 30,
            value: options.minBodySize,
            onChanged: (value) => onChanged(() => options.minBodySize = value),
          ),
          Text(
            'Divider width: ${options.dividerSize.round()}',
            style: textTheme.labelLarge,
          ),
          Slider(
            min: 12,
            max: 48,
            divisions: 36,
            value: options.dividerSize,
            onChanged: (value) => onChanged(() => options.dividerSize = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Slow motion'),
            subtitle: const Text('FoldableMotion, 6 times slower'),
            value: options.slowMotion,
            onChanged: (value) => onChanged(() => options.slowMotion = value),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => onChanged(options.reset),
            child: const Text('Reset'),
          ),
        ],
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
    final canSplit = FoldableScaffoldScope.maybeOf(context)?.canSplit ?? false;
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
            const SizedBox(height: 8),
            Text('Room for', style: Theme.of(context).textTheme.labelMedium),
            Text(canSplit ? 'fits two' : 'fits one'),
          ],
        ),
      ),
    );
  }
}
