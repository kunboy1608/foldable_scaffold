import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_core/foldable_core.dart';

void main() {
  group('FoldablePaneTransitions after dispose', () {
    test('begin() after dispose does not assert', () {
      final transitions = FoldablePaneTransitions();
      transitions.dispose();
      // Before the guard this reached notifyListeners() on a disposed
      // ChangeNotifier and asserted.
      expect(transitions.begin, returnsNormally);
    });

    test('end() after dispose does not assert', () {
      final transitions = FoldablePaneTransitions()..begin();
      transitions.dispose();
      // Before the guard this dropped the count to zero and notified a
      // disposed ChangeNotifier.
      expect(transitions.end, returnsNormally);
    });

    test('the count never goes negative', () {
      final transitions = FoldablePaneTransitions();
      transitions.end();
      transitions.end();
      expect(transitions.value, isFalse);
      transitions.begin();
      expect(transitions.value, isTrue);
      transitions.end();
      transitions.end();
      expect(transitions.value, isFalse);
    });
  });
}
