import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Key, Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold_example/main.dart';

void main() {
  // A desktop platform: the default rules need 1200 wide for two panes.
  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('a simulated hinge puts a pane on each screen', (tester) async {
    // A desktop window this wide shows one pane.
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();
    expect(find.text('no fold'), findsOneWidget);
    expect(find.text('one pane'), findsOneWidget);

    await tester.tap(find.byTooltip('Pretend the device has a fold'));
    await tester.pumpAndSettle();
    // The popup menu animates in a transform the finder does not follow; the
    // expectations below show the tap landed.
    await tester.tap(find.text('Hinge (two screens)'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('separating fold at 500'), findsOneWidget);
    expect(find.text('two panes'), findsOneWidget);
  }, variant: desktop);

  testWidgets('a flat fold needs the phone and tablet rules to split', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.tap(find.byTooltip('Pretend the device has a fold'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fold, flat'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('flat fold at 450'), findsOneWidget);
    expect(find.text('one pane'), findsOneWidget);

    await tester.tap(find.byTooltip('Pretend the device has a fold'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining('Phone and tablet rules'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('two panes'), findsOneWidget);
  }, variant: desktop);

  testWidgets('the divider snaps to 360 when released near it', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();

    // The drag loses the touch slop, so the message pane ends near 380.
    await tester.drag(
      find.byKey(const Key('pane_divider')),
      const Offset(340, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('This pane is 360 wide.'), findsOneWidget);
  }, variant: desktop);

  testWidgets('the compose button opens the sheet, and Send closes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsNothing);

    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsOneWidget);
    expect(find.text('Compose'), findsNothing);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsNothing);
    expect(find.text('Message sent'), findsOneWidget);
  }, variant: desktop);

  testWidgets('the drawers open from the app bar', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Layout options'));
    await tester.pumpAndSettle();
    expect(find.text('Layout options'), findsOneWidget);

    // Turning snapping off is applied to the scaffold behind the drawer.
    await tester.tap(find.text('Snap to 360 and 412'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();
    expect(find.text('Layout options'), findsNothing);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Mail'), findsOneWidget);
  }, variant: desktop);
}
