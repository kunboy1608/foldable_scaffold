import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const ScaffoldExample());

/// A mail app: the body lists messages, the secondary body reads one.
///
/// Resize the window: one pane below 1200, both panes above, and the divider
/// can be dragged.
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: FoldableScaffold(
        topNavigationBuilder: (context, constraints) =>
            AppBar(title: Text(_destinations[_tab].$2)),
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
