// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:foldable_dev_tools/foldable_dev_tools.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const DevToolsExample());

class ListRoute extends FoldableRoute {
  const ListRoute();

  @override
  String get path => '/list';

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (var index = 1; index <= 10; index++)
          ListTile(
            title: Text('Item $index'),
            onTap: () => _router.push(DetailRoute(id: '$index')),
          ),
      ],
    );
  }
}

class DetailRoute extends FoldableRoute {
  const DetailRoute({this.id});

  final String? id;

  @override
  String get path => '/detail';

  @override
  Map<String, Object?> get query => {'id': id};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const FoldableBackButton(),
        title: Text('Item ${id ?? ''}'),
      ),
      body: Center(child: Text('Detail of item ${id ?? ''}')),
    );
  }
}

FoldableRoute? _match(Uri uri) {
  return switch (uri.path) {
    '/list' => const ListRoute(),
    '/detail' => DetailRoute(id: RouteQuery.fromUri(uri).string('id')),
    _ => null,
  };
}

final _router = FoldableRouter(
  config: FoldableRouterConfig(
    roots: const [ListRoute()],
    matcher: _match,
    notFound: (uri) => const ListRoute(),
  ),
);

final _navigatorKey = GlobalKey<NavigatorState>();

final _delegate = FoldableRouterDelegate(
  router: _router,
  navigatorKey: _navigatorKey,
  builder: (context) => FoldableNavigator(
    controller: _router.controller,
    builder: (context, body, secondaryBody) {
      return FoldableScaffold(
        topNavigationBuilder: (context, constraints) =>
            AppBar(title: const Text('Open the bug button')),
        bodyBuilder: (_, _) =>
            Stack(children: [const FoldablePaneLayoutObserver(), body]),
        secondaryBodyBuilder: (_, _) => secondaryBody,
      );
    },
  ),
);

/// The router example, with the dev tools overlay on top: size the window,
/// draw a hinge, slow the animations down and watch the navigation log.
class DevToolsExample extends StatelessWidget {
  const DevToolsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'foldable_dev_tools',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      routerDelegate: _delegate,
      routeInformationParser: const FoldableRouteInformationParser(),
      builder: (context, child) {
        // Release safe: the overlay only shows in debug builds.
        return FoldableDevTools(router: _router, child: child!);
      },
    );
  }
}
