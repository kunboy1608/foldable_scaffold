import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

import 'shell_route_test.dart';

/// The value of `SystemNavigator.setFrameworkHandlesBack` seen by the engine,
/// in order.
final List<bool> reportedHandlesBack = <bool>[];

void installPlatformMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          expect(call.arguments, isA<bool>());
          reportedHandlesBack.add(call.arguments! as bool);
        }
        return null;
      });
}

/// Puts the binding in the state of a running app: `WidgetsApp` only
/// forwards `NavigationNotification`s to the engine while the app is
/// `resumed` (or otherwise alive).
Future<void> resumeApp(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    const StringCodec().encodeMessage(AppLifecycleState.resumed.toString()),
    (ByteData? _) {},
  );
}

Future<void> _sendBackGesture(
  WidgetTester tester,
  String method, [
  Map<String, Object?>? arguments,
]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (ByteData? _) {},
  );
}

/// Sends the Android predictive back gesture on `flutter/backgesture` the
/// way the engine does, then commits (or cancels) it.
Future<void> performBackGesture(
  WidgetTester tester, {
  bool cancel = false,
}) async {
  await _sendBackGesture(tester, 'startBackGesture', <String, Object?>{
    'touchOffset': <double>[5.0, 300.0],
    'progress': 0.0,
    'swipeEdge': 0, // left
  });
  await tester.pump();
  await _sendBackGesture(tester, 'updateBackGestureProgress', <String, Object?>{
    'touchOffset': <double>[150.0, 300.0],
    'progress': 0.45,
    'swipeEdge': 0,
  });
  await tester.pump();
  await _sendBackGesture(
    tester,
    cancel ? 'cancelBackGesture' : 'commitBackGesture',
  );
  await tester.pumpAndSettle();
}

