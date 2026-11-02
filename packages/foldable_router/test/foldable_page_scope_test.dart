import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// A counter that restores its value under the id `count`. Every page uses the
/// same ids, so only the restoration scope of each page keeps them apart.
class _Counter extends StatefulWidget {
  const _Counter(this.name);

  final String name;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> with RestorationMixin {
  final _count = RestorableInt(0);

  @override
  String? get restorationId => 'counter';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_count, 'count');
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _count.value++),
        child: Text('${widget.name}: ${_count.value}'),
      ),
    );
  }
}

FoldablePage<void> _page(String name, {String? restorationId}) {
  return FoldablePage<void>(
    name: '/$name',
    restorationId: restorationId,
    child: _Counter(name),
  );
}

enum _Kind { stack, split }

Widget _app(_Kind kind, FoldableNavigatorController controller) {
  if (kind == _Kind.stack) {
    return MaterialApp(
      restorationScopeId: 'app',
      home: FoldableNavigator.stack(controller: controller),
    );
  }
  return MaterialApp(
    restorationScopeId: 'app',
    home: FoldableNavigator(
      controller: controller,
      builder: (context, body, secondary) => FoldableScaffold(
        bodyBuilder: (_, _) => body,
        secondaryBodyBuilder: (_, _) => secondary,
        hasSecondaryBody: secondary != null,
      ),
    ),
  );
}

void main() {
  for (final kind in _Kind.values) {
    group('${kind.name} navigator', () {
      testWidgets('a page with a restorationId restores its state', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([
          _page('detail', restorationId: 'detail'),
        ]);
        await tester.pumpWidget(_app(kind, controller));
        await tester.tap(find.text('detail: 0'));
        await tester.pump();
        await tester.tap(find.text('detail: 1'));
        await tester.pump();
        expect(find.text('detail: 2'), findsOneWidget);

        await tester.restartAndRestore();

        expect(find.text('detail: 2'), findsOneWidget);
      });

      testWidgets('every page has its own restoration scope', (tester) async {
        final controller = FoldableNavigatorController.single([
          _page('first', restorationId: 'first'),
        ]);
        await tester.pumpWidget(_app(kind, controller));
        await tester.tap(find.text('first: 0'));
        await tester.pump();

        controller.push(_page('second', restorationId: 'second'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('second: 0'));
        await tester.pump();
        await tester.tap(find.text('second: 1'));
        await tester.pump();
        expect(find.text('second: 2'), findsOneWidget);

        await tester.restartAndRestore();

        expect(find.text('second: 2'), findsOneWidget);
        // The split navigator keeps the first page mounted, so it still has
        // its own value. The stack navigator unmounted it, which drops what
        // it saved: it starts again.
        controller.pop();
        await tester.pumpAndSettle();
        expect(
          find.text(kind == _Kind.split ? 'first: 1' : 'first: 0'),
          findsOneWidget,
        );
      });

      testWidgets('pages without a restorationId still work', (tester) async {
        final controller = FoldableNavigatorController.single([_page('body')]);
        await tester.pumpWidget(_app(kind, controller));

        controller.push(_page('detail', restorationId: 'detail'));
        await tester.pumpAndSettle();
        controller.pop();
        await tester.pumpAndSettle();

        expect(find.text('body: 0'), findsOneWidget);
      });
    });
  }
}
