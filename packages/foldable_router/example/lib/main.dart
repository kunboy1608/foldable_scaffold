import 'package:material_ui/material_ui.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'routes.dart';

void main() {
  usePathUrlStrategy();
  runApp(ExampleApp(router: createRouter()));
}
