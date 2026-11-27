import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show EditableText, EditableTextState, Key, MediaQuery, Size;
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

  testWidgets('two panes: the search field of the list keeps the focus while '
      'the keyboard slides up, and filters the messages', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ScaffoldExample());
    await tester.pumpAndSettle();
    expect(find.text('two panes'), findsOneWidget);

    final search = find.byKey(const Key('search'));
    EditableTextState field() => tester.state<EditableTextState>(
      find.descendant(of: search, matching: find.byType(EditableText)),
    );
    await tester.tap(search);
    await tester.pump();
    final first = field();
    for (var i = 1; i <= 8; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: 35.0 * i);
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(field(), first), isTrue, reason: 'frame $i');
      expect(first.widget.focusNode.hasFocus, isTrue, reason: 'frame $i');
    }
    await tester.pumpAndSettle();

    await tester.enterText(search, 'third');
    await tester.pump();
    expect(find.text('A third one'), findsOneWidget);
    expect(find.text('A second one'), findsNothing);
  }, variant: desktop);
}
