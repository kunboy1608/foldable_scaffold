import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

final _themeData = ThemeData(platform: TargetPlatform.linux);

/// Pumps a two-pane [FoldableScaffold] in a 1400 wide window, with the divider
/// theme in the [ThemeData] of the app ([inherited]) or on the scaffold
/// ([theme]), or both.
Future<void> _pump(
  WidgetTester tester, {
  FoldableScaffoldThemeData? inherited,
  FoldableScaffoldThemeData? theme,
  FoldableDividerBuilder? dividerBuilder,
  List<DisplayFeature> features = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 600);
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = features;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: _themeData.copyWith(
        extensions: [if (inherited != null) inherited],
      ),
      home: FoldableScaffold(
        theme: theme,
        dividerBuilder: dividerBuilder,
        body: const Text('body'),
        secondaryBody: const Text('secondary'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _divider => find.byKey(const Key('pane_divider'));

Finder get _handle =>
    find.descendant(of: _divider, matching: find.byType(AnimatedContainer));

AnimatedContainer _handleWidget(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(_handle);

BoxDecoration _decorationOf(WidgetTester tester) =>
    _handleWidget(tester).decoration! as BoxDecoration;

void main() {
  group('the default look of the divider', () {
    testWidgets('is the same as before theming', (tester) async {
      await _pump(tester);

      expect(tester.getSize(_handle), const Size(4, 50));
      expect(_decorationOf(tester).color, _themeData.dividerColor);
      expect(_decorationOf(tester).borderRadius, BorderRadius.circular(2));
      expect(_handleWidget(tester).duration, const Duration(milliseconds: 200));
    });

    testWidgets('keeps the background of the divider slot', (tester) async {
      await _pump(tester);

      final background = tester.widget<Container>(
        find.descendant(of: _divider, matching: find.byType(Container)).first,
      );
      expect(background.color, _themeData.scaffoldBackgroundColor);
    });

    testWidgets('the handle grows while it is dragged', (tester) async {
      await _pump(tester);

      final gesture = await tester.startGesture(tester.getCenter(_handle));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pumpAndSettle();

      expect(tester.getSize(_handle), const Size(12, 50));
      expect(_decorationOf(tester).color, _themeData.colorScheme.primary);
      expect(_decorationOf(tester).borderRadius, BorderRadius.circular(6));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the divider theme', () {
    testWidgets('of the ThemeData styles the handle', (tester) async {
      await _pump(
        tester,
        inherited: const FoldableScaffoldThemeData(
          dividerColor: Colors.red,
          handleSize: Size(6, 64),
          handleBorderRadius: BorderRadius.all(Radius.circular(3)),
          animationDuration: Duration(milliseconds: 50),
        ),
      );

      expect(tester.getSize(_handle), const Size(6, 64));
      expect(_decorationOf(tester).color, Colors.red);
      expect(
        _decorationOf(tester).borderRadius,
        const BorderRadius.all(Radius.circular(3)),
      );
      expect(_handleWidget(tester).duration, const Duration(milliseconds: 50));
    });

    testWidgets('of the widget wins over the inherited one', (tester) async {
      await _pump(
        tester,
        inherited: const FoldableScaffoldThemeData(
          dividerColor: Colors.red,
          dividerActiveColor: Colors.orange,
          handleSize: Size(6, 64),
        ),
        theme: const FoldableScaffoldThemeData(dividerColor: Colors.green),
      );

      // The color comes from the widget, the size from the inherited theme.
      expect(_decorationOf(tester).color, Colors.green);
      expect(tester.getSize(_handle), const Size(6, 64));

      final gesture = await tester.startGesture(tester.getCenter(_handle));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(_decorationOf(tester).color, Colors.orange);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('of the widget alone styles the handle', (tester) async {
      await _pump(
        tester,
        theme: const FoldableScaffoldThemeData(
          dividerActiveColor: Colors.purple,
          handleActiveWidth: 20,
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(_handle));
      await tester.pumpAndSettle();

      expect(tester.getSize(_handle).width, 20);
      expect(_decorationOf(tester).color, Colors.purple);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('a custom divider handle', () {
    testWidgets('replaces the look and gets the state of the divider', (
      tester,
    ) async {
      final states = <FoldableDividerState>[];

      await _pump(
        tester,
        dividerBuilder: (context, state) {
          states.add(state);
          return Container(
            key: const Key('custom_handle'),
            width: 8,
            height: 8,
            color: Colors.blue,
          );
        },
      );

      expect(find.byKey(const Key('custom_handle')), findsOneWidget);
      expect(_handle, findsNothing);
      expect(states.last.isHovering, isFalse);
      expect(states.last.isDragging, isFalse);
      expect(states.last.isFocused, isFalse);
      expect(states.last.atFold, isFalse);
      expect(states.last.textDirection, TextDirection.ltr);

      final gesture = await tester.startGesture(tester.getCenter(_divider));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(states.last.isDragging, isTrue);
      expect(states.last.isActive, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(states.last.isDragging, isFalse);
    });

    testWidgets('gets the hover of the pointer', (tester) async {
      final states = <FoldableDividerState>[];

      await _pump(
        tester,
        dividerBuilder: (context, state) {
          states.add(state);
          return const SizedBox(key: Key('custom_handle'));
        },
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();

      await mouse.moveTo(tester.getCenter(_divider));
      await tester.pumpAndSettle();

      expect(states.last.isHovering, isTrue);
      expect(states.last.isActive, isTrue);
    });

    testWidgets('is not called around a hinge, where there is no handle', (
      tester,
    ) async {
      var calls = 0;

      await _pump(
        tester,
        features: [
          DisplayFeature(
            bounds: const Rect.fromLTRB(680, 0, 720, 600),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
        dividerBuilder: (context, state) {
          calls++;
          return const SizedBox(key: Key('custom_handle'));
        },
      );

      expect(calls, 0);
      expect(find.byKey(const Key('custom_handle')), findsNothing);
      expect(tester.getSize(_divider).width, 40);
    });
  });

  group('FoldableScaffoldThemeData', () {
    const red = Color(0xFFF44336);
    const blue = Color(0xFF2196F3);
    const base = FoldableScaffoldThemeData(
      dividerColor: red,
      handleSize: Size(4, 50),
    );

    test('copyWith keeps what it does not change', () {
      final changed = base.copyWith(dividerColor: blue);

      expect(changed.dividerColor, blue);
      expect(changed.handleSize, const Size(4, 50));
      expect(changed, isNot(base));
      expect(changed.copyWith(dividerColor: red), base);
      expect(changed.hashCode, isNot(base.hashCode));
    });

    test('merge puts the other theme on top, field by field', () {
      const other = FoldableScaffoldThemeData(
        dividerColor: blue,
        handleActiveWidth: 16,
      );
      final merged = base.merge(other);

      expect(merged.dividerColor, blue);
      expect(merged.handleActiveWidth, 16);
      expect(merged.handleSize, const Size(4, 50));
      expect(base.merge(null), base);
    });

    test('lerp goes from one theme to the other', () {
      const other = FoldableScaffoldThemeData(
        dividerColor: blue,
        handleSize: Size(8, 100),
      );

      expect(base.lerp(other, 0), base);
      expect(base.lerp(other, 1), other);
      final halfway = base.lerp(other, 0.5);
      expect(halfway.dividerColor, Color.lerp(red, blue, 0.5));
      expect(halfway.handleSize, const Size(6, 75));
    });

    test('lerp keeps a field that only one side sets', () {
      const withRadius = FoldableScaffoldThemeData(
        handleBorderRadius: BorderRadius.all(Radius.circular(4)),
      );

      expect(base.lerp(withRadius, 0.5).handleBorderRadius, isNotNull);
      expect(const FoldableScaffoldThemeData().lerp(base, 0.5), base);
      expect(base.lerp(null, 0.5), base);
    });

    test('resolve puts the widget theme over the inherited one', () {
      final theme = _themeData.copyWith(
        extensions: const [FoldableScaffoldThemeData(dividerColor: Colors.red)],
      );

      const override = FoldableScaffoldThemeData(
        dividerActiveColor: Colors.teal,
      );
      final resolved = FoldableScaffoldThemeData.resolve(
        theme,
        override: override,
      );

      expect(resolved.dividerColor, Colors.red);
      expect(resolved.dividerActiveColor, Colors.teal);
    });

    test('resolve without any theme keeps every field null', () {
      final resolved = FoldableScaffoldThemeData.resolve(_themeData);

      expect(resolved, const FoldableScaffoldThemeData());
    });

    test('describes its fields to the devtools', () {
      final properties = DiagnosticPropertiesBuilder();
      base.debugFillProperties(properties);

      expect(
        properties.properties.map((property) => property.name),
        containsAll(<String>[
          'dividerColor',
          'dividerActiveColor',
          'handleSize',
          'handleActiveWidth',
          'handleBorderRadius',
          'animationDuration',
        ]),
      );
    });
  });
}
