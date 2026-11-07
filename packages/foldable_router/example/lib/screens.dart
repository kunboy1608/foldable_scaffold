import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A button that pushes a [location] onto the current branch.
class PushButton extends StatelessWidget {
  const PushButton(this.label, this.location, {super.key});

  final String label;
  final String location;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () => FoldableRouterScope.of(context).pushLocation(location),
    );
  }
}

/// A button that opens a [location] (replaces the children above the caller).
class OpenButton extends StatelessWidget {
  const OpenButton(this.label, this.location, {super.key});

  final String label;
  final String location;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () => FoldableRouterScope.of(context).openLocation(location),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouterScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        children: [
          PushButton('Push Calendar', '/home/calendar'),
          OpenButton('Open List news', '/home/news'),
          ListTile(
            title: const Text('Switch to the Statistics shell'),
            subtitle: const Text('The Home tab keeps its stack.'),
            onTap: () => router.showShell(router.shells[1]),
          ),
        ],
      ),
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        children: [
          PushButton('Push Event details', '/home/calendar/event'),
        ],
      ),
    );
  }
}

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: const Center(child: Text('Event details')),
    );
  }
}

class ListNewsScreen extends StatelessWidget {
  const ListNewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List news')),
      body: ListView(
        children: const [
          PushButton('Open New details', '/home/news/new'),
        ],
      ),
    );
  }
}

class NewDetailsScreen extends StatelessWidget {
  const NewDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New details')),
      body: const Center(child: Text('New details')),
    );
  }
}

class DocumentScreen extends StatelessWidget {
  const DocumentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document')),
      body: ListView(
        children: const [
          PushButton('Push Record editor', '/document/record'),
        ],
      ),
    );
  }
}

class RecordEditorScreen extends StatelessWidget {
  const RecordEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record editor')),
      body: const Center(child: Text('Record editor')),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: const [
          PushButton('Push Edit profile', '/profile/edit'),
          PushButton('Push Bill management', '/profile/bills'),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: const Center(child: Text('Edit profile')),
    );
  }
}

class BillManagementScreen extends StatelessWidget {
  const BillManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill management')),
      body: const Center(child: Text('Bill management')),
    );
  }
}

class ProfitScreen extends StatelessWidget {
  const ProfitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profit')),
      body: ListView(
        children: const [
          PushButton('Push Recipe details', '/profit/recipe'),
        ],
      ),
    );
  }
}

class RecipeDetailsScreen extends StatelessWidget {
  const RecipeDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe details')),
      body: const Center(child: Text('Recipe details')),
    );
  }
}

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense')),
      body: ListView(
        children: const [
          PushButton('Push Recipe details', '/expense/recipe'),
        ],
      ),
    );
  }
}

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouterScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => router.openLocation('/home'),
          child: const Text('Go to Home'),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: const Center(child: Text('Sign up')),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen(this.uri, {super.key});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('No route for $uri')),
    );
  }
}