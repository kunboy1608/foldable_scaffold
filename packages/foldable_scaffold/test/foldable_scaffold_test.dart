import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps a [FoldableScaffold] in a window of exactly [size].
Future<void> _pumpScaffold(
  WidgetTester tester,
  Size size, {
  bool focusOnPrimaryBody = false,
  bool secondary = false,
  bool withNavigation = false,
  double minBodySize = 200.0,
  ValueListenable<bool>? paneTransition,
  PopInvokedWithResultCallback<dynamic>? onSecondBodyClose,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: FoldableScaffold(
        focusOnPrimaryBody: focusOnPrimaryBody,
        minBodySize: minBodySize,
        paneTransition: paneTransition,
        onSecondBodyClose: onSecondBodyClose,
        bodyBuilder: (_, _) => const Text('body'),
        secondaryBodyBuilder: secondary
            ? (_, _) => const Text('secondary')
            : null,
        primaryNavigationBuilder: withNavigation
            ? (context, constraints, padding) =>
                  const SizedBox(width: 80, child: Text('rail'))
            : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _paneWidth(WidgetTester tester, String key) {
  return tester.getSize(find.byKey(Key(key), skipOffstage: false)).width;
}

FoldablePaneLayout _layout(WidgetTester tester) {
  return tester.widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout));
}

void main() {
  testWidgets('shows the secondary body alone below 1200', (tester) async {
    await _pumpScaffold(tester, const Size(800, 600), secondary: true);

    expect(_paneWidth(tester, 'body_builder'), 0);
    expect(_paneWidth(tester, 'secondary_body_builder'), 800);
    expect(_layout(tester).primaryVisible, isFalse);
    expect(_layout(tester).secondaryVisible, isTrue);
    expect(
      tester
          .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
          .canSplit,
      isFalse,
    );
  });

  testWidgets('keeps the body when focusOnPrimaryBody is true', (tester) async {
    await _pumpScaffold(
      tester,
      const Size(800, 600),
      secondary: true,
      focusOnPrimaryBody: true,
    );

    expect(_paneWidth(tester, 'body_builder'), 800);
    expect(_paneWidth(tester, 'secondary_body_builder'), 0);
  });

  testWidgets('shows both panes from 1200 with a secondary body', (
    tester,
  ) async {
    await _pumpScaffold(tester, const Size(1400, 600), secondary: true);

    expect(_paneWidth(tester, 'body_builder'), greaterThan(0));
    expect(_paneWidth(tester, 'secondary_body_builder'), greaterThan(0));
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);
    expect(
      tester
          .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
          .canSplit,
      isTrue,
    );
  });

  testWidgets('splits the panes at exactly 1200, not below', (tester) async {
    await _pumpScaffold(tester, const Size(1199, 600), secondary: true);

    expect(_paneWidth(tester, 'body_builder'), 0);
    expect(_paneWidth(tester, 'secondary_body_builder'), 1199);
    expect(
      tester
          .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
          .canSplit,
      isFalse,
    );

    await _pumpScaffold(tester, const Size(1200, 600), secondary: true);

    expect(_paneWidth(tester, 'body_builder'), greaterThanOrEqualTo(200));
    expect(
      _paneWidth(tester, 'secondary_body_builder'),
      greaterThanOrEqualTo(200),
    );
    expect(
      _paneWidth(tester, 'body_builder') +
          _paneWidth(tester, 'pane_divider') +
          _paneWidth(tester, 'secondary_body_builder'),
      closeTo(1200, 0.01),
    );
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);
    expect(
      tester
          .widget<FoldableScaffoldScope>(find.byType(FoldableScaffoldScope))
          .canSplit,
      isTrue,
    );
  });

  testWidgets('the divider stops at both edges and can be dragged back', (
    tester,
  ) async {
    await _pumpScaffold(tester, const Size(1400, 600), secondary: true);
    final divider = find.byKey(const Key('pane_divider'));

    // Far past the left edge: the body keeps minBodySize.
    await tester.drag(divider, const Offset(-5000, 0));
    await tester.pumpAndSettle();
    expect(_paneWidth(tester, 'body_builder'), closeTo(200, 0.01));
    expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(1176, 0.01));
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);

    // Far past the right edge: the secondary body keeps minBodySize.
    await tester.drag(divider, const Offset(5000, 0));
    await tester.pumpAndSettle();
    expect(_paneWidth(tester, 'body_builder'), closeTo(1176, 0.01));
    expect(_paneWidth(tester, 'secondary_body_builder'), closeTo(200, 0.01));
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);

    // No dead zone: the divider follows the pointer from the edge.
    await tester.drag(divider, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(_paneWidth(tester, 'secondary_body_builder'), greaterThan(300));
    expect(_layout(tester).primaryVisible, isTrue);
    expect(_layout(tester).secondaryVisible, isTrue);
  });

  testWidgets('a pane narrower than minBodySize collapses into the other', (
    tester,
  ) async {
    // Two panes of 800 do not fit in 1400, so the body gives way.
    await _pumpScaffold(
      tester,
      const Size(1400, 600),
      secondary: true,
      minBodySize: 800,
    );

    expect(_paneWidth(tester, 'body_builder'), 0);
    expect(_paneWidth(tester, 'pane_divider'), 0);
    expect(_paneWidth(tester, 'secondary_body_builder'), 1400);
    expect(_layout(tester).primaryVisible, isFalse);
    expect(_layout(tester).secondaryVisible, isTrue);
  });

  testWidgets('calls onSecondBodyClose on back with a secondary body', (
    tester,
  ) async {
    final closed = <bool>[];
    await _pumpScaffold(
      tester,
      const Size(800, 600),
      secondary: true,
      onSecondBodyClose: (didPop, _) => closed.add(didPop),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(closed, [false]);
  });

  testWidgets('shows the navigation rail from 600', (tester) async {
    await _pumpScaffold(tester, const Size(500, 600), withNavigation: true);
    expect(find.text('rail'), findsNothing);

    await _pumpScaffold(tester, const Size(800, 600), withNavigation: true);
    expect(find.text('rail'), findsOneWidget);
    // The rail takes room from the body.
    expect(_paneWidth(tester, 'body_builder'), lessThan(800));
  });

  testWidgets('reads an explicit paneTransition signal', (tester) async {
    final transition = ValueNotifier(false);
    addTearDown(transition.dispose);

    await _pumpScaffold(
      tester,
      const Size(800, 600),
      paneTransition: transition,
    );
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('hasSecondaryBody skips probing the builder', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<int> pumpWith({required bool? hasSecondaryBody}) async {
      var calls = 0;
      // Start from an empty tree so both runs build from scratch.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: FoldableScaffold(
            hasSecondaryBody: hasSecondaryBody,
            bodyBuilder: (_, _) => const Text('body'),
            secondaryBodyBuilder: (_, _) {
              calls++;
              return const Text('secondary');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calls;
    }

    final probed = await pumpWith(hasSecondaryBody: null);
    final flagged = await pumpWith(hasSecondaryBody: true);

    // One call to probe for null plus one to build the pane, or only the latter.
    expect(probed, 2);
    expect(flagged, 1);
    expect(find.text('secondary'), findsOneWidget);
  });

  testWidgets('hasSecondaryBody false hides the secondary pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: FoldableScaffold(
          hasSecondaryBody: false,
          bodyBuilder: (_, _) => const Text('body'),
          secondaryBodyBuilder: (_, _) => const Text('secondary'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_paneWidth(tester, 'body_builder'), 800);
    expect(_paneWidth(tester, 'secondary_body_builder'), 0);
  });
}
