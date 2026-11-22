import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

/// Stands in for the transitions of a Material library other than
/// `package:flutter/material.dart` (`material_ui`): no SDK `Theme` anywhere.
class _RecordingTransitions extends PageTransitionsBuilder {
  _RecordingTransitions(this.log);
  final List<String> log;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    log.add(route.settings.name ?? '?');
    return FadeTransition(opacity: animation, child: child);
  }
}

class _Home extends FoldableFlatRoute {
  const _Home();
  @override
  String get segment => 'home';
  @override
  Widget build(BuildContext context) => const Text('home');
}

class _Detail extends FoldableFlatRoute {
  const _Detail();
  @override
  String get segment => 'detail';
  @override
  FoldableFlatRoute? get parent => const _Home();
  @override
  Widget build(BuildContext context) => const Text('detail');
}

void main() {
  testWidgets('pageTransitions drives the transitions without any SDK Theme '
      '(flat stack)', (tester) async {
    final log = <String>[];
    final router = FoldableRouter(
      initial: const _Home(),
      routes: const {},
      notFoundBuilder: (context, uri) => const Text('not found'),
      pageTransitions: (context) => _RecordingTransitions(log),
    );
    // WidgetsApp has no material Theme: reading one would throw or fall
    // back to the SDK's default light theme.
    await tester.pumpWidget(
      WidgetsApp.router(
        color: const Color(0xFF000000),
        routerConfig: router.routerConfig,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    log.clear();

    router.push(const _Detail());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Mid-transition: the custom builder is running (a fade) and the
    // route lasts 120 ms, not the default 300 ms.
    expect(log, contains('/home/detail'));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
    expect(find.text('detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
