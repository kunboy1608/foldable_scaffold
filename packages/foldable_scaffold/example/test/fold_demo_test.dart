import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodCall, SystemChannels;
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

  testWidgets('a simulated horizontal hinge stacks the panes', (tester) async {
    // A desktop window this wide shows one pane.
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();
    expect(find.text('one pane'), findsOneWidget);

    await tester.tap(find.byTooltip('Pretend the device has a fold'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Hinge, horizontal (two screens stacked)'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('separating fold at 350'), findsOneWidget);
    expect(find.text('two panes, stacked'), findsOneWidget);
    // The body is above the secondary body.
    expect(
      tester.getRect(find.byKey(const Key('body_builder'))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('secondary_body_builder'))).top,
      ),
    );
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

  testWidgets('the platform data dialog says the scope only works on iOS', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Platform data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('the scope only works on iOS'), findsOneWidget);
    expect(find.textContaining('MediaQuery.displayFeatures'), findsOneWidget);
  }, variant: desktop);

  testWidgets('the platform data dialog copies the data with the pose', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Platform data'));
    await tester.pumpAndSettle();

    // Without a pose, the text is the data.
    await tester.tap(find.byKey(const Key('platform_data_copy')));
    await tester.pumpAndSettle();
    expect(copied, hasLength(1));
    expect(copied.single, startsWith('platform: '));
    expect(copied.single, contains('MediaQuery.size: 1400.00 x 700.00'));
    expect(find.text('Copied'), findsOneWidget);

    // With one, it goes on top, and the button asks to be pressed again.
    await tester.enterText(
      find.byKey(const Key('platform_data_pose')),
      'outer display',
    );
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.byKey(const Key('platform_data_copy')));
    await tester.pumpAndSettle();
    expect(copied, hasLength(2));
    expect(copied.last, startsWith('pose: outer display\nplatform: '));
  }, variant: desktop);
}
