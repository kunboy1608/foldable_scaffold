import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

import 'predictive_back_test.dart';
import 'shell_route_test.dart';

/// A branch page that vetoes its own pop, to check that user [PopScope]s
/// keep working with the shell's back routing.
class GuardedDetailRoute extends FoldableRoute {
  const GuardedDetailRoute();

  @override
  String get path => '/a/guarded';

  @override
  FoldableRoute? get parent => const TabARoute();

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) => guardedPops.add(didPop),
    child: const Text('guarded detail'),
  );
}

/// Records `onPopInvokedWithResult` of the guarded pages and dialogs.
final List<bool> guardedPops = <bool>[];
final List<bool> dialogPops = <bool>[];

BuildContext contextOf(WidgetTester tester, String text) =>
    tester.element(find.text(text, skipOffstage: false));

Future<FoldableRouter> pumpShellApp(
  WidgetTester tester, {
  FoldableRoute initial = const ShellMain(),
}) async {
  final router = createShellRouter(
    initial: initial,
    extraRoutes: {'/a/guarded': (params) => const GuardedDetailRoute()},
  );
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

/// A dialog on the root navigator (`useRootNavigator: true`, the default of
/// [showDialog]).
Future<String?> openRootDialog(
  WidgetTester tester, {
  bool canPop = true,
  String from = 'tab a',
}) {
  return showDialog<String>(
    context: contextOf(tester, from),
    useRootNavigator: true,
    builder: (context) => PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) => dialogPops.add(didPop),
      child: const AlertDialog(title: Text('test dialog')),
    ),
  );
}

/// A bottom sheet on the nearest navigator, i.e. the one of the branch.
Future<String?> openBranchSheet(WidgetTester tester, {String from = 'tab a'}) {
  return showModalBottomSheet<String>(
    context: contextOf(tester, from),
    builder: (context) => const Text('test sheet'),
  );
}

