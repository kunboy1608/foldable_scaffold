import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_core/foldable_core.dart';

void main() {
  testWidgets('FoldableMotion scales durations below it', (tester) async {
    late Duration scaled;
    late Duration plain;
    await tester.pumpWidget(
      FoldableMotion(
        scale: (duration) => duration * 5,
        child: Builder(
          builder: (context) {
            scaled = FoldableMotion.of(context, const Duration(seconds: 1));
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          plain = FoldableMotion.of(context, const Duration(seconds: 1));
          return const SizedBox();
        },
      ),
    );
    expect(scaled, const Duration(seconds: 5));
    expect(plain, const Duration(seconds: 1));
  });

  testWidgets('FoldablePaneLayout and FoldableScaffoldScope are readable', (
    tester,
  ) async {
    FoldablePaneLayout? layout;
    bool? canSplit;
    await tester.pumpWidget(
      FoldableScaffoldScope(
        canSplit: true,
        child: FoldablePaneLayout(
          primaryVisible: true,
          secondaryVisible: false,
          child: Builder(
            builder: (context) {
              layout = FoldablePaneLayout.maybeOf(context);
              canSplit = FoldableScaffoldScope.maybeOf(context)?.canSplit;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(layout?.primaryVisible, isTrue);
    expect(layout?.secondaryVisible, isFalse);
    expect(canSplit, isTrue);
    // Panes side by side unless said otherwise: the old constructor call.
    expect(layout?.axis, Axis.horizontal);
  });

  testWidgets('FoldablePaneLayout.axis notifies when it changes', (
    tester,
  ) async {
    final axes = <Axis?>[];
    // A const reader only rebuilds when the inherited widget notifies it.
    final reader = Builder(
      builder: (context) {
        axes.add(FoldablePaneLayout.maybeOf(context)?.axis);
        return const SizedBox();
      },
    );
    Widget build(Axis axis) => FoldablePaneLayout(
      primaryVisible: true,
      secondaryVisible: true,
      axis: axis,
      child: reader,
    );

    await tester.pumpWidget(build(Axis.horizontal));
    await tester.pumpWidget(build(Axis.horizontal));
    await tester.pumpWidget(build(Axis.vertical));

    expect(axes, [Axis.horizontal, Axis.vertical]);
  });

  testWidgets('FoldablePaneTransitionScope follows its notifier', (
    tester,
  ) async {
    final transition = ValueNotifier(false);
    addTearDown(transition.dispose);
    var seen = <bool>[];
    await tester.pumpWidget(
      FoldablePaneTransitionScope(
        transition: transition,
        child: Builder(
          builder: (context) {
            seen.add(FoldablePaneTransitionScope.isTransitioningOf(context));
            return const SizedBox();
          },
        ),
      ),
    );
    transition.value = true;
    await tester.pump();
    expect(seen, [false, true]);
  });
}
