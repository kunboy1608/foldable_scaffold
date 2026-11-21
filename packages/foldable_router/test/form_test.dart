import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

// ---------------------------------------------------------------------------
// Does the router break `Form`, `GlobalKey<FormState>` and `TextFormField`?
//
// Every page below is a form whose fields own their text (no controller), so
// a field that is rebuilt from scratch loses what was typed: that is what
// the tests look for, together with the identity of the `FormState`.
// ---------------------------------------------------------------------------

bool twoPane = false;

/// A key that lives outside any State (a top-level / static key, as some apps
/// declare them).
final GlobalKey<FormState> sharedKey = GlobalKey<FormState>();

class FormPage extends StatefulWidget {
  const FormPage({
    super.key,
    required this.tag,
    this.canPop = true,
    this.externalKey,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  final String tag;
  final bool canPop;
  final GlobalKey<FormState>? externalKey;
  final AutovalidateMode autovalidateMode;

  @override
  State<FormPage> createState() => FormPageState();
}

class FormPageState extends State<FormPage> {
  late final GlobalKey<FormState> formKey =
      widget.externalKey ?? GlobalKey<FormState>();
  final Map<String, String?> saved = <String, String?>{};
  final List<bool> pops = <bool>[];
  int changes = 0;
  bool? lastValid;

  void submit() {
    final FormState form = formKey.currentState!;
    lastValid = form.validate();
    if (lastValid!) form.save();
  }

  @override
  Widget build(BuildContext context) {
    final String tag = widget.tag;
    return Scaffold(
      key: Key('page $tag'),
      appBar: AppBar(title: Text('form $tag')),
      body: Form(
        key: formKey,
        canPop: widget.canPop,
        autovalidateMode: widget.autovalidateMode,
        onChanged: () => changes++,
        onPopInvokedWithResult: (bool didPop, Object? result) =>
            pops.add(didPop),
        child: Column(
          children: <Widget>[
            TextFormField(
              key: Key('$tag-name'),
              textInputAction: TextInputAction.next,
              validator: (String? v) =>
                  v == null || v.isEmpty ? '$tag name required' : null,
              onSaved: (String? v) => saved['name'] = v,
            ),
            TextFormField(
              key: Key('$tag-email'),
              validator: (String? v) =>
                  v != null && v.contains('@') ? null : '$tag email invalid',
              onSaved: (String? v) => saved['email'] = v,
            ),
            TextButton(
              key: Key('$tag-submit'),
              onPressed: submit,
              child: Text('submit $tag'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Routes without a shell -------------------------------------------------

class LoginRoute extends FoldableFlatRoute {
  const LoginRoute();
  @override
  String get path => '/login';
  @override
  Widget build(BuildContext context) => const FormPage(tag: 'login');
}

class SignupRoute extends FoldableFlatRoute {
  const SignupRoute();
  @override
  String get path => '/login/signup';
  @override
  FoldableFlatRoute? get parent => const LoginRoute();
  @override
  Widget build(BuildContext context) => const FormPage(tag: 'signup');
}

class LockedRoute extends FoldableFlatRoute {
  const LockedRoute();
  @override
  String get path => '/login/locked';
  @override
  FoldableFlatRoute? get parent => const LoginRoute();
  @override
  Widget build(BuildContext context) =>
      const FormPage(tag: 'locked', canPop: false);
}

class PlainRoute extends FoldableFlatRoute {
  const PlainRoute();
  @override
  String get path => '/plain';
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('plain page')));
}

// --- Routes in a shell ------------------------------------------------------

class FormShell extends FoldableShellRoute {
  const FormShell();

  @override
  String get path => '/';

  @override
  List<FoldableShellChildRoute> get branches => const [
    ItemsRoute(),
    SettingsRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Scaffold(
    body: shell.child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.list), label: 'Items'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    ),
  );

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    if (!twoPane) return null;
    return Row(
      children: <Widget>[
        Expanded(child: panes.primary),
        const VerticalDivider(width: 16),
        Expanded(
          child: panes.hasSecondary
              ? panes.secondary
              : const Center(child: Text('nothing selected')),
        ),
      ],
    );
  }
}

class ItemsRoute extends FoldableShellChildRoute {
  const ItemsRoute();
  @override
  String get path => '/items';
  @override
  FoldableShellParent get parent => const FormShell();
  @override
  Widget build(BuildContext context) => const FormPage(tag: 'items');
}

class SettingsRoute extends FoldableShellChildRoute {
  const SettingsRoute();
  @override
  String get path => '/settings';
  @override
  FoldableShellParent get parent => const FormShell();
  @override
  Widget build(BuildContext context) => const FormPage(tag: 'settings');
}

class EditRoute extends FoldableShellChildRoute {
  const EditRoute();
  @override
  String get path => '/items/edit';
  @override
  FoldableShellParent get parent => const ItemsRoute();
  @override
  Widget build(BuildContext context) => const FormPage(
    tag: 'edit',
    autovalidateMode: AutovalidateMode.onUserInteraction,
  );
}

class DeepRoute extends FoldableShellChildRoute {
  const DeepRoute();
  @override
  String get path => '/items/edit/deep';
  @override
  FoldableShellParent get parent => const EditRoute();
  @override
  Widget build(BuildContext context) => const FormPage(tag: 'deep');
}

class GuardedRoute extends FoldableShellChildRoute {
  const GuardedRoute();
  @override
  String get path => '/items/guarded';
  @override
  FoldableShellParent get parent => const ItemsRoute();
  @override
  Widget build(BuildContext context) =>
      const FormPage(tag: 'guarded', canPop: false);
}

/// Two different routes whose pages use the same top-level key.
class SharedKeyRoute extends FoldableShellChildRoute {
  const SharedKeyRoute({required this.id});
  final String id;
  @override
  String get path => '/items/shared';
  @override
  Map<String, Object?> get params => {'id': id};
  @override
  FoldableShellParent get parent => const ItemsRoute();
  @override
  Widget build(BuildContext context) =>
      FormPage(tag: 'shared-$id', externalKey: sharedKey);
}

// --- Helpers ----------------------------------------------------------------

Future<FoldableRouter> pumpApp(
  WidgetTester tester,
  FoldableRoute initial,
) async {
  final router = FoldableRouter(
    initial: initial,
    routes: {
      '/': (_) => const FormShell(),
      '/login': (_) => const LoginRoute(),
      '/login/signup': (_) => const SignupRoute(),
      '/login/locked': (_) => const LockedRoute(),
      '/plain': (_) => const PlainRoute(),
      '/items': (_) => const ItemsRoute(),
      '/settings': (_) => const SettingsRoute(),
      '/items/edit': (_) => const EditRoute(),
      '/items/edit/deep': (_) => const DeepRoute(),
      '/items/guarded': (_) => const GuardedRoute(),
      '/items/shared': (params) => SharedKeyRoute(id: params['id']!),
    },
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> setTwoPane(
  WidgetTester tester,
  FoldableRouter router, {
  required bool value,
}) async {
  twoPane = value;
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
}

Finder page(String tag) => find.byWidgetPredicate(
  (Widget w) => w is FormPage && w.tag == tag,
  skipOffstage: false,
);

FormPageState pageState(WidgetTester tester, String tag) =>
    tester.state<FormPageState>(page(tag));

Finder field(String key) => find.byKey(Key(key), skipOffstage: false);

String text(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: field(key),
        matching: find.byType(EditableText, skipOffstage: false),
        skipOffstage: false,
      ),
    )
    .controller
    .text;

bool hasFocus(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: field(key), matching: find.byType(EditableText)),
    )
    .focusNode
    .hasPrimaryFocus;

/// Remembers the identity of a form and what was typed, to compare later.
class Snapshot {
  Snapshot(WidgetTester tester, this.tag)
    : page = pageState(tester, tag),
      form = pageState(tester, tag).formKey.currentState!,
      name = text(tester, '$tag-name'),
      email = text(tester, '$tag-email');

  final String tag;
  final FormPageState page;
  final FormState form;
  final String name;
  final String email;

  void expectUnchanged(WidgetTester tester, {String? reason}) {
    final FormPageState now = pageState(tester, tag);
    expect(identical(now, page), isTrue, reason: 'page state lost: $reason');
    expect(
      identical(now.formKey.currentState, form),
      isTrue,
      reason: 'FormState lost: $reason',
    );
    expect(now.formKey.currentContext?.mounted, isTrue, reason: reason);
    expect(text(tester, '$tag-name'), name, reason: reason);
    expect(text(tester, '$tag-email'), email, reason: reason);
  }
}

/// validate / errors / save / reset on a visible form.
Future<void> exerciseForm(WidgetTester tester, String tag) async {
  final FormPageState state = pageState(tester, tag);
  final GlobalKey<FormState> key = state.formKey;
  expect(key.currentState, isNotNull, reason: '$tag: currentState');
  expect(key.currentWidget, isA<Form>());
  // Start from an empty form, whatever was typed before.
  key.currentState!.reset();
  state.saved.clear();
  await tester.pump();

  // Empty form: both validators fail and their messages are drawn.
  await tester.tap(find.byKey(Key('$tag-submit')));
  await tester.pump();
  expect(state.lastValid, isFalse);
  expect(find.text('$tag name required'), findsOneWidget);
  expect(find.text('$tag email invalid'), findsOneWidget);
  expect(state.saved, isEmpty);

  // Typing goes to the right field and reaches Form.onChanged.
  final int changes = state.changes;
  await tester.enterText(find.byKey(Key('$tag-name')), 'Ann $tag');
  await tester.enterText(find.byKey(Key('$tag-email')), 'ann@$tag.dev');
  await tester.pump();
  expect(state.changes, greaterThan(changes));
  expect(text(tester, '$tag-name'), 'Ann $tag');
  expect(text(tester, '$tag-email'), 'ann@$tag.dev');

  // Valid: errors disappear, onSaved gets the values.
  await tester.tap(find.byKey(Key('$tag-submit')));
  await tester.pump();
  expect(state.lastValid, isTrue);
  expect(find.text('$tag name required'), findsNothing);
  expect(find.text('$tag email invalid'), findsNothing);
  expect(state.saved, {'name': 'Ann $tag', 'email': 'ann@$tag.dev'});

  // reset() clears the fields.
  key.currentState!.reset();
  await tester.pump();
  expect(text(tester, '$tag-name'), '');
  expect(text(tester, '$tag-email'), '');
  expect(tester.takeException(), isNull);
}

Future<void> type(WidgetTester tester, String tag) async {
  await tester.enterText(find.byKey(Key('$tag-name')), 'typed $tag');
  await tester.enterText(find.byKey(Key('$tag-email')), 'typed@$tag');
  await tester.pump();
}

Future<void> silentRecheck(WidgetTester tester, FoldableRouter router) async {
  final RouterDelegate<Object> delegate = router.routerConfig.routerDelegate;
  final Object current = delegate.currentConfiguration!;
  // ignore: unawaited_futures
  delegate.setNewRoutePath(current);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => twoPane = false);

  group('without a shell', () {
    testWidgets('validate, errors, save, reset', (tester) async {
      await pumpApp(tester, const LoginRoute());
      await exerciseForm(tester, 'login');
    });

    testWidgets('a child page has a working form of its own', (tester) async {
      final router = await pumpApp(tester, const LoginRoute());
      // ignore: unawaited_futures
      router.open(const SignupRoute());
      await tester.pumpAndSettle();
      await exerciseForm(tester, 'signup');
    });

    testWidgets('the form below keeps its state while pages come and go', (
      tester,
    ) async {
      final router = await pumpApp(tester, const LoginRoute());
      await type(tester, 'login');
      final snap = Snapshot(tester, 'login');

      // ignore: unawaited_futures
      router.open(const SignupRoute());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      snap.expectUnchanged(tester, reason: 'during the push transition');
      await tester.pumpAndSettle();
      snap.expectUnchanged(tester, reason: 'covered by a child page');
      // The covered form still answers through its key.
      expect(snap.page.formKey.currentState!.validate(), isTrue);

      // ignore: unawaited_futures
      router.push<void>(const PlainRoute());
      await tester.pumpAndSettle();
      snap.expectUnchanged(tester, reason: 'two pages above');
      router.pop();
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(router.stack, [const LoginRoute()]);
      snap.expectUnchanged(tester, reason: 'back on top');

      // Still editable after coming back.
      await tester.enterText(find.byKey(const Key('login-name')), 'again');
      expect(text(tester, 'login-name'), 'again');
      expect(tester.takeException(), isNull);
    });

    testWidgets('refresh, silent re-check, rebuild and keyboard keep it', (
      tester,
    ) async {
      final router = await pumpApp(tester, const LoginRoute());
      // ignore: unawaited_futures
      router.open(const SignupRoute());
      await tester.pumpAndSettle();
      await type(tester, 'signup');
      final snap = Snapshot(tester, 'signup');

      // ignore: unawaited_futures
      router.refresh();
      await tester.pumpAndSettle();
      snap.expectUnchanged(tester, reason: 'refresh');

      await silentRecheck(tester, router);
      snap.expectUnchanged(tester, reason: 'silent re-check');

      // Opening the route that is already on top.
      // ignore: unawaited_futures
      router.open(const SignupRoute());
      await tester.pumpAndSettle();
      snap.expectUnchanged(tester, reason: 'open of the current route');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.routerConfig),
      );
      await tester.pumpAndSettle();
      snap.expectUnchanged(tester, reason: 'app rebuild');

      // The on-screen keyboard shows up and the window is resized.
      addTearDown(tester.view.reset);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();
      snap.expectUnchanged(tester, reason: 'keyboard insets');
      tester.view.physicalSize = const Size(1200, 2000);
      await tester.pumpAndSettle();
      snap.expectUnchanged(tester, reason: 'resize');
      expect(tester.takeException(), isNull);
    });

    testWidgets('focus and the keyboard action move between fields', (
      tester,
    ) async {
      await pumpApp(tester, const LoginRoute());
      await tester.tap(find.byKey(const Key('login-name')));
      await tester.pump();
      expect(hasFocus(tester, 'login-name'), isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.enterText('via keyboard');
      await tester.pump();
      expect(text(tester, 'login-name'), 'via keyboard');

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(hasFocus(tester, 'login-email'), isTrue);
    });

    testWidgets('Form(canPop: false) blocks back', (tester) async {
      final router = await pumpApp(tester, const LoginRoute());
      // ignore: unawaited_futures
      router.open(const LockedRoute());
      await tester.pumpAndSettle();
      final FormPageState state = pageState(tester, 'locked');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.stack, [const LoginRoute(), const LockedRoute()]);
      expect(state.pops, [false]);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.stack, [const LoginRoute(), const LockedRoute()]);
      expect(state.pops, [false, false]);
    });

    testWidgets('a popped page releases its key; reopening starts fresh', (
      tester,
    ) async {
      final router = await pumpApp(tester, const LoginRoute());
      // ignore: unawaited_futures
      router.open(const SignupRoute());
      await tester.pumpAndSettle();
      await type(tester, 'signup');
      final GlobalKey<FormState> key = pageState(tester, 'signup').formKey;

      router.pop();
      await tester.pumpAndSettle();
      expect(key.currentState, isNull);

      // ignore: unawaited_futures
      router.open(const SignupRoute());
      await tester.pumpAndSettle();
      expect(text(tester, 'signup-name'), '');
      await exerciseForm(tester, 'signup');
    });
  });

  group('in a shell, one pane', () {
    testWidgets('validate, errors, save, reset on a tab root and a child', (
      tester,
    ) async {
      final router = await pumpApp(tester, const FormShell());
      await exerciseForm(tester, 'items');
      // ignore: unawaited_futures
      router.open(const DeepRoute());
      await tester.pumpAndSettle();
      await exerciseForm(tester, 'deep');
    });

    testWidgets('forms survive tab switches and pages above', (tester) async {
      final router = await pumpApp(tester, const FormShell());
      await type(tester, 'items');
      final items = Snapshot(tester, 'items');

      // ignore: unawaited_futures
      router.open(const EditRoute());
      await tester.pumpAndSettle();
      await type(tester, 'edit');
      final edit = Snapshot(tester, 'edit');

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      items.expectUnchanged(tester, reason: 'hidden tab');
      edit.expectUnchanged(tester, reason: 'hidden tab');
      // A form of a hidden tab still validates through its key.
      expect(edit.page.formKey.currentState!.validate(), isTrue);
      await exerciseForm(tester, 'settings');
      await type(tester, 'settings');
      final settings = Snapshot(tester, 'settings');

      await tester.tap(find.text('Items'));
      await tester.pumpAndSettle();
      items.expectUnchanged(tester, reason: 'tab shown again');
      edit.expectUnchanged(tester, reason: 'tab shown again');
      settings.expectUnchanged(tester, reason: 'now hidden');

      // A full-screen page above the shell.
      // ignore: unawaited_futures
      router.push<void>(const PlainRoute());
      await tester.pumpAndSettle();
      edit.expectUnchanged(tester, reason: 'covered by a full-screen page');
      router.pop();
      await tester.pumpAndSettle();

      // ignore: unawaited_futures
      router.refresh();
      await tester.pumpAndSettle();
      await silentRecheck(tester, router);
      edit.expectUnchanged(tester, reason: 'refresh + re-check');
      items.expectUnchanged(tester, reason: 'refresh + re-check');

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(router.stack, [const FormShell(), const ItemsRoute()]);
      expect(edit.page.formKey.currentState, isNull);
      items.expectUnchanged(tester, reason: 'child popped');
      expect(tester.takeException(), isNull);
    });

    testWidgets('autovalidate on user interaction', (tester) async {
      final router = await pumpApp(tester, const FormShell());
      // ignore: unawaited_futures
      router.open(const EditRoute());
      await tester.pumpAndSettle();
      expect(find.text('edit email invalid'), findsNothing);
      await tester.enterText(find.byKey(const Key('edit-email')), 'nope');
      await tester.pump();
      expect(find.text('edit email invalid'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('edit-email')), 'a@b');
      await tester.pump();
      expect(find.text('edit email invalid'), findsNothing);
    });

    testWidgets('Form(canPop: false) blocks back', (tester) async {
      final router = await pumpApp(tester, const FormShell());
      // ignore: unawaited_futures
      router.open(const GuardedRoute());
      await tester.pumpAndSettle();
      final FormPageState state = pageState(tester, 'guarded');
      final stack = [
        const FormShell(),
        const ItemsRoute(),
        const GuardedRoute(),
      ];

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.stack, stack);
      expect(state.pops, [false]);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.stack, stack);
      expect(state.pops, [false, false]);
    });
  });

