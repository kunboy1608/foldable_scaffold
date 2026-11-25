import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

double _paneWidth(WidgetTester tester, String key) {
  return tester.getSize(find.byKey(Key(key), skipOffstage: false)).width;
}

/// Samples the pane widths for [frames] frames of [step], without settling.
Future<List<(double, double)>> _sampleWidths(
  WidgetTester tester, {
  required int frames,
  Duration step = const Duration(milliseconds: 16),
}) async {
  final samples = <(double, double)>[];
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
    samples.add((
      _paneWidth(tester, 'body_builder'),
      _paneWidth(tester, 'secondary_body_builder'),
    ));
  }
  return samples;
}

bool _sawMidWidth(List<(double, double)> samples, double full) {
  return samples.any(
    (pair) => pair.$1 > 0 && pair.$1 < full && pair.$2 > 0 && pair.$2 < full,
  );
}

void main() {
  testWidgets(
    'FoldablePaneTransitionScope snaps the pane switch with no mid widths',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final transitions = FoldablePaneTransitions()..begin();
      addTearDown(transitions.dispose);

      var hasSecondary = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: FoldablePaneTransitionScope(
            transitions: transitions,
            child: StatefulBuilder(
              builder: (context, setState) {
                return FoldableScaffold(
                  // Keep the default 250 ms so a missing snap would show mids.
                  paneAnimationDuration: const Duration(milliseconds: 250),
                  hasSecondaryBody: hasSecondary,
                  body: const Text('body'),
                  secondaryBody: const Text('secondary'),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => setState(() => hasSecondary = true),
                    child: const Icon(Icons.add),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_paneWidth(tester, 'body_builder'), 800);
      expect(_paneWidth(tester, 'secondary_body_builder'), 0);

      await tester.tap(find.byType(FloatingActionButton));
      // One frame to apply the new pose; then sample during what would be the
      // animation. With the transition scope active every sample must already
      // be the final single-pane layout (secondary full, body zero).
      await tester.pump();
      final samples = await _sampleWidths(tester, frames: 8);

      for (final (body, secondary) in samples) {
        expect(body, 0, reason: 'body mid width $body with snap');
        expect(
          secondary,
          800,
          reason: 'secondary mid width $secondary with snap',
        );
      }
    },
  );

  testWidgets(
    'FoldableScaffold.paneTransition true also snaps the pane switch',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final transition = ValueNotifier(true);
      addTearDown(transition.dispose);

      var hasSecondary = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: StatefulBuilder(
            builder: (context, setState) {
              return FoldableScaffold(
                paneTransition: transition,
                paneAnimationDuration: const Duration(milliseconds: 250),
                hasSecondaryBody: hasSecondary,
                body: const Text('body'),
                secondaryBody: const Text('secondary'),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => hasSecondary = true),
                  child: const Icon(Icons.add),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      final samples = await _sampleWidths(tester, frames: 8);

      for (final (body, secondary) in samples) {
        expect(body, 0);
        expect(secondary, 800);
      }
    },
  );

  testWidgets(
    'closing the secondary pane in a split animates through mid widths',
    (tester) async {
      // Split → single changes `_wasSinglePane`, so snapPanes stays false and
      // the panes animate. (A single-pane visibility swap always snaps, with
      // or without a transition signal, because primaryVisible changes.)
      tester.view.physicalSize = const Size(1400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var hasSecondary = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: StatefulBuilder(
            builder: (context, setState) {
              return FoldableScaffold(
                paneAnimationDuration: const Duration(milliseconds: 250),
                hasSecondaryBody: hasSecondary,
                body: const Text('body'),
                secondaryBody: const Text('secondary'),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => hasSecondary = false),
                  child: const Icon(Icons.close),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_paneWidth(tester, 'body_builder'), greaterThan(0));
      expect(_paneWidth(tester, 'secondary_body_builder'), greaterThan(0));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      final samples = await _sampleWidths(tester, frames: 8);

      expect(
        _sawMidWidth(samples, 1400),
        isTrue,
        reason: 'split → single should animate through mid widths',
      );
    },
  );
}
