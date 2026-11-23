import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Sets the window of the test to exactly [size].
void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps a [FoldableScaffold] filling the window and, unless [settle] is false,
/// waits for the pane animation. [settle] is false when the content runs an
/// endless ticker, which would otherwise keep [WidgetTester.pumpAndSettle]
/// busy forever.
Future<void> pumpScaffold(
  WidgetTester tester, {
  Size size = const Size(800, 600),
  bool focusOnPrimaryBody = false,
  bool hasSecondaryBody = true,
  Widget? body,
  Widget? secondaryBody,
  bool settle = true,
}) async {
  setSize(tester, size);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      home: FoldableScaffold(
        focusOnPrimaryBody: focusOnPrimaryBody,
        hasSecondaryBody: hasSecondaryBody,
        body: body ?? const Text('body'),
        secondaryBody: secondaryBody ?? const Text('secondary'),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

double paneWidth(WidgetTester tester, String key) {
  return tester.getSize(find.byKey(Key(key), skipOffstage: false)).width;
}

/// A probe whose [AnimationController] keeps ticking while it is mounted.
class TickerProbe extends StatefulWidget {
  const TickerProbe({super.key});

  @override
  State<TickerProbe> createState() => TickerProbeState();
}

class TickerProbeState extends State<TickerProbe>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  int ticks = 0;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    controller.addListener(() {
      setState(() => ticks++);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('ticks: $ticks');
}

/// Remembers text input and a counter so state can be asserted across hide and
/// show cycles.
class StateProbe extends StatefulWidget {
  const StateProbe({super.key, required this.labelKey, required this.countKey});

  final Key labelKey;
  final Key countKey;

  @override
  State<StateProbe> createState() => StateProbeState();
}

class StateProbeState extends State<StateProbe> {
  final TextEditingController text = TextEditingController();
  int count = 0;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(key: widget.labelKey, controller: text),
        TextButton(
          key: widget.countKey,
          onPressed: () => setState(() => count++),
          child: const Text('+'),
        ),
        Text('count: $count'),
      ],
    );
  }
}

