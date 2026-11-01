import 'package:material_ui/material_ui.dart';

/// Full screen page for the sign in and onboarding sessions: no scaffold
/// bar, no navigation rail, just a title, a body and actions.
class FullScreenPage extends StatelessWidget {
  const FullScreenPage({
    required this.title,
    required this.body,
    required this.actions,
    super.key,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled group of [LabAction]s in the navigation lab.
class LabSection extends StatelessWidget {
  const LabSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// One navigation button of the lab.
class LabAction extends StatelessWidget {
  const LabAction({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(title), subtitle: Text(subtitle), onTap: onTap);
  }
}