/// A widget test that runs with Android as the target platform, where the
/// default page transition is `PredictiveBackPageTransitionsBuilder`.
void androidTest(String description, WidgetTesterCallback callback) {
  testWidgets(
    description,
    callback,
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

Future<FoldableRouter> pumpApp(
  WidgetTester tester, {
  FoldableRoute initial = const ShellMain(),
}) async {
  final router = createShellRouter(initial: initial);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Builds the state where tab A shows [.., detail 7] and tab B, hidden,
/// shows [.., detail 2], then goes back to tab A.
Future<FoldableRouter> pumpTwoDeepTabs(WidgetTester tester) async {
  final router = await pumpApp(tester);
  await router.open(const ADetailRoute(id: '7'));
  await tester.pumpAndSettle();
  await tapKey(tester, 'tab-1');
  await router.open(const BDetailRoute(id: '2'));
  await tester.pumpAndSettle();
  await tapKey(tester, 'tab-0');
  expect(router.stack, [
    const ShellMain(),
    const TabARoute(),
    const ADetailRoute(id: '7'),
  ]);
  return router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    reportedHandlesBack.clear();
    installPlatformMock();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('A1: visible and hidden tab both have pages', () {
    androidTest('the gesture pops the visible tab only', (tester) async {
      await resumeApp(tester);
      final router = await pumpTwoDeepTabs(tester);
      reportedHandlesBack.clear();

      await performBackGesture(tester);

      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(router.location, Uri.parse('/a'));
      expect(reportedHandlesBack.last, isFalse);

      // The hidden tab kept its stack.
      await tapKey(tester, 'tab-1');
      expect(router.stack, [
        const ShellMain(),
        const TabBRoute(),
        const BDetailRoute(id: '2'),
      ]);
      expect(find.text('b detail 2'), findsOneWidget);
    });

    androidTest('a canceled gesture changes nothing', (tester) async {
      await resumeApp(tester);
      final router = await pumpTwoDeepTabs(tester);
      final before = reportedHandlesBack.last;
      expect(before, isTrue);

      await performBackGesture(tester, cancel: true);

      expect(router.stack, [
        const ShellMain(),
        const TabARoute(),
        const ADetailRoute(id: '7'),
      ]);
      expect(router.location, Uri.parse('/a/detail?id=7'));
      expect(reportedHandlesBack.last, before);

      await tapKey(tester, 'tab-1');
      expect(router.stack, [
        const ShellMain(),
        const TabBRoute(),
        const BDetailRoute(id: '2'),
      ]);
    });
  });

  group('A2: a full-screen overlay covers the branch', () {
    androidTest('the gesture removes the overlay only', (tester) async {
      await resumeApp(tester);
      final router = await pumpApp(tester);
      await router.open(const ADetailRoute(id: '7'));
      await tester.pumpAndSettle();
      final pushed = router.push<String>(const PickerRoute());
      await tester.pumpAndSettle();
      final before = reportedHandlesBack.last;
      expect(before, isTrue);

      await performBackGesture(tester);

      expect(await pushed, isNull);
      expect(router.stack, [
        const ShellMain(),
        const TabARoute(),
        const ADetailRoute(id: '7'),
      ]);
      expect(router.location, Uri.parse('/a/detail?id=7'));
      expect(find.text('picker'), findsNothing);
      // The branch below still has a page to go back to.
      expect(reportedHandlesBack.last, before);
    });
  });

  group('A3: the visible tab is at its root, the hidden tab is deep', () {
    androidTest('the gesture is not handled', (tester) async {
      await resumeApp(tester);
      final router = await pumpApp(tester);
      await tapKey(tester, 'tab-1');
      await router.open(const BDetailRoute(id: '2'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'tab-0');
      final before = reportedHandlesBack.last;
      expect(before, isFalse);

      await performBackGesture(tester);

      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(router.location, Uri.parse('/a'));
      expect(reportedHandlesBack.last, before);

      await tapKey(tester, 'tab-1');
      expect(router.stack, [
        const ShellMain(),
        const TabBRoute(),
        const BDetailRoute(id: '2'),
      ]);
      expect(find.text('b detail 2'), findsOneWidget);
    });
  });

  group('B: the signal reported to the platform', () {
    androidTest('closing an overlay while the branch has pages reports true', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpApp(tester);
      await router.open(const ADetailRoute(id: '7'));
      await tester.pumpAndSettle();
      router.push<String>(const PickerRoute());
      await tester.pumpAndSettle();
      expect(reportedHandlesBack.last, isTrue);

      router.pop();
      await tester.pumpAndSettle();

      expect(router.stack, [
        const ShellMain(),
        const TabARoute(),
        const ADetailRoute(id: '7'),
      ]);
      expect(reportedHandlesBack.last, isTrue);
    });

    androidTest('closing an overlay at the branch root reports false', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpApp(tester);
      router.push<String>(const PickerRoute());
      await tester.pumpAndSettle();
      expect(reportedHandlesBack.last, isTrue);

      router.pop();
      await tester.pumpAndSettle();

      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('the signal follows the visible tab', (tester) async {
      await resumeApp(tester);
      final router = await pumpApp(tester);
      await tapKey(tester, 'tab-1');
      await router.open(const BDetailRoute(id: '2'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'tab-0');
      expect(reportedHandlesBack.last, isFalse);

      await tapKey(tester, 'tab-1');
      expect(reportedHandlesBack.last, isTrue);

      await tapKey(tester, 'tab-0');
      expect(reportedHandlesBack.last, isFalse);
    });

    androidTest('popping inside the visible branch reports false at its root', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpApp(tester);
      await router.open(const ADetailRoute(id: '7'));
      await tester.pumpAndSettle();
      expect(reportedHandlesBack.last, isTrue);

      router.pop();
      await tester.pumpAndSettle();

      expect(router.stack, [const ShellMain(), const TabARoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });
  });

  group('D: branches do not interfere with the flat stack', () {
    androidTest('without a shell the flat stack keeps its own gesture', (
      tester,
    ) async {
      await resumeApp(tester);
      final router = await pumpApp(tester, initial: const LoginRoute());
      router.push<String>(const PickerRoute());
      await tester.pumpAndSettle();

      await performBackGesture(tester);

      expect(router.stack, [const LoginRoute()]);
      expect(reportedHandlesBack.last, isFalse);
    });
  });
}