void main() {
  group('hidden pane: one pane is at width 0', () {
    testWidgets('the primary pane is hidden below the split width', (
      tester,
    ) async {
      await pumpScaffold(tester, size: const Size(800, 600));

      expect(paneWidth(tester, 'body_builder'), 0);
      expect(paneWidth(tester, 'secondary_body_builder'), 800);
    });

    testWidgets('the secondary pane is hidden when hasSecondaryBody is false', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        size: const Size(1400, 600),
        hasSecondaryBody: false,
      );

      expect(paneWidth(tester, 'body_builder'), 1400);
      expect(paneWidth(tester, 'secondary_body_builder'), 0);
    });
  });

  group('point 1: a width-0 pane does not break layout', () {
    testWidgets('a wide Row inside the hidden primary pane does not overflow', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        size: const Size(800, 600),
        body: const Row(
          children: <Widget>[
            SizedBox(width: 300, height: 100),
            Text('a long line of text that cannot fit in a zero-width pane'),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a ListTile inside the hidden pane does not overflow', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        size: const Size(800, 600),
        body: const Material(
          child: ListTile(
            leading: Icon(Icons.mail),
            title: Text('a long list tile title that does not fit'),
            trailing: Icon(Icons.arrow_forward),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('point 2: focus does not reach the hidden pane', () {
    testWidgets('Tab focuses the visible pane, not the hidden one', (
      tester,
    ) async {
      final hiddenFocus = FocusNode();
      final visibleFocus = FocusNode();
      addTearDown(hiddenFocus.dispose);
      addTearDown(visibleFocus.dispose);

      await pumpScaffold(
        tester,
        size: const Size(800, 600),
        body: TextField(focusNode: hiddenFocus),
        secondaryBody: TextField(focusNode: visibleFocus),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(hiddenFocus.hasFocus, isFalse);
      expect(visibleFocus.hasFocus, isTrue);
    });
  });

  group('point 3: semantics does not contain the hidden pane', () {
    testWidgets('a semantics label in the hidden pane is not exposed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpScaffold(
          tester,
          size: const Size(800, 600),
          body: Semantics(
            container: true,
            label: 'hidden item',
            child: Text('hidden text'),
          ),
        );

        expect(find.bySemanticsLabel(RegExp('hidden item')), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
      'the same semantics label is exposed when the pane is visible',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpScaffold(
            tester,
            size: const Size(1400, 600),
            body: Semantics(
              container: true,
              label: 'visible item',
              child: Text('visible text'),
            ),
          );

          expect(find.bySemanticsLabel(RegExp('visible item')), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      },
    );
  });

  group('point 4: pointer and ticker', () {
    testWidgets('a ticker inside the hidden pane does not tick', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        size: const Size(800, 600),
        body: const TickerProbe(),
        settle: false,
      );

      final probe = tester.state<TickerProbeState>(find.byType(TickerProbe));
      final before = probe.ticks;

      await tester.pump(const Duration(milliseconds: 400));
      expect(probe.ticks, before);
    });

    testWidgets('a ticker inside a visible pane keeps ticking', (tester) async {
      await pumpScaffold(
        tester,
        size: const Size(1400, 600),
        body: const TickerProbe(),
        settle: false,
      );

      final probe = tester.state<TickerProbeState>(find.byType(TickerProbe));
      final before = probe.ticks;

      await tester.pump(const Duration(milliseconds: 400));
      expect(probe.ticks, greaterThan(before));
    });

    testWidgets('a pointer inside the hidden pane has no effect', (
      tester,
    ) async {
      var tapped = false;
      await pumpScaffold(
        tester,
        size: const Size(800, 600),
        body: GestureDetector(
          key: const Key('hidden-gesture'),
          behavior: HitTestBehavior.opaque,
          onTap: () => tapped = true,
          child: const SizedBox.expand(),
        ),
      );

      await tester.tap(
        find.byKey(const Key('hidden-gesture')),
        warnIfMissed: false,
      );
      expect(tapped, isFalse);
    });

    testWidgets('a pointer inside a visible pane works', (tester) async {
      var tapped = false;
      await pumpScaffold(
        tester,
        size: const Size(1400, 600),
        body: GestureDetector(
          key: const Key('visible-gesture'),
          behavior: HitTestBehavior.opaque,
          onTap: () => tapped = true,
          child: const SizedBox.expand(),
        ),
      );

      await tester.tap(
        find.byKey(const Key('visible-gesture')),
        warnIfMissed: false,
      );
      expect(tapped, isTrue);
    });

    testWidgets(
      'a pane still takes pointer while it is animating out (not disabled '
      'early)',
      (tester) async {
        setSize(tester, const Size(1400, 600));
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.linux),
            home: FoldableScaffold(
              body: GestureDetector(
                key: const Key('sliding-gesture'),
                behavior: HitTestBehavior.opaque,
                onTap: () => tapped = true,
                child: const SizedBox.expand(),
              ),
              secondaryBody: const Text('secondary'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(paneWidth(tester, 'body_builder'), greaterThan(0));

        // Start the collapse but do not wait for it: the primary pane still
        // has a non-zero animated width.
        tester.view.physicalSize = const Size(800, 600);
        await tester.pump();
        expect(paneWidth(tester, 'body_builder'), greaterThan(0));

        await tester.tap(
          find.byKey(const Key('sliding-gesture')),
          warnIfMissed: false,
        );
        expect(tapped, isTrue);

        await tester.pumpAndSettle();
        expect(paneWidth(tester, 'body_builder'), 0);
      },
    );
  });

  group('state survives hide and show', () {
    Widget app({required bool hasSecondaryBody}) {
      return MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: FoldableScaffold(
          hasSecondaryBody: hasSecondaryBody,
          body: const StateProbe(
            key: Key('body-probe'),
            labelKey: Key('body-label'),
            countKey: Key('body-count'),
          ),
          secondaryBody: const StateProbe(
            key: Key('secondary-probe'),
            labelKey: Key('secondary-label'),
            countKey: Key('secondary-count'),
          ),
        ),
      );
    }

    StateProbeState probeState(WidgetTester tester, String key) {
      return tester.state<StateProbeState>(find.byKey(Key(key)));
    }

    testWidgets('the hidden pane keeps its state when shown again', (
      tester,
    ) async {
      setSize(tester, const Size(1400, 600));
      await tester.pumpWidget(app(hasSecondaryBody: true));
      await tester.pumpAndSettle();

      final secondaryBefore = probeState(tester, 'secondary-probe');
      await tester.enterText(
        find.byKey(const Key('secondary-label')),
        'secondary text',
      );
      await tester.tap(find.byKey(const Key('secondary-count')));
      await tester.tap(find.byKey(const Key('secondary-count')));
      await tester.pump();
      expect(secondaryBefore.count, 2);
      expect(secondaryBefore.text.text, 'secondary text');

      // Hide the secondary pane.
      await tester.pumpWidget(app(hasSecondaryBody: false));
      await tester.pumpAndSettle();
      expect(paneWidth(tester, 'secondary_body_builder'), 0);

      // Show it again.
      await tester.pumpWidget(app(hasSecondaryBody: true));
      await tester.pumpAndSettle();
      expect(paneWidth(tester, 'secondary_body_builder'), greaterThan(0));

      final secondaryAfter = probeState(tester, 'secondary-probe');
      expect(identical(secondaryAfter, secondaryBefore), isTrue);
      expect(secondaryAfter.count, 2);
      expect(secondaryAfter.text.text, 'secondary text');
    });

    testWidgets(
      'the primary pane keeps its state across one-pane and two-pane layouts',
      (tester) async {
        setSize(tester, const Size(1400, 600));
        await tester.pumpWidget(app(hasSecondaryBody: true));
        await tester.pumpAndSettle();

        final bodyBefore = probeState(tester, 'body-probe');
        await tester.enterText(
          find.byKey(const Key('body-label')),
          'body text',
        );
        await tester.tap(find.byKey(const Key('body-count')));
        await tester.pump();

        // Shrink to a single-pane layout: the primary pane is hidden.
        tester.view.physicalSize = const Size(800, 600);
        await tester.pumpAndSettle();
        expect(paneWidth(tester, 'body_builder'), 0);

        // Grow back to two panes.
        tester.view.physicalSize = const Size(1400, 600);
        await tester.pumpAndSettle();
        expect(paneWidth(tester, 'body_builder'), greaterThan(0));

        final bodyAfter = probeState(tester, 'body-probe');
        expect(identical(bodyAfter, bodyBefore), isTrue);
        expect(bodyAfter.count, 1);
        expect(bodyAfter.text.text, 'body text');
      },
    );
  });
}