/// A popup menu on the nearest navigator, i.e. the one of the branch.
Future<String?> openBranchMenu(WidgetTester tester, {String from = 'tab a'}) {
  return showMenu<String>(
    context: contextOf(tester, from),
    position: const RelativeRect.fromLTRB(10, 100, 10, 100),
    items: const [
      PopupMenuItem<String>(value: 'item', child: Text('menu item')),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    reportedHandlesBack.clear();
    guardedPops.clear();
    dialogPops.clear();
    installPlatformMock();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('N1: dialog on the root navigator, branch at its root', () {
    androidTest('back closes the dialog instead of leaving the app', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      final dialog = openRootDialog(tester);
      await tester.pumpAndSettle();
      expect(find.text('test dialog'), findsOneWidget);
      // N4: the framework can handle back while the dialog is open.
      expect(reportedHandlesBack.last, isTrue);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('test dialog'), findsNothing);
      expect(await dialog, isNull);
      expect(dialogPops, [true]);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(router.location, Uri.parse('/a'));
      // Back at the root of the branch: the next back leaves the app.
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('the back gesture closes the dialog', (tester) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      final dialog = openRootDialog(tester);
      await tester.pumpAndSettle();
      expect(reportedHandlesBack.last, isTrue);

      await performBackGesture(tester);

      expect(find.text('test dialog'), findsNothing);
      expect(await dialog, isNull);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('a canceled gesture leaves the dialog open', (tester) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      final dialog = openRootDialog(tester);
      await tester.pumpAndSettle();
      final before = reportedHandlesBack.last;
      expect(before, isTrue);

      await performBackGesture(tester, cancel: true);

      expect(find.text('test dialog'), findsOneWidget);
      // Still open: the future has not completed.
      var done = false;
      unawaited(dialog.then((_) => done = true));
      await tester.pump();
      expect(done, isFalse);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, before);
    });

    androidTest('a PopScope in the dialog is respected', (tester) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      openRootDialog(tester, canPop: false);
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('test dialog'), findsOneWidget);
      expect(dialogPops, [false]);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isTrue);
    });
  });

  group('N2: bottom sheet / menu on the branch navigator', () {
    androidTest('back closes a bottom sheet at the branch root', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      final sheet = openBranchSheet(tester);
      await tester.pumpAndSettle();
      expect(find.text('test sheet'), findsOneWidget);
      expect(reportedHandlesBack.last, isTrue);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('test sheet'), findsNothing);
      expect(await sheet, isNull);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('the back gesture closes a bottom sheet', (tester) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      final sheet = openBranchSheet(tester);
      await tester.pumpAndSettle();

      await performBackGesture(tester);

      expect(find.text('test sheet'), findsNothing);
      expect(await sheet, isNull);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
    });

    androidTest('back closes a popup menu at the branch root', (tester) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      final menu = openBranchMenu(tester);
      await tester.pumpAndSettle();
      expect(find.text('menu item'), findsOneWidget);
      expect(reportedHandlesBack.last, isTrue);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('menu item'), findsNothing);
      expect(await menu, isNull);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });
  });

  group('N3: dialog on the root navigator over a deeper branch', () {
    androidTest('back closes the dialog, not the page below it', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      await router.open(const ADetailRoute(id: '7'));
      await tester.pumpAndSettle();
      final dialog = openRootDialog(tester, from: 'a detail 7');
      await tester.pumpAndSettle();
      expect(reportedHandlesBack.last, isTrue);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('test dialog'), findsNothing);
      expect(await dialog, isNull);
      expect(router.stack, [
        const ShellMain(),
        const TabARoute(),
        const ADetailRoute(id: '7'),
      ]);
      expect(router.location, Uri.parse('/a/detail?id=7'));
      expect(reportedHandlesBack.last, isTrue);

      // A second back now goes one page back inside the branch.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('the back gesture closes the dialog, not the page below it', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      await router.open(const ADetailRoute(id: '7'));
      await tester.pumpAndSettle();
      final dialog = openRootDialog(tester, from: 'a detail 7');
      await tester.pumpAndSettle();

      await performBackGesture(tester);

      expect(find.text('test dialog'), findsNothing);
      expect(await dialog, isNull);
      expect(router.stack, [
        const ShellMain(),
        const TabARoute(),
        const ADetailRoute(id: '7'),
      ]);
      expect(router.location, Uri.parse('/a/detail?id=7'));
      expect(reportedHandlesBack.last, isTrue);
    });
  });

  group('variants', () {
    androidTest('dialog above a full-screen overlay: the dialog goes first', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      router.push<String>(const PickerRoute());
      await tester.pumpAndSettle();
      final dialog = openRootDialog(tester);
      await tester.pumpAndSettle();
      expect(find.text('test dialog'), findsOneWidget);
      expect(reportedHandlesBack.last, isTrue);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('test dialog'), findsNothing);
      expect(await dialog, isNull);
      expect(router.stack, [
        const ShellMain(),
        const TabARoute(),
        const PickerRoute(),
      ]);

      // The overlay is still there and goes next.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('a bottom sheet under an overlay is not closed first', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      openBranchSheet(tester);
      await tester.pumpAndSettle();
      router.push<String>(const PickerRoute());
      await tester.pumpAndSettle();

      // Back removes the overlay that is on top, not the sheet below it.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(find.text('test sheet'), findsOneWidget);

      // The sheet is now the top of the branch and goes next.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('test sheet'), findsNothing);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('a dialog does not touch a hidden tab with pages', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      await tapKey(tester, 'tab-1');
      await router.open(const BDetailRoute(id: '2'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'tab-0');
      final dialog = openRootDialog(tester);
      await tester.pumpAndSettle();
      expect(reportedHandlesBack.last, isTrue);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('test dialog'), findsNothing);
      expect(await dialog, isNull);
      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);

      await tapKey(tester, 'tab-1');
      expect(router.stack, [
        const ShellMain(),
        const TabBRoute(),
        const BDetailRoute(id: '2'),
      ]);
    });

    androidTest('a dialog over a shell with ancestors below closes first', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester, initial: const LandingShell());
      final dialog = openRootDialog(tester, from: 'landing tab');
      await tester.pumpAndSettle();
      expect(reportedHandlesBack.last, isTrue);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('test dialog'), findsNothing);
      expect(await dialog, isNull);
      expect(router.stack, [
        const LandingRoute(),
        const LandingShell(),
        const LandingTabRoute(),
      ]);
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('a PopScope in a branch page is respected', (tester) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester);
      await router.open(const GuardedDetailRoute());
      await tester.pumpAndSettle();
      expect(router.stack, [
        const ShellMain(),
        const TabARoute(),
        const GuardedDetailRoute(),
      ]);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(guardedPops, [false]);
      expect(router.stack, [
        const ShellMain(),
        const TabARoute(),
        const GuardedDetailRoute(),
      ]);
      expect(reportedHandlesBack.last, isTrue);
    });
  });

  group('without a shell', () {
    androidTest('a dialog still closes on back, stack untouched', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpShellApp(tester, initial: const LoginRoute());
      final dialog = openRootDialog(tester, from: 'login');
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('test dialog'), findsNothing);
      expect(await dialog, isNull);
      expect(router.stack, [const LoginRoute()]);

      // And the back gesture closes a dialog too.
      openRootDialog(tester, from: 'login');
      await tester.pumpAndSettle();
      await performBackGesture(tester);
      expect(find.text('test dialog'), findsNothing);
      expect(router.stack, [const LoginRoute()]);
    });
  });
}
