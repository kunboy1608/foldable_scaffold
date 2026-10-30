// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Router for foldable apps: one page stack per branch, page slides, swipe
/// back, deep links and redirects. Works with `foldable_scaffold`, but does not
/// depend on it.
library;

export 'package:foldable_core/foldable_core.dart';

export 'src/foldable_navigator.dart';
export 'src/foldable_navigator_controller.dart';
export 'src/foldable_page.dart';
export 'src/lazy_branch.dart';
export 'src/route/foldable_path.dart';
export 'src/route/foldable_route.dart';
export 'src/route/route_query.dart';
export 'src/router/foldable_router.dart';
export 'src/router/foldable_router_config.dart';
export 'src/router/foldable_router_delegate.dart';
export 'src/router/foldable_router_observer.dart';
