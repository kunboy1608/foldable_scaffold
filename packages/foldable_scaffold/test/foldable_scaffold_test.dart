// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
  ValueListenable<bool>? paneTransition,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: FoldableScaffold(
        focusOnPrimaryBody: focusOnPrimaryBody,
        paneTransition: paneTransition,
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
}
