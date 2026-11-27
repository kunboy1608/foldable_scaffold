import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Key, MediaQuery, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold_example/main.dart';

void main() {
  // A desktop platform: the default rules need 1200 wide for two panes.
  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);
  const keyboard = 300.0;

  for (final size in const [Size(1400, 800), Size(500, 800)]) {
    testWidgets(
      'the on-screen keyboard does not cover the reply field (${size.width})',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const ScaffoldExample());
        await tester.pumpAndSettle();

        final reply = find.byKey(const Key('reply'));
        await tester.tap(reply);
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(reply).bottom,
          lessThanOrEqualTo(size.height - keyboard),
        );
        // The pane got the room left by the keyboard, not the inset again.
        expect(MediaQuery.viewInsetsOf(tester.element(reply)).bottom, 0);
      },
      variant: desktop,
    );
  }

  testWidgets('the compose sheet stays above the on-screen keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const Key('compose'))).bottom,
      lessThanOrEqualTo(800 - keyboard),
    );
  }, variant: desktop);
}
