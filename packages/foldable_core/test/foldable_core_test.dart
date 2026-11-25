import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_core/foldable_core.dart';

class FakeOwner implements FoldablePaneOwner {}

void main() {
  group('FoldableMotion', () {
    testWidgets('of scales durations below it', (tester) async {
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

    testWidgets('readOf scales without subscribing', (tester) async {
      late Duration read;
      int builds = 0;
      late final Widget reader = Builder(
        builder: (context) {
          read = FoldableMotion.readOf(context, const Duration(seconds: 1));
          builds++;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        FoldableMotion(scale: (duration) => duration * 2, child: reader),
      );
      expect(read, const Duration(seconds: 2));
      expect(builds, 1);

      // Changing the scale must not rebuild a readOf reader, and the value it
      // captured earlier is not recomputed.
      await tester.pumpWidget(
        FoldableMotion(scale: (duration) => duration * 10, child: reader),
      );
      expect(read, const Duration(seconds: 2));
      expect(builds, 1);
    });

    testWidgets('without a provider the duration is unchanged', (tester) async {
      late Duration value;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            value = FoldableMotion.of(context, const Duration(seconds: 3));
            return const SizedBox();
          },
        ),
      );
      expect(value, const Duration(seconds: 3));
    });
  });

  group('FoldablePane', () {
    test('isSlot is true only for primary and secondary', () {
      expect(FoldablePane.single.isSlot, isFalse);
      expect(FoldablePane.primary.isSlot, isTrue);
      expect(FoldablePane.secondary.isSlot, isTrue);
    });
  });

  group('FoldablePaneLayout', () {
    testWidgets('maybeOf is null without a provider', (tester) async {
      FoldablePaneLayout? layout;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            layout = FoldablePaneLayout.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(layout, isNull);
    });

    testWidgets('read is null without a provider', (tester) async {
      FoldablePaneLayout? layout;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            layout = FoldablePaneLayout.read(context);
            return const SizedBox();
          },
        ),
      );
      expect(layout, isNull);
    });

    testWidgets('read does not subscribe the caller', (tester) async {
      int builds = 0;
      late final Widget reader = Builder(
        builder: (context) {
          FoldablePaneLayout.read(context);
          builds++;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        FoldablePaneLayout(
          canSplit: true,
          primaryVisible: true,
          secondaryVisible: false,
          axis: Axis.horizontal,
          child: reader,
        ),
      );
      expect(builds, 1);

      await tester.pumpWidget(
        FoldablePaneLayout(
          canSplit: false,
          primaryVisible: true,
          secondaryVisible: false,
          axis: Axis.horizontal,
          child: reader,
        ),
      );
      expect(builds, 1);
    });

    testWidgets('maybeOf subscribes the caller', (tester) async {
      int builds = 0;
      late final Widget reader = Builder(
        builder: (context) {
          FoldablePaneLayout.maybeOf(context);
          builds++;
          return const SizedBox();
        },
      );
      Widget build({required bool canSplit}) => FoldablePaneLayout(
        canSplit: canSplit,
        primaryVisible: true,
        secondaryVisible: false,
        axis: Axis.horizontal,
        child: reader,
      );

      await tester.pumpWidget(build(canSplit: true));
      expect(builds, 1);

      await tester.pumpWidget(build(canSplit: false));
      expect(builds, 2);
    });

    testWidgets('reads the published layout', (tester) async {
      late FoldablePaneLayout? layout;
      await tester.pumpWidget(
        FoldablePaneLayout(
          canSplit: true,
          primaryVisible: true,
          secondaryVisible: false,
          axis: Axis.vertical,
          child: Builder(
            builder: (context) {
              layout = FoldablePaneLayout.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(layout?.canSplit, isTrue);
      expect(layout?.primaryVisible, isTrue);
      expect(layout?.secondaryVisible, isFalse);
      expect(layout?.axis, Axis.vertical);
      expect(layout?.isSplit, isFalse);
      expect(layout?.bodyPane, FoldablePane.primary);
    });

    testWidgets('isSplit is true only when both panes are visible', (
      tester,
    ) async {
      late bool split;
      await tester.pumpWidget(
        FoldablePaneLayout(
          canSplit: true,
          primaryVisible: true,
          secondaryVisible: true,
          axis: Axis.horizontal,
          child: Builder(
            builder: (context) {
              split = FoldablePaneLayout.of(context).isSplit;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(split, isTrue);
    });

    testWidgets('updateShouldNotify when any field changes', (tester) async {
      int notify = 0;
      // One reader instance: it only rebuilds when the inherited widget
      // notifies it, not on every pump of a new parent.
      late final Widget reader = Builder(
        builder: (context) {
          context.dependOnInheritedWidgetOfExactType<FoldablePaneLayout>();
          notify++;
          return const SizedBox();
        },
      );
      Widget build({
        required bool canSplit,
        required bool primaryVisible,
        required bool secondaryVisible,
        required Axis axis,
      }) => FoldablePaneLayout(
        canSplit: canSplit,
        primaryVisible: primaryVisible,
        secondaryVisible: secondaryVisible,
        axis: axis,
        child: reader,
      );

      await tester.pumpWidget(
        build(
          canSplit: true,
          primaryVisible: true,
          secondaryVisible: false,
          axis: Axis.horizontal,
        ),
      );
      expect(notify, 1);

      await tester.pumpWidget(
        build(
          canSplit: true,
          primaryVisible: true,
          secondaryVisible: false,
          axis: Axis.horizontal,
        ),
      );
      expect(notify, 1);

      await tester.pumpWidget(
        build(
          canSplit: false,
          primaryVisible: true,
          secondaryVisible: false,
          axis: Axis.horizontal,
        ),
      );
      expect(notify, 2);

      await tester.pumpWidget(
        build(
          canSplit: false,
          primaryVisible: false,
          secondaryVisible: false,
          axis: Axis.horizontal,
        ),
      );
      expect(notify, 3);

      await tester.pumpWidget(
        build(
          canSplit: false,
          primaryVisible: false,
          secondaryVisible: true,
          axis: Axis.horizontal,
        ),
      );
      expect(notify, 4);

      await tester.pumpWidget(
        build(
          canSplit: false,
          primaryVisible: false,
          secondaryVisible: true,
          axis: Axis.vertical,
        ),
      );
      expect(notify, 5);
    });
  });

  group('FoldablePaneScope', () {
    testWidgets('maybeOf and read are null without a provider', (tester) async {
      FoldablePaneScope? byMaybe;
      FoldablePaneScope? byRead;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            byMaybe = FoldablePaneScope.maybeOf(context);
            byRead = FoldablePaneScope.read(context);
            return const SizedBox();
          },
        ),
      );
      expect(byMaybe, isNull);
      expect(byRead, isNull);
    });

    testWidgets('paneOf falls back to single without a provider', (
      tester,
    ) async {
      late FoldablePane pane;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            pane = FoldablePaneScope.paneOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(pane, FoldablePane.single);
    });

    testWidgets('reads the pane of the closest scope', (tester) async {
      late FoldablePane pane;
      await tester.pumpWidget(
        FoldablePaneScope(
          pane: FoldablePane.secondary,
          child: Builder(
            builder: (context) {
              pane = FoldablePaneScope.paneOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(pane, FoldablePane.secondary);
    });

    testWidgets('read does not subscribe the caller', (tester) async {
      int builds = 0;
      late final Widget reader = Builder(
        builder: (context) {
          FoldablePaneScope.read(context);
          builds++;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        FoldablePaneScope(pane: FoldablePane.primary, child: reader),
      );
      expect(builds, 1);

      await tester.pumpWidget(
        FoldablePaneScope(pane: FoldablePane.secondary, child: reader),
      );
      // read does not subscribe, so changing the pane must not rebuild.
      expect(builds, 1);
    });

    testWidgets('updateShouldNotify when pane or owner changes', (
      tester,
    ) async {
      int notify = 0;
      // One reader instance: it only rebuilds when the inherited widget
      // notifies it, not on every pump of a new parent.
      late final Widget reader = Builder(
        builder: (context) {
          context.dependOnInheritedWidgetOfExactType<FoldablePaneScope>();
          notify++;
          return const SizedBox();
        },
      );
      Widget build({required FoldablePane pane, FoldablePaneOwner? owner}) =>
          FoldablePaneScope(pane: pane, owner: owner, child: reader);

      await tester.pumpWidget(build(pane: FoldablePane.primary));
      expect(notify, 1);

      await tester.pumpWidget(build(pane: FoldablePane.primary));
      expect(notify, 1);

      await tester.pumpWidget(build(pane: FoldablePane.secondary));
      expect(notify, 2);

      final owner = FakeOwner();
      await tester.pumpWidget(
        build(pane: FoldablePane.secondary, owner: owner),
      );
      expect(notify, 3);

      await tester.pumpWidget(
        build(pane: FoldablePane.secondary, owner: owner),
      );
      expect(notify, 3);

      // A different owner notifies too.
      await tester.pumpWidget(
        build(pane: FoldablePane.secondary, owner: FakeOwner()),
      );
      expect(notify, 4);
    });
  });

  group('FoldablePaneTransitions', () {
    testWidgets('value is false until the first begin', (tester) async {
      final transitions = FoldablePaneTransitions();
      addTearDown(transitions.dispose);
      expect(transitions.value, isFalse);

      transitions.begin();
      expect(transitions.value, isTrue);

      transitions.begin();
      expect(transitions.value, isTrue);

      transitions.end();
      // One transition still in flight: still transitioning.
      expect(transitions.value, isTrue);

      transitions.end();
      expect(transitions.value, isFalse);

      // Ending past zero never goes negative and never notifies again.
      transitions.end();
      transitions.end();
      expect(transitions.value, isFalse);
    });

    testWidgets('notifies exactly when the count crosses 0', (tester) async {
      final transitions = FoldablePaneTransitions();
      addTearDown(transitions.dispose);
      int notify = 0;
      transitions.addListener(() => notify++);

      transitions.begin();
      expect(notify, 1);

      transitions.begin();
      expect(notify, 1);

      transitions.end();
      expect(notify, 1);

      transitions.end();
      expect(notify, 2);

      transitions.end();
      expect(notify, 2);
    });

    testWidgets('works as a ValueListenable<bool>', (tester) async {
      final transitions = FoldablePaneTransitions();
      addTearDown(transitions.dispose);
      bool? seen;
      transitions.addListener(() => seen = transitions.value);

      transitions.begin();
      expect(seen, isTrue);

      transitions.end();
      expect(seen, isFalse);
    });
  });

  group('FoldablePaneTransitionScope', () {
    testWidgets('of and read are null without a provider', (tester) async {
      ValueListenable<bool>? byOf;
      ValueListenable<bool>? byRead;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            byOf = FoldablePaneTransitionScope.of(context);
            byRead = FoldablePaneTransitionScope.read(context);
            return const SizedBox();
          },
        ),
      );
      expect(byOf, isNull);
      expect(byRead, isNull);
    });

    testWidgets('isTransitioningOf is false without a provider', (
      tester,
    ) async {
      late bool transitioning;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            transitioning = FoldablePaneTransitionScope.isTransitioningOf(
              context,
            );
            return const SizedBox();
          },
        ),
      );
      expect(transitioning, isFalse);
    });

    testWidgets('isTransitioningOf rebuilds when the notifier changes', (
      tester,
    ) async {
      final transitions = FoldablePaneTransitions();
      addTearDown(transitions.dispose);
      var seen = <bool>[];
      // One reader instance: only the notifier makes it rebuild.
      late final Widget reader = Builder(
        builder: (context) {
          seen.add(FoldablePaneTransitionScope.isTransitioningOf(context));
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        FoldablePaneTransitionScope(transitions: transitions, child: reader),
      );
      expect(seen, [false]);

      transitions.begin();
      await tester.pump();
      expect(seen, [false, true]);

      transitions.end();
      await tester.pump();
      expect(seen, [false, true, false]);
    });

    testWidgets('read does not subscribe the caller', (tester) async {
      final transitions = FoldablePaneTransitions();
      addTearDown(transitions.dispose);
      int builds = 0;
      late final Widget reader = Builder(
        builder: (context) {
          FoldablePaneTransitionScope.read(context);
          builds++;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        FoldablePaneTransitionScope(transitions: transitions, child: reader),
      );
      expect(builds, 1);

      transitions.begin();
      await tester.pump();
      expect(builds, 1);
    });

    testWidgets('of returns the scope notifier', (tester) async {
      final transitions = FoldablePaneTransitions();
      addTearDown(transitions.dispose);
      late ValueListenable<bool> captured;
      await tester.pumpWidget(
        FoldablePaneTransitionScope(
          transitions: transitions,
          child: Builder(
            builder: (context) {
              captured = FoldablePaneTransitionScope.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(identical(captured, transitions), isTrue);
    });
  });
}
