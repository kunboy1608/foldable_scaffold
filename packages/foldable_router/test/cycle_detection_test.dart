import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_router/src/redirect_resolver.dart';

/// A shell at `/` whose branch root is also at `/` (segment `''`).
class _ShellRoute extends FoldableShellRoute {
  const _ShellRoute();
  @override
  List<FoldableShellChildRoute> get branches => const [_BranchRoot()];
  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      shell.child;
}

class _BranchRoot extends FoldableShellChildRoute {
  const _BranchRoot();
  @override
  String get segment => '';
  @override
  FoldableShellParent get parent => const _ShellRoute();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// A real cycle: an instance whose parent chain revisits itself.
class _SelfParentRoute extends FoldableFlatRoute {
  const _SelfParentRoute();
  @override
  String get segment => 'self';
  @override
  FoldableFlatRoute? get parent => this;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  test(
    'chainOf accepts a shell branch root equal to the shell (same fullPath)',
    () {
      // _ShellRoute and _BranchRoot are different instances but both resolve
      // to '/': `chain.contains` (route `==`) would falsely report a cycle.
      final chain = RedirectResolver.chainOf(const _BranchRoot());
      expect(chain, [const _ShellRoute(), const _BranchRoot()]);
    },
  );

  test('chainOf still throws on a genuine instance cycle', () {
    expect(
      () => RedirectResolver.chainOf(const _SelfParentRoute()),
      throwsA(isA<StateError>()),
    );
  });
}
