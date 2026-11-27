import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Records the smallest non-zero width the content of a pane is laid out at.
class _WidthProbe extends StatelessWidget {
  const _WidthProbe({required this.onWidth, required this.child});

  final ValueChanged<double> onWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      onWidth(constraints.maxWidth);
      return child;
    },
  );
}

void main() {
  testWidgets(
    'a collapsing pane is never laid out narrower than minBodySize',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(tester.view.reset);

      var narrowest = double.infinity;
      void record(double width) {
        if (width > 0 && width < narrowest) narrowest = width;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: FoldableScaffold(
            breakpoints: const FoldableBreakpoints(split: 840),
            body: _WidthProbe(
              onWidth: record,
              child: Scaffold(
                appBar: AppBar(title: const Text('Users')),
                body: ListView(
                  children: const [
                    ListTile(
                      leading: CircleAvatar(radius: 20),
                      title: Text('User 1'),
                      subtitle: Text('Open the user'),
                    ),
                  ],
                ),
              ),
            ),
            secondaryBody: const Center(child: Text('detail')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag the window narrower over many frames, as a desktop window is.
      for (var i = 1; i <= 20; i++) {
        tester.view.physicalSize = Size(1280 - 880 * i / 20, 720);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(narrowest, greaterThanOrEqualTo(200));
      expect(find.text('detail'), findsOneWidget);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'a collapsing body slides out on the outer side ($direction)',
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1280, 720);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                Directionality(textDirection: direction, child: child!),
            home: const FoldableScaffold(
              breakpoints: FoldableBreakpoints(split: 840),
              body: SizedBox.expand(key: Key('body')),
              secondaryBody: SizedBox.expand(key: Key('secondary')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // One pane from now on: the body animates out.
        tester.view.physicalSize = const Size(800, 720);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final Rect body = tester.getRect(find.byKey(const Key('body')));
        final Rect secondary = tester.getRect(
          find.byKey(const Key('secondary')),
        );
        // Mid-way: the body keeps its minimum width and touches the secondary
        // body on the side of the divider, overflowing past the outer edge.
        expect(body.width, 200);
        if (direction == TextDirection.ltr) {
          expect(body.left, lessThan(0));
          expect(body.right, lessThanOrEqualTo(secondary.left));
        } else {
          expect(body.right, greaterThan(800));
          expect(body.left, greaterThanOrEqualTo(secondary.right));
        }

        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(const Key('body'))).width, 0);
        expect(tester.getRect(find.byKey(const Key('secondary'))).width, 800);
      },
    );
  }
}
