import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A page named `/name`. [log] records every `onPopInvoked` call as
/// `name:didPop:result`.
FoldablePage<Object?> _page(
  String name, {
  bool canPop = true,
  List<String>? log,
}) {
  return FoldablePage<Object?>(
    name: '/$name',
    canPop: canPop,
    onPopInvoked: (didPop, result) => log?.add('$name:$didPop:$result'),
    child: Text(name),
  );
}

/// A controller that is disposed when the test ends.
FoldableNavigatorController _single(List<Page<Object?>> pages) {
  final controller = FoldableNavigatorController.single(pages);
  addTearDown(controller.dispose);
  return controller;
}

/// The names of the pages of [branch] (default: the current branch).
List<String?> _names(FoldableNavigatorController controller, {int? branch}) {
  final pages = branch == null ? controller.pages : controller.pagesOf(branch);
  return [for (final page in pages) page.name];
}

/// Records whether a future completed, and with what.
class _Result {
  _Result(Future<dynamic> future) {
    future.then((result) {
      done = true;
      value = result;
    });
  }

  bool done = false;
  Object? value;
}

void main() {
  group('push', () {
    test('completes with the result given to pop', () async {
      final controller = _single([_page('root')]);

      final future = controller.push<String>(
        const FoldablePage<String>(name: '/typed', child: Text('typed')),
      );
      expect(controller.pop('done'), isTrue);

      expect(await future, 'done');
    });

    test('completes with null when the page is removed another way', () async {
      final controller = _single([_page('root')]);

      final result = _Result(controller.push(_page('a')));
      controller.popToRoot();
      await pumpEventQueue();

      expect(result.done, isTrue);
      expect(result.value, isNull);
    });

    test('adds to the given branch without switching to it', () {
      final controller = FoldableNavigatorController(
        branches: [
          [_page('home')],
          [_page('inbox')],
        ],
      );
      addTearDown(controller.dispose);

      controller.push(_page('detail'), branch: 1);

      expect(controller.currentIndex, 0);
      expect(_names(controller, branch: 0), ['/home']);
      expect(_names(controller, branch: 1), ['/inbox', '/detail']);
    });
  });

  group('pushAndRemoveUntil', () {
    test('removes pages down to the match and adds the page, once', () async {
      final controller = _single([_page('root')]);
      final a = controller.push(_page('a'));
      final b = controller.push(_page('b'));
      var notified = 0;
      controller.addListener(() => notified++);

      final c = controller.pushAndRemoveUntil(
        _page('c'),
        (page) => page.name == '/a',
      );

      expect(_names(controller), ['/root', '/a', '/c']);
      expect(notified, 1);

      final resultA = _Result(a);
      final resultB = _Result(b);
      final resultC = _Result(c);
      await pumpEventQueue();
      // The removed page completes with null, the others are still pending.
      expect(resultB.done, isTrue);
      expect(resultB.value, isNull);
      expect(resultA.done, isFalse);
      expect(resultC.done, isFalse);

      controller.pop('result');
      await pumpEventQueue();
      expect(resultC.value, 'result');
    });

    test('removes every page when the predicate never matches', () {
      final controller = _single([_page('root')]);
      controller.push(_page('a'));

      controller.pushAndRemoveUntil(_page('c'), (page) => false);

      expect(_names(controller), ['/c']);
    });
  });

  group('pushAndReplace', () {
    test('swaps the top page for the new one, once', () async {
      final controller = _single([_page('root')]);
      final a = controller.push(_page('a'));
      var notified = 0;
      controller.addListener(() => notified++);

      final b = controller.pushAndReplace(_page('b'));

      expect(_names(controller), ['/root', '/b']);
      expect(notified, 1);

      final resultA = _Result(a);
      final resultB = _Result(b);
      await pumpEventQueue();
      expect(resultA.done, isTrue);
      expect(resultA.value, isNull);
      expect(resultB.done, isFalse);

      controller.pop('result');
      await pumpEventQueue();
      expect(resultB.value, 'result');
    });
  });

  group('popUntil and popToRoot', () {
    test('popUntil stops at the first match and notifies once', () async {
      final controller = _single([_page('root')]);
      controller.push(_page('a'));
      final b = _Result(controller.push(_page('b')));
      final c = _Result(controller.push(_page('c')));
      var notified = 0;
      controller.addListener(() => notified++);

      controller.popUntil((page) => page.name == '/a');
      await pumpEventQueue();

      expect(_names(controller), ['/root', '/a']);
      expect(notified, 1);
      expect(b.done, isTrue);
      expect(b.value, isNull);
      expect(c.done, isTrue);
    });

    test('popUntil keeps the first page even if nothing matches', () {
      final controller = _single([_page('root')]);
      controller.push(_page('a'));
      controller.push(_page('b'));

      controller.popUntil((page) => false);

      expect(_names(controller), ['/root']);
      expect(controller.canPop, isFalse);
    });

    test('popUntil does not notify when there is nothing to remove', () {
      final controller = _single([_page('root')]);
      controller.push(_page('a'));
      var notified = 0;
      controller.addListener(() => notified++);

      controller.popUntil((page) => page.name == '/a');
      controller.popToRoot(); // removes a
      controller.popToRoot(); // nothing left to remove

      expect(notified, 1);
    });

    test('popToRoot leaves only the first page', () async {
      final controller = _single([_page('root')]);
      final a = _Result(controller.push(_page('a')));
      controller.push(_page('b'));

      controller.popToRoot();
      await pumpEventQueue();

      expect(_names(controller), ['/root']);
      expect(a.done, isTrue);
    });

    test('popToRoot of another branch does not switch to it', () {
      final controller = FoldableNavigatorController(
        branches: [
          [_page('home')],
          [_page('inbox')],
        ],
      );
      addTearDown(controller.dispose);
      controller.push(_page('detail'), branch: 1);

      controller.popToRoot(branch: 1);

      expect(controller.currentIndex, 0);
      expect(_names(controller, branch: 1), ['/inbox']);
    });
  });

  group('pop', () {
    test('removes the top page, tells it and delivers the result', () async {
      final log = <String>[];
      final controller = _single([_page('root')]);
      final result = _Result(controller.push(_page('a', log: log)));

      expect(controller.pop('r'), isTrue);
      await pumpEventQueue();

      expect(_names(controller), ['/root']);
      expect(log, ['a:true:r']);
      expect(result.value, 'r');
    });

    test('is refused when Page.canPop is false', () async {
      final log = <String>[];
      final controller = _single([_page('root')]);
      final result = _Result(
        controller.push(_page('locked', canPop: false, log: log)),
      );
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.pop('r'), isFalse);
      await pumpEventQueue();

      expect(_names(controller), ['/root', '/locked']);
      expect(log, ['locked:false:r']);
      expect(result.done, isFalse);
      expect(notified, 0);
    });

    test('never removes the last page of a branch', () {
      final log = <String>[];
      final controller = _single([_page('root', log: log)]);

      expect(controller.canPop, isFalse);
      expect(controller.pop(), isFalse);
      expect(log, isEmpty);
      expect(_names(controller), ['/root']);
    });
  });

  group('popPage', () {
    test(
      'removes a page that is not on top, with the pages above it',
      () async {
        final log = <String>[];
        final controller = _single([_page('root')]);
        final a = _Result(controller.push(_page('a', log: log)));
        final b = _Result(controller.push(_page('b', log: log)));
        final c = _Result(controller.push(_page('c', log: log)));
        final pageA = controller.pages[1];
        var notified = 0;
        controller.addListener(() => notified++);

        expect(controller.popPage(pageA, 'r'), isTrue);
        await pumpEventQueue();

        expect(_names(controller), ['/root']);
        expect(notified, 1);
        // The pages above are removed first, with a null result.
        expect(log, ['c:true:null', 'b:true:null', 'a:true:r']);
        expect(a.value, 'r');
        expect(b.done, isTrue);
        expect(b.value, isNull);
        expect(c.done, isTrue);
        expect(c.value, isNull);
      },
    );

    test('never removes the first page, only what is above it', () async {
      final controller = _single([_page('root')]);
      final a = _Result(controller.push(_page('a')));
      final b = _Result(controller.push(_page('b')));
      final root = controller.pages.first;

      expect(controller.popPage(root, 'r'), isTrue);
      await pumpEventQueue();

      expect(_names(controller), ['/root']);
      expect(a.done, isTrue);
      expect(b.done, isTrue);
    });

    test('on the top page it is the same as pop', () async {
      final controller = _single([_page('root')]);
      final a = _Result(controller.push(_page('a')));

      expect(controller.popPage(controller.pages.last, 'x'), isTrue);
      await pumpEventQueue();

      expect(_names(controller), ['/root']);
      expect(a.value, 'x');
    });

    test('on the only page of a branch does nothing', () {
      final controller = _single([_page('root')]);

      expect(controller.popPage(controller.pages.first), isFalse);
      expect(_names(controller), ['/root']);
    });

    test('is refused when the page cannot be popped', () async {
      final log = <String>[];
      final controller = _single([_page('root')]);
      controller.push(_page('locked', canPop: false, log: log));
      controller.push(_page('b'));
      final locked = controller.pages[1];
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.popPage(locked, 'r'), isFalse);

      expect(_names(controller), ['/root', '/locked', '/b']);
      expect(log, ['locked:false:r']);
      expect(notified, 0);
    });

    test('finds the page in a branch that is not on screen', () {
      final controller = FoldableNavigatorController(
        branches: [
          [_page('home')],
          [_page('inbox')],
        ],
      );
      addTearDown(controller.dispose);
      controller.push(_page('a'), branch: 0);
      controller.push(_page('b'), branch: 0);
      controller.push(_page('c'), branch: 1);
      controller.openBranch(1);
      final pageA = controller.pagesOf(0)[1];

      expect(controller.popPage(pageA), isTrue);

      expect(_names(controller, branch: 0), ['/home']);
      expect(_names(controller, branch: 1), ['/inbox', '/c']);
    });

    test('a page that is not in any branch does nothing', () {
      final controller = _single([_page('root')]);
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.popPage(_page('stranger')), isFalse);
      expect(notified, 0);
    });
  });

  group('setPages', () {
    test('completes the futures of removed pages with null', () async {
      final root = _page('root');
      final controller = _single([root]);
      final a = _Result(controller.push(_page('a')));
      final b = _Result(controller.push(_page('b')));
      final pageA = controller.pages[1];

      controller.setPages([root, pageA, _page('c')]);
      await pumpEventQueue();

      expect(_names(controller), ['/root', '/a', '/c']);
      expect(b.done, isTrue);
      expect(b.value, isNull);
      // A page that stayed keeps waiting for its own pop.
      expect(a.done, isFalse);

      controller.popPage(pageA, 'later');
      await pumpEventQueue();
      expect(a.value, 'later');
    });

    test('replaces the pages of the given branch only', () {
      final controller = FoldableNavigatorController(
        branches: [
          [_page('home')],
          [_page('inbox')],
        ],
      );
      addTearDown(controller.dispose);

      controller.setPages([_page('other')], branch: 1);

      expect(_names(controller, branch: 0), ['/home']);
      expect(_names(controller, branch: 1), ['/other']);
      expect(controller.currentIndex, 0);
    });
  });

  group('batch', () {
    test('notifies once, after all mutations', () {
      final controller = _single([_page('root')]);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.batch(() {
        controller.push(_page('a'));
        controller.push(_page('b'));
        controller.popUntil((page) => page.name == '/a');
        expect(notified, 0);
      });

      expect(notified, 1);
      expect(_names(controller), ['/root', '/a']);
    });

    test('a nested batch notifies once, at the end of the outer one', () {
      final controller = _single([_page('root')]);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.batch(() {
        controller.push(_page('a'));
        controller.batch(() {
          controller.push(_page('b'));
        });
        // The inner batch ending does not flush.
        expect(notified, 0);
        controller.push(_page('c'));
      });

      expect(notified, 1);
      expect(_names(controller), ['/root', '/a', '/b', '/c']);
    });

    test('does not notify when nothing changed', () {
      final controller = _single([_page('root')]);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.batch(() {});
      controller.batch(controller.popToRoot);

      expect(notified, 0);
    });

    test('still notifies, and rethrows, when a mutation throws', () {
      final controller = _single([_page('root')]);
      var notified = 0;
      controller.addListener(() => notified++);

      expect(
        () => controller.batch(() {
          controller.push(_page('a'));
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(notified, 1);
      // The depth was reset: the next change notifies right away.
      controller.push(_page('b'));
      expect(notified, 2);
    });

    test('openBranch inside a batch is deferred too', () {
      final controller = FoldableNavigatorController(
        branches: [
          [_page('home')],
          [_page('inbox')],
        ],
      );
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.batch(() {
        controller.popToRoot(branch: 1);
        controller.openBranch(1);
        expect(notified, 0);
      });

      expect(controller.currentIndex, 1);
      expect(notified, 1);
    });
  });

  test('openBranch to the branch on screen does not notify', () {
    final controller = FoldableNavigatorController(
      branches: [
        [_page('home')],
        [_page('inbox')],
      ],
    );
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);

    controller.openBranch(0);
    expect(notified, 0);

    controller.openBranch(1);
    expect(notified, 1);
    expect(controller.currentIndex, 1);
  });

  test('dispose completes pending futures with null', () async {
    final controller = FoldableNavigatorController.single([_page('root')]);
    final a = _Result(controller.push(_page('a')));
    final b = _Result(controller.push(_page('b')));

    controller.dispose();
    await pumpEventQueue();

    expect(a.done, isTrue);
    expect(a.value, isNull);
    expect(b.done, isTrue);
    expect(b.value, isNull);
  });
}
