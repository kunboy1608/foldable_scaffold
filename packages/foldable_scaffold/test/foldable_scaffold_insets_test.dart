import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// The insets a pane sees.
class _Insets {
  EdgeInsets padding = EdgeInsets.zero;
  EdgeInsets viewInsets = EdgeInsets.zero;
}

/// Pumps a [FoldableScaffold] in a window of [size] with a system inset of
/// [systemBottom] at the bottom (a gesture bar), and says what the body and the
/// secondary body see in [body] and [secondary].
Future<void> _pump(
  WidgetTester tester,
  Size size, {
  required _Insets body,
  _Insets? secondary,
  double systemBottom = 34,
  double keyboard = 0,
  bool extendBody = true,
  bool withBottomNavigation = true,
  bool withNavigation = true,
  bool withAppBar = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(bottom: systemBottom);
  tester.view.padding = FakeViewPadding(
    bottom: (systemBottom - keyboard).clamp(0, double.infinity),
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      home: FoldableScaffold(
        extendBody: extendBody,
        hasSecondaryBody: secondary != null,
        topNavigationBuilder: withAppBar
            ? (_, _) => AppBar(title: const Text('title'))
            : null,
        primaryNavigationBuilder: withNavigation
            ? (_, _, _) => const SizedBox.expand()
            : null,
        bottomNavigationBuilder: withBottomNavigation
            ? (_, _) => const SizedBox(height: 80)
            : null,
        bodyBuilder: (context, _) {
          body
            ..padding = MediaQuery.paddingOf(context)
            ..viewInsets = MediaQuery.viewInsetsOf(context);
          return const SizedBox.expand();
        },
        secondaryBodyBuilder: secondary == null
            ? null
            : (context, _) {
                secondary
                  ..padding = MediaQuery.paddingOf(context)
                  ..viewInsets = MediaQuery.viewInsetsOf(context);
                return const SizedBox.expand();
              },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const compact = Size(400, 800);
  const wide = Size(1400, 800);

  group('the bottom navigation bar', () {
    testWidgets('extendBody: the panes pad for the bar', (tester) async {
      final body = _Insets();
      await _pump(tester, compact, body: body);

      expect(body.padding.bottom, 80);
    });

    testWidgets('extendBody false: the body ends above the bar', (
      tester,
    ) async {
      final body = _Insets();
      await _pump(tester, compact, body: body, extendBody: false);

      // The bar sits on the system inset: nothing is left to pad for.
      expect(body.padding.bottom, 0);
    });

    testWidgets('the secondary body pads for it too', (tester) async {
      final body = _Insets();
      final secondary = _Insets();
      await _pump(tester, compact, body: body, secondary: secondary);

      expect(secondary.padding.bottom, 80);
    });
  });

  group('without the bottom navigation bar', () {
    testWidgets('the rail replaces it, the panes keep the system inset', (
      tester,
    ) async {
      final body = _Insets();
      await _pump(tester, wide, body: body);
      expect(body.padding.bottom, 34);

      await _pump(tester, wide, body: body, extendBody: false);
      expect(body.padding.bottom, 34);
    });

    testWidgets('no builder: the panes keep the system inset', (tester) async {
      final body = _Insets();
      await _pump(tester, compact, body: body, withBottomNavigation: false);

      expect(body.padding.bottom, 34);
    });
  });

  group('the keyboard', () {
    testWidgets('is consumed once: the body is resized, not padded again', (
      tester,
    ) async {
      final body = _Insets();
      final secondary = _Insets();
      await _pump(
        tester,
        wide,
        body: body,
        secondary: secondary,
        keyboard: 300,
        withNavigation: false,
        withBottomNavigation: false,
      );

      expect(body.viewInsets.bottom, 0);
      expect(secondary.viewInsets.bottom, 0);
    });
  });

  group('the app bar', () {
    testWidgets('takes the top inset, the bar the bottom one', (tester) async {
      final body = _Insets();
      await _pump(tester, compact, body: body, withAppBar: true);

      expect(body.padding.top, 0);
      expect(body.padding.bottom, 80);
    });
  });
}
