import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// Records `init <name>` and `dispose <name>` of every [_Probe], to tell a page
/// that kept its state from one that was built again.
final _log = <String>[];

class _Probe extends StatefulWidget {
  const _Probe(this.name);

  final String name;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _log.add('init ${widget.name}');
  }

  @override
  void dispose() {
    _log.add('dispose ${widget.name}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('${widget.name}: $_count'),
      ),
    );
  }
}

FoldablePage<void> _page(String name, {FoldablePageTransition? transition}) {
  return FoldablePage<void>(
    name: '/$name',
    transition: transition,
    child: _Probe(name),
  );
}

/// The page called [name].
Finder _label(String name, {bool offstage = false}) =>
    find.textContaining('$name:', skipOffstage: !offstage);

enum _Kind { stack, split }

/// A navigator of [kind]. The split navigator sits in a one-pane layout, like
/// a phone: the visible pane switches to the top page.
Widget _app(
  _Kind kind,
  FoldableNavigatorController controller, {
  FoldablePageTransition transition = FoldablePageTransition.cupertino,
}) {
  if (kind == _Kind.stack) {
    return MaterialApp(
      home: FoldableNavigator.stack(
        controller: controller,
        transition: transition,
      ),
    );
  }
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final hasSecondary = controller.pages.length > 1;
      return MaterialApp(
        home: FoldableScaffoldScope(
          canSplit: false,
          child: FoldablePaneLayout(
            primaryVisible: !hasSecondary,
            secondaryVisible: hasSecondary,
            child: FoldableNavigator(
              controller: controller,
              transition: transition,
              builder: (context, body, secondary) => Column(
                children: [
                  Expanded(child: body),
                  if (secondary != null) Expanded(child: secondary),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Pumps [app] after unmounting the previous test's tree, whose disposal would
/// otherwise end up in [_log].
Future<void> _start(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(const SizedBox());
  _log.clear();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// The opacity of the closest fade around the page called [name].
double _opacityOf(WidgetTester tester, String name) {
  final fade = tester.widget<FadeTransition>(
    find
        .ancestor(
          of: _label(name, offstage: true),
          matching: find.byType(FadeTransition, skipOffstage: false),
        )
        .first,
  );
  return fade.opacity.value;
}

/// The slide of the closest [SlideTransition] around the page called [name].
Offset _slideOf(WidgetTester tester, String name) {
  final slide = tester.widget<SlideTransition>(
    find
        .ancestor(
          of: _label(name, offstage: true),
          matching: find.byType(SlideTransition, skipOffstage: false),
        )
        .first,
  );
  return slide.position.value;
}

bool _transitioning(WidgetTester tester, String name) =>
    FoldableNavigator.isTransitioning(tester.element(_label(name)));

/// Drags from the left edge past half the width and releases.
Future<void> _swipeBack(WidgetTester tester) async {
  final swipe = await tester.startGesture(const Offset(8, 300));
  await swipe.moveBy(const Offset(40, 0));
  await tester.pump();
  await swipe.moveBy(const Offset(500, 0));
  await tester.pump(const Duration(milliseconds: 300));
  await swipe.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(_log.clear);

  for (final kind in _Kind.values) {
    group('${kind.name} navigator', () {
      testWidgets('fade keeps both pages mounted and fades the new one in', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([_page('body')]);
        await _start(
          tester,
          _app(kind, controller, transition: FoldablePageTransition.fade),
        );

        controller.push(_page('detail'));
        await tester.pump();

        expect(_label('body', offstage: true), findsOneWidget);
        expect(_label('detail'), findsOneWidget);
        expect(_transitioning(tester, 'detail'), isTrue);
        expect(_opacityOf(tester, 'detail'), 0);
        expect(_opacityOf(tester, 'body'), 1);

        await tester.pump(const Duration(milliseconds: 150));
        expect(_opacityOf(tester, 'detail'), inExclusiveRange(0, 1));
        expect(_opacityOf(tester, 'body'), 1);

        await tester.pumpAndSettle();
        expect(_opacityOf(tester, 'detail'), 1);
        expect(_transitioning(tester, 'detail'), isFalse);
        expect(_log.where((e) => e.startsWith('dispose')), [
          if (kind == _Kind.stack) 'dispose body',
        ]);
      });

      testWidgets('fade fades the removed page out on a pop', (tester) async {
        final controller = FoldableNavigatorController.single([
          _page('body'),
          _page('detail'),
        ]);
        await _start(
          tester,
          _app(kind, controller, transition: FoldablePageTransition.fade),
        );

        controller.pop();
        await tester.pump();
        expect(_opacityOf(tester, 'detail'), 1);
        expect(_label('body', offstage: true), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 150));
        expect(_opacityOf(tester, 'detail'), inExclusiveRange(0, 1));
        expect(_opacityOf(tester, 'body'), 1);

        await tester.pumpAndSettle();
        expect(_label('detail', offstage: true), findsNothing);
        expect(_opacityOf(tester, 'body'), 1);
      });

      testWidgets('none shows the new page at once without animating', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([_page('body')]);
        await _start(
          tester,
          _app(kind, controller, transition: FoldablePageTransition.none),
        );

        controller.push(_page('detail'));
        await tester.pump();

        expect(_label('detail'), findsOneWidget);
        expect(_transitioning(tester, 'detail'), isFalse);
        expect(tester.hasRunningAnimations, isFalse);
        if (kind == _Kind.stack) {
          expect(_label('body', offstage: true), findsNothing);
        }

        controller.pop();
        await tester.pump();

        expect(_label('body'), findsOneWidget);
        expect(_label('detail', offstage: true), findsNothing);
        expect(_transitioning(tester, 'body'), isFalse);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('a page transition beats the navigator one', (tester) async {
        final controller = FoldableNavigatorController.single([_page('body')]);
        await _start(
          tester,
          _app(kind, controller, transition: FoldablePageTransition.none),
        );

        controller.push(
          _page('slide', transition: FoldablePageTransition.cupertino),
        );
        await tester.pump();

        expect(_transitioning(tester, 'slide'), isTrue);
        expect(_slideOf(tester, 'slide'), const Offset(1, 0));
        await tester.pumpAndSettle();
        expect(_slideOf(tester, 'slide'), Offset.zero);

        // The next page has no transition of its own: the navigator's, none.
        controller.push(_page('plain'));
        await tester.pump();
        expect(_label('plain'), findsOneWidget);
        expect(_transitioning(tester, 'plain'), isFalse);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('a page can opt out of the navigator transition', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([_page('body')]);
        await _start(tester, _app(kind, controller));

        controller.push(
          _page('detail', transition: FoldablePageTransition.none),
        );
        await tester.pump();

        expect(_label('detail'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('a pop uses the transition of the removed page', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([
          _page('body', transition: FoldablePageTransition.fade),
          _page('detail'),
        ]);
        await _start(tester, _app(kind, controller));

        controller.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        // `detail` slides out (cupertino) although `body` is a fade page.
        expect(_slideOf(tester, 'detail').dx, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(_label('body'), findsOneWidget);

        controller.push(
          _page('other', transition: FoldablePageTransition.fade),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(_opacityOf(tester, 'other'), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();

        // `other` is a fade page, `body` below it too, so the pop fades.
        controller.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(_opacityOf(tester, 'other'), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(controller.pages.length, 1);
      });

      testWidgets('a push uses the transition of the new page', (tester) async {
        final controller = FoldableNavigatorController.single([
          _page('body', transition: FoldablePageTransition.fade),
        ]);
        await _start(tester, _app(kind, controller));

        controller.push(_page('detail'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        // `detail` slides in (cupertino) although `body` is a fade page.
        expect(_slideOf(tester, 'detail').dx, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
      });

      testWidgets('swipe back is not offered for fade pages', (tester) async {
        final controller = FoldableNavigatorController.single([
          _page('body'),
          _page('detail'),
        ]);
        await _start(
          tester,
          _app(kind, controller, transition: FoldablePageTransition.fade),
        );

        final swipe = await tester.startGesture(const Offset(8, 300));
        await swipe.moveBy(const Offset(40, 0));
        await tester.pump();
        await swipe.moveBy(const Offset(500, 0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_transitioning(tester, 'detail'), isFalse);
        await swipe.up();
        await tester.pumpAndSettle();

        expect(controller.pages.length, 2);
        expect(_label('detail'), findsOneWidget);
      });

      testWidgets('swipe back is not offered for none pages', (tester) async {
        final controller = FoldableNavigatorController.single([
          _page('body'),
          _page('detail'),
        ]);
        await _start(
          tester,
          _app(kind, controller, transition: FoldablePageTransition.none),
        );

        await _swipeBack(tester);

        expect(controller.pages.length, 2);
      });

      testWidgets('swipe back works for a cupertino page in a fade app', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([
          _page('body'),
          _page('detail', transition: FoldablePageTransition.cupertino),
        ]);
        await _start(
          tester,
          _app(kind, controller, transition: FoldablePageTransition.fade),
        );

        await _swipeBack(tester);

        expect(controller.pages.length, 1);
        expect(_label('detail', offstage: true), findsNothing);
      });

      testWidgets('swipe back works for the default transition', (
        tester,
      ) async {
        final controller = FoldableNavigatorController.single([
          _page('body'),
          _page('detail'),
        ]);
        await _start(tester, _app(kind, controller));

        await _swipeBack(tester);

        expect(controller.pages.length, 1);
      });

      testWidgets('a custom transition gets the info and can allow swiping', (
        tester,
      ) async {
        final seen = <(FoldableTransitionRole, bool)>{};
        final scale = FoldablePageTransition.custom((context, info, child) {
          seen.add((info.role, info.isPush));
          return ScaleTransition(
            scale: info.role == FoldableTransitionRole.incoming
                ? info.animation
                : kAlwaysCompleteAnimation,
            child: child,
          );
        }, supportsSwipeBack: true);
        final controller = FoldableNavigatorController.single([_page('body')]);
        await _start(tester, _app(kind, controller, transition: scale));

        controller.push(_page('detail'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final scaleOf = tester.widget<ScaleTransition>(
          find
              .ancestor(
                of: _label('detail'),
                matching: find.byType(ScaleTransition),
              )
              .first,
        );
        expect(scaleOf.scale.value, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();

        expect(seen, contains((FoldableTransitionRole.incoming, true)));
        expect(seen, contains((FoldableTransitionRole.outgoing, true)));
        expect(seen, contains((FoldableTransitionRole.steady, true)));

        await _swipeBack(tester);
        expect(controller.pages.length, 1);
      });

      for (final entry in {
        'cupertino': FoldablePageTransition.cupertino,
        'fade': FoldablePageTransition.fade,
        'none': FoldablePageTransition.none,
      }.entries) {
        testWidgets('pages keep their state with ${entry.key}', (tester) async {
          final controller = FoldableNavigatorController.single([
            _page('body'),
          ]);
          await _start(tester, _app(kind, controller, transition: entry.value));
          await tester.tap(_label('body'));
          await tester.pump();
          expect(find.text('body: 1'), findsOneWidget);

          controller.push(_page('detail'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          controller.pop();
          await tester.pumpAndSettle();

          // Every page was built once, except the stack navigator that builds
          // the revealed page again.
          expect(_log.where((e) => e == 'init detail'), hasLength(1));
          expect(_log.where((e) => e == 'dispose detail'), hasLength(1));
          if (kind == _Kind.split) {
            expect(_log.where((e) => e == 'init body'), hasLength(1));
            expect(_log.where((e) => e == 'dispose body'), isEmpty);
            expect(find.text('body: 1'), findsOneWidget);
          } else {
            expect(find.text('body: 0'), findsOneWidget);
          }
        });
      }

      testWidgets('pages keep their state when transitions differ', (
        tester,
      ) async {
        // `body` rests with the cupertino wrapper but animates out with the
        // fade of `detail`.
        final controller = FoldableNavigatorController.single([
          _page('body', transition: FoldablePageTransition.cupertino),
        ]);
        await _start(tester, _app(kind, controller));
        await tester.tap(_label('body'));
        await tester.pump();

        controller.push(
          _page('detail', transition: FoldablePageTransition.fade),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(_log.where((e) => e == 'init body'), hasLength(1));
        expect(_log.where((e) => e == 'init detail'), hasLength(1));
        expect(_log.where((e) => e == 'dispose detail'), isEmpty);
        if (kind == _Kind.split) {
          expect(_log.where((e) => e == 'dispose body'), isEmpty);
          expect(find.text('body: 1', skipOffstage: false), findsOneWidget);
        }
      });
    });
  }

  testWidgets('a route passes its transition to the page', (tester) async {
    expect(const _FadeRoute().toPage<void>().transition, isNotNull);
    expect(const _PlainRoute().toPage<void>().transition, isNull);
  });
}

class _FadeRoute extends FoldableRoute {
  const _FadeRoute();

  @override
  String get path => '/fade';

  @override
  FoldablePageTransition get transition => FoldablePageTransition.fade;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _PlainRoute extends FoldableRoute {
  const _PlainRoute();

  @override
  String get path => '/plain';

  @override
  Widget build(BuildContext context) => const SizedBox();
}
