// Closing the secondary pane of a split scaffold: the body grows and the
// secondary body leaves, frame by frame, without anything jumping at the start
// or at the end of the animation.
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

const _destinations = [
  NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
  NavigationDestination(icon: Icon(Icons.send), label: 'Sent'),
];

/// How the app closes the secondary pane.
enum _Close {
  /// `hasSecondaryBody: false`, the secondary body still given.
  flag,

  /// `secondaryBody: null`.
  remove,
}

/// One frame of the animation: where the content of each pane is (null when
/// it is not in the tree) and the padding the body sees.
class _Sample {
  _Sample(this.body, this.secondary, this.bodyPadding);

  final Rect body;
  final Rect? secondary;
  final EdgeInsets bodyPadding;
}

Future<List<_Sample>> _close(
  WidgetTester tester, {
  required TextDirection direction,
  required _Close close,
  FoldableNavigationEdge? rail,
  bool extendBody = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 800);
  addTearDown(tester.view.reset);
  var open = true;
  late StateSetter setOpen;
  late EdgeInsets bodyPadding;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: StatefulBuilder(
        builder: (context, setState) {
          setOpen = setState;
          return FoldableScaffold(
            extendBody: extendBody,
            breakpoints: const FoldableBreakpoints(split: 840),
            navigationPlacement: rail == null
                ? (info) => const FoldableNavigationPlacement.none()
                : (info) => FoldableNavigationPlacement(rail),
            navigationBuilder: (context, placement, constraints, padding) =>
                NavigationRail(
                  selectedIndex: 0,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: destination.icon,
                        label: Text(destination.label),
                      ),
                  ],
                ),
            body: Builder(
              builder: (context) {
                bodyPadding = MediaQuery.paddingOf(context);
                return const SizedBox.expand(key: Key('body'));
              },
            ),
            secondaryBody: close == _Close.remove && !open
                ? null
                : const SizedBox.expand(key: Key('secondary')),
            hasSecondaryBody: close == _Close.flag ? open : null,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  _Sample sample() {
    final secondary = find.byKey(const Key('secondary'));
    return _Sample(
      tester.getRect(find.byKey(const Key('body'))),
      secondary.evaluate().isEmpty ? null : tester.getRect(secondary),
      bodyPadding,
    );
  }

  final samples = [sample()];
  setOpen(() => open = false);
  // Small steps, so that a jump stands out from the motion of the panes.
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 4));
    samples.add(sample());
  }
  await tester.pumpAndSettle();
  samples.add(sample());
  return samples;
}

/// Checks that every edge and the padding of the body move by at most about
/// as much per frame as the panes do, and that the secondary body slides out
/// whole and in one piece.
void _expectContinuous(List<_Sample> samples, TextDirection direction) {
  final ltr = direction == TextDirection.ltr;
  final first = samples.first;
  final secondaryWidth = first.secondary!.width;

  // How far the edge between the panes moves per frame at most: the edge of
  // the secondary body that faces the body.
  var step = 0.0;
  for (var i = 1; i < samples.length; i++) {
    final before = samples[i - 1].secondary;
    final after = samples[i].secondary;
    if (before == null || after == null || after.width == 0) continue;
    final delta = ltr ? after.left - before.left : after.right - before.right;
    if (delta.abs() > step) step = delta.abs();
  }
  expect(step, greaterThan(0), reason: 'the secondary body never moved');
  final limit = 2 * step + 1;

  for (var i = 1; i < samples.length; i++) {
    final before = samples[i - 1];
    final after = samples[i];
    final reason = 'frame $i';
    expect(
      (after.body.left - before.body.left).abs(),
      lessThan(limit),
      reason: '$reason: left edge of the body',
    );
    expect(
      (after.body.right - before.body.right).abs(),
      lessThan(limit),
      reason: '$reason: right edge of the body',
    );
    expect(
      (after.bodyPadding.left - before.bodyPadding.left).abs(),
      lessThan(limit),
      reason: '$reason: left padding of the body',
    );
    expect(
      (after.bodyPadding.right - before.bodyPadding.right).abs(),
      lessThan(limit),
      reason: '$reason: right padding of the body',
    );
    final secondary = after.secondary;
    final last = i == samples.length - 1;
    if (!last && after.body.width < samples.last.body.width - 0.5) {
      // While the body still grows, the secondary body is there, at its
      // width: it slides out instead of disappearing or being squeezed.
      expect(secondary, isNotNull, reason: '$reason: secondary body gone');
      expect(
        secondary!.width,
        moreOrLessEquals(secondaryWidth),
        reason: '$reason: secondary body squeezed',
      );
      // And it stays next to the body.
      if (ltr) {
        expect(secondary.left, greaterThanOrEqualTo(after.body.left));
      } else {
        expect(secondary.right, lessThanOrEqualTo(after.body.right));
      }
    }
  }
}

void main() {
  for (final direction in TextDirection.values) {
    for (final close in _Close.values) {
      testWidgets('closing the secondary pane is continuous '
          '($direction, ${close.name})', (tester) async {
        final samples = await _close(
          tester,
          direction: direction,
          close: close,
        );
        _expectContinuous(samples, direction);
        expect(samples.last.body.width, 1200);
      });

      for (final rail in [
        FoldableNavigationEdge.start,
        FoldableNavigationEdge.end,
      ]) {
        for (final extendBody in [false, true]) {
          testWidgets('closing the secondary pane next to a rail is continuous '
              '($direction, ${close.name}, ${rail.name}, '
              'extendBody: $extendBody)', (tester) async {
            final samples = await _close(
              tester,
              direction: direction,
              close: close,
              rail: rail,
              extendBody: extendBody,
            );
            _expectContinuous(samples, direction);
            // At the end the body has the pane area, and with extendBody
            // the room under the rail, wherever the rail is.
            final end = samples.last;
            expect(end.body.width, extendBody ? 1200 : lessThan(1200));
            if (extendBody) {
              final padding = end.bodyPadding.left + end.bodyPadding.right;
              expect(padding, greaterThan(0));
            }
          });
        }
      }
    }
  }

  testWidgets('a secondary body removed while hidden is let go', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 800);
    addTearDown(tester.view.reset);
    Widget scaffold({required bool withSecondary}) => MaterialApp(
      home: FoldableScaffold(
        breakpoints: const FoldableBreakpoints(split: 840),
        focusOnPrimaryBody: true,
        body: const SizedBox.expand(key: Key('body')),
        secondaryBody: withSecondary
            ? const SizedBox.expand(key: Key('secondary'))
            : null,
      ),
    );
    await tester.pumpWidget(scaffold(withSecondary: true));
    await tester.pumpAndSettle();
    // One pane, the body's: the secondary body is there, hidden.
    expect(tester.getSize(find.byKey(const Key('secondary'))).width, 0);
    await tester.pumpWidget(scaffold(withSecondary: false));
    await tester.pump();
    expect(find.byKey(const Key('secondary')), findsNothing);
  });
}