  group('in a shell, two panes', () {
    testWidgets('both visible forms work independently', (tester) async {
      final router = await pumpApp(tester, const FormShell());
      await setTwoPane(tester, router, value: true);
      // ignore: unawaited_futures
      router.open(const EditRoute());
      await tester.pumpAndSettle();
      expect(
        FoldableRouter.paneOf(tester.element(page('items'))),
        FoldablePane.primary,
      );
      expect(
        FoldableRouter.paneOf(tester.element(page('edit'))),
        FoldablePane.secondary,
      );

      await exerciseForm(tester, 'items'); // left
      await exerciseForm(tester, 'edit'); // right
      await exerciseForm(tester, 'items'); // left again, right still there

      // Errors of one form do not show in the other.
      await tester.tap(find.byKey(const Key('items-submit')));
      await tester.pump();
      expect(find.text('items name required'), findsOneWidget);
      expect(find.text('edit name required'), findsNothing);
    });

    testWidgets('focus and typing in the left and in the right pane', (
      tester,
    ) async {
      final router = await pumpApp(tester, const FormShell());
      await setTwoPane(tester, router, value: true);
      // ignore: unawaited_futures
      router.open(const EditRoute());
      await tester.pumpAndSettle();

      for (final tag in ['items', 'edit', 'items']) {
        await tester.tap(find.byKey(Key('$tag-name')));
        await tester.pump();
        expect(hasFocus(tester, '$tag-name'), isTrue, reason: tag);
        expect(tester.testTextInput.hasAnyClients, isTrue, reason: tag);
        tester.testTextInput.enterText('kb $tag');
        await tester.pump();
        expect(text(tester, '$tag-name'), 'kb $tag');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(hasFocus(tester, '$tag-email'), isTrue, reason: tag);
        tester.testTextInput.enterText('kb@$tag');
        await tester.pump();
        expect(text(tester, '$tag-email'), 'kb@$tag');
      }
      expect(text(tester, 'edit-name'), 'kb edit');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the left field keeps focus and text when the right pane '
        'changes', (tester) async {
      final router = await pumpApp(tester, const FormShell());
      await setTwoPane(tester, router, value: true);
      await tester.tap(find.byKey(const Key('items-name')));
      await tester.pump();
      tester.testTextInput.enterText('left');
      await tester.pump();
      final items = Snapshot(tester, 'items');

      // ignore: unawaited_futures
      router.open(const EditRoute());
      await tester.pumpAndSettle();
      items.expectUnchanged(tester, reason: 'right pane opened');

      // Typing on the left again once the right pane is there.
      await tester.tap(find.byKey(const Key('items-name')));
      await tester.pump();
      expect(hasFocus(tester, 'items-name'), isTrue);
      tester.testTextInput.enterText('left 2');
      await tester.pump();
      expect(text(tester, 'items-name'), 'left 2');

      // System back closes the right pane; the left form is untouched.
      final items2 = Snapshot(tester, 'items');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(router.stack, [const FormShell(), const ItemsRoute()]);
      items2.expectUnchanged(tester, reason: 'right pane closed');
      expect(tester.takeException(), isNull);
    });

    testWidgets('forms survive one pane <-> two panes and the sliding '
        'window', (tester) async {
      final router = await pumpApp(tester, const FormShell());
      // ignore: unawaited_futures
      router.open(const DeepRoute());
      await tester.pumpAndSettle();
      expect(router.stack, [
        const FormShell(),
        const ItemsRoute(),
        const EditRoute(),
        const DeepRoute(),
      ]);
      await type(tester, 'deep');
      final deep = Snapshot(tester, 'deep');
      final GlobalKey<FormState> itemsKey = pageState(tester, 'items').formKey;
      final GlobalKey<FormState> editKey = pageState(tester, 'edit').formKey;
      final FormState itemsForm = itemsKey.currentState!;
      final FormState editForm = editKey.currentState!;

      for (var i = 0; i < 2; i++) {
        await setTwoPane(tester, router, value: true);
        deep.expectUnchanged(tester, reason: 'two panes ($i)');
        expect(identical(itemsKey.currentState, itemsForm), isTrue);
        expect(identical(editKey.currentState, editForm), isTrue);
        await setTwoPane(tester, router, value: false);
        deep.expectUnchanged(tester, reason: 'one pane ($i)');
        expect(identical(itemsKey.currentState, itemsForm), isTrue);
        expect(identical(editKey.currentState, editForm), isTrue);
      }

      // Two panes: [items hidden] [edit | deep]. The hidden form is alive
      // and its key answers.
      await setTwoPane(tester, router, value: true);
      expect(itemsKey.currentState!.validate(), isFalse);
      await tester.pump();
      await exerciseForm(tester, 'edit');
      await type(tester, 'edit');
      final edit = Snapshot(tester, 'edit');

      // Back: edit slides from the left pane to the right, items appears.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      edit.expectUnchanged(tester, reason: 'while sliding');
      await tester.pumpAndSettle();
      edit.expectUnchanged(tester, reason: 'moved to the right pane');
      expect(
        FoldableRouter.paneOf(tester.element(page('edit'))),
        FoldablePane.secondary,
      );
      expect(identical(itemsKey.currentState, itemsForm), isTrue);
      await exerciseForm(tester, 'items');
      await exerciseForm(tester, 'edit');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Form(canPop: false) on the right blocks every back', (
      tester,
    ) async {
      final router = await pumpApp(tester, const FormShell());
      await setTwoPane(tester, router, value: true);
      // ignore: unawaited_futures
      router.open(const GuardedRoute());
      await tester.pumpAndSettle();
      final FormPageState state = pageState(tester, 'guarded');
      final stack = [
        const FormShell(),
        const ItemsRoute(),
        const GuardedRoute(),
      ];

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.stack, stack);
      expect(state.pops, [false]);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.stack, stack);
      expect(state.pops, [false, false]);

      FoldableRouter.close(tester.element(page('guarded')));
      await tester.pumpAndSettle();
      expect(router.stack, stack);
      expect(state.pops, [false, false, false]);
    });
  });

  group('a key declared outside the State', () {
    for (final panes in [false, true]) {
      testWidgets('one page with a top-level key, twoPane=$panes', (
        tester,
      ) async {
        final router = await pumpApp(tester, const FormShell());
        await setTwoPane(tester, router, value: panes);
        // ignore: unawaited_futures
        router.open(const SharedKeyRoute(id: '1'));
        await tester.pumpAndSettle();
        await exerciseForm(tester, 'shared-1');
        await type(tester, 'shared-1');
        final snap = Snapshot(tester, 'shared-1');

        // ignore: unawaited_futures
        router.push<void>(const PlainRoute());
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();
        await setTwoPane(tester, router, value: !panes);
        await setTwoPane(tester, router, value: panes);
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Items'));
        await tester.pumpAndSettle();
        snap.expectUnchanged(tester, reason: 'top-level key');

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(sharedKey.currentState, isNull);
        expect(tester.takeException(), isNull);
      });

      // Not something the router can fix: while the old page animates out
      // and the new one animates in, both are in the tree with the same
      // GlobalKey. A plain Navigator reports the same error (next test).
      testWidgets('replacing a page by another one using the same key is a '
          'duplicate key, twoPane=$panes', (tester) async {
        final router = await pumpApp(tester, const FormShell());
        await setTwoPane(tester, router, value: panes);
        // ignore: unawaited_futures
        router.open(const SharedKeyRoute(id: '1'));
        await tester.pumpAndSettle();
        // ignore: unawaited_futures
        router.open(const SharedKeyRoute(id: '2'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (FlutterError e) => e.message,
            'message',
            contains('GlobalKey'),
          ),
        );
      });
    }

    testWidgets('baseline: a plain Navigator has the same duplicate key', (
      tester,
    ) async {
      Widget app(String id) => MaterialApp(
        home: Navigator(
          pages: <Page<void>>[
            const MaterialPage<void>(key: ValueKey('root'), child: Text('r')),
            MaterialPage<void>(
              key: ValueKey(id),
              child: Scaffold(
                body: Form(key: sharedKey, child: TextFormField()),
              ),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      );
      await tester.pumpWidget(app('1'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app('2'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (FlutterError e) => e.message,
          'message',
          contains('GlobalKey'),
        ),
      );
    });
  });
}
