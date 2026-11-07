import 'package:material_ui/material_ui.dart';

/// What the last button did, shown on the Home tab.
final lastAction = ValueNotifier<String>('Nothing yet. Try a button below.');

void logAction(String message) => lastAction.value = message;
