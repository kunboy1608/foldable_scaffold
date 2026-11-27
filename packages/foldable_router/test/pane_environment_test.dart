import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A layout that declares two panes, like `FoldableScaffold`: each frame sits
/// under a `MediaQuery` of its own (the left pane has a left padding of 11,
/// the right one a right padding of 22) and no keyboard inset, since the
/// layout already took the room of the keyboard.
class DeclaredShell extends FoldableShellRoute {
  const DeclaredShell();

  @override
  List<FoldableShellChildRoute> get branches => const [ListRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Material(child: shell.child);

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    final MediaQueryData media = MediaQuery.of(context);
    final double keyboard = media.viewInsets.bottom;
    Widget pane(Widget frame, EdgeInsets padding) => MediaQuery(
      data: media.copyWith(padding: padding, viewInsets: EdgeInsets.zero),
      child: frame,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: FoldablePaneLayout(
        primaryVisible: true,
        secondaryVisible: true,
        child: Row(
          children: <Widget>[
            Expanded(
              child: pane(panes.primary, const EdgeInsets.only(left: 11)),
            ),
            Expanded(
              child: panes.hasSecondary
                  ? pane(panes.secondary, const EdgeInsets.only(right: 22))
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}

class ListRoute extends FoldableShellChildRoute {
  const ListRoute();

  @override
  String get segment => 'list';

  @override
  FoldableShellParent get parent => const DeclaredShell();

  @override
  Widget build(BuildContext context) => const _Page(label: 'list');
}

class DetailRoute extends FoldableShellChildRoute {
  const DetailRoute();

  @override
  String get segment => 'detail';

  @override
  FoldableShellParent get parent => const ListRoute();

  @override
  Widget build(BuildContext context) => const _Page(label: 'detail');
}

class _Page extends StatelessWidget {
  const _Page({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: Text(
              '$label padding ${MediaQuery.paddingOf(context)}',
              key: Key('$label padding'),
            ),
          ),
        ),
        TextField(key: Key('$label field')),
      ],
    ),
  );
}

void main() {
  testWidgets('each page keeps the environment of its pane, and a field '
      'being edited keeps its state and focus while the keyboard slides up', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final router = FoldableRouter(
      initial: const DeclaredShell(),
      routes: <String, FoldableRouteFactory>{
        '/list': (params) => const ListRoute(),
        '/list/detail': (params) => const DetailRoute(),
      },
      notFoundBuilder: (context, uri) => const SizedBox.shrink(),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router.routerConfig),
    );
    await tester.pumpAndSettle();
    await router.open(const DetailRoute());
    await tester.pumpAndSettle();

    String paddingOf(String label) =>
        tester.widget<Text>(find.byKey(Key('$label padding'))).data!;
    // From the first frames: each page reads the media of its own pane.
    expect(paddingOf('list'), contains('EdgeInsets(11.0, 0.0, 0.0, 0.0)'));
    expect(paddingOf('detail'), contains('EdgeInsets(0.0, 0.0, 22.0, 0.0)'));

    final Finder field = find.byKey(const Key('detail field'));
    EditableTextState editable() => tester.state<EditableTextState>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    await tester.tap(field);
    await tester.pump();
    final EditableTextState first = editable();
    expect(first.widget.focusNode.hasFocus, isTrue);
    final double bottom = tester.getRect(field).bottom;

    for (var i = 1; i <= 8; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: 30.0 * i);
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(editable(), first), isTrue, reason: 'frame $i');
      expect(first.widget.focusNode.hasFocus, isTrue, reason: 'frame $i');
      // Moved up by the keyboard once: the pane media has no inset left.
      expect(tester.getRect(field).bottom, bottom - 30.0 * i);
      expect(paddingOf('list'), contains('EdgeInsets(11.0, 0.0, 0.0, 0.0)'));
      expect(paddingOf('detail'), contains('EdgeInsets(0.0, 0.0, 22.0, 0.0)'));
    }
  });
}
