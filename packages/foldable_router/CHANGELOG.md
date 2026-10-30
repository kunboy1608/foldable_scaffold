## 0.1.0

* Initial release.
* `FoldableNavigator` with one page stack per branch, split-view panes, offstage pages, Cupertino slides, left-edge swipe back and `FoldableBackButton`.
* `FoldableRouter`: deep links, per-route and global redirects with async support and a loop cap, branch roots, back policy and observers.
* `FoldableRouterDelegate` and `FoldableRouteInformationParser` for `MaterialApp.router`.
* `LazyBranch` builds a branch on its first visit.
* `RouteQuery` reads typed query parameters; `FoldablePath` matches `/record/:id` style patterns.
