import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A custom page that implements [FoldablePageContent] with its own route.
class _FadePage<T> extends Page<T> implements FoldablePageContent {
  const _FadePage({required this.child, super.key, super.name});

  @override
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(settings: this, pageBuilder: (_, _, _) => child);
  }
}

/// A page type the navigators do not know.
class _UnsupportedPage extends Page<void> {
  const _UnsupportedPage({super.name});

  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder<void>(
      settings: this,
      pageBuilder: (_, _, _) => const Text('unsupported'),
    );
  }
}

Widget _splitApp(FoldableNavigatorController controller) {
  return MaterialApp(
    home: FoldableScaffoldScope(
      canSplit: true,
      child: FoldablePaneLayout(
        primaryVisible: true,
        secondaryVisible: true,
        child: FoldableNavigator(
          controller: controller,
          builder: (context, body, secondary) => Column(
            children: [
              Expanded(child: body),
              if (secondary != null) Expanded(child: secondary),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _stackApp(FoldableNavigatorController controller) {
  return MaterialApp(home: FoldableNavigator.stack(controller: controller));
}

void main() {
  group('split navigator', () {
    testWidgets('shows a custom page that implements FoldablePageContent', (
      tester,
    ) async {
      final controller = FoldableNavigatorController.single([
        const _FadePage<void>(name: '/a', child: Text('custom a')),
        const _FadePage<void>(name: '/b', child: Text('custom b')),
      ]);

      await tester.pumpWidget(_splitApp(controller));

      expect(find.text('custom a'), findsOneWidget);
      expect(find.text('custom b'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows CupertinoPage and MaterialPage', (tester) async {
      final controller = FoldableNavigatorController.single([
        const CupertinoPage<void>(name: '/a', child: Text('cupertino')),
        const MaterialPage<void>(name: '/b', child: Text('material')),
      ]);

      await tester.pumpWidget(_splitApp(controller));

      expect(find.text('cupertino'), findsOneWidget);
      expect(find.text('material'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports an unsupported page type', (tester) async {
      final controller = FoldableNavigatorController.single([
        const _UnsupportedPage(name: '/a'),
      ]);

      await tester.pumpWidget(_splitApp(controller));

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      final message = (error as FlutterError).toString();
      expect(message, contains('_UnsupportedPage'));
      expect(message, contains('FoldablePageContent'));
      expect(message, contains('CupertinoPage'));
    });
  });

  group('stack navigator', () {
    testWidgets('shows a custom page that implements FoldablePageContent', (
      tester,
    ) async {
      final controller = FoldableNavigatorController.single([
        const _FadePage<void>(name: '/a', child: Text('custom a')),
      ]);

      await tester.pumpWidget(_stackApp(controller));
      expect(find.text('custom a'), findsOneWidget);

      controller.push(
        const _FadePage<void>(name: '/b', child: Text('custom b')),
      );
      await tester.pumpAndSettle();

      expect(find.text('custom b'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows CupertinoPage and MaterialPage', (tester) async {
      final controller = FoldableNavigatorController.single([
        const CupertinoPage<void>(name: '/a', child: Text('cupertino')),
      ]);

      await tester.pumpWidget(_stackApp(controller));
      expect(find.text('cupertino'), findsOneWidget);

      controller.push(
        const MaterialPage<void>(name: '/b', child: Text('material')),
      );
      await tester.pumpAndSettle();

      expect(find.text('material'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports an unsupported page type', (tester) async {
      final controller = FoldableNavigatorController.single([
        const _UnsupportedPage(name: '/a'),
      ]);

      await tester.pumpWidget(_stackApp(controller));

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      final message = (error as FlutterError).toString();
      expect(message, contains('_UnsupportedPage'));
      expect(message, contains('FoldablePageContent'));
    });
  });
}
