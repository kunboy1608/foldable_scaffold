import 'package:flutter/foundation.dart';

/// A fake, in-memory session. The delays stand in for network calls so the
/// router's "pending" behaviour is visible.
class Session extends ChangeNotifier {
  bool _loggedIn = false;
  Future<void>? _restored;

  bool get loggedIn => _loggedIn;

  /// One-time startup work (think: reading a stored token). Slow on the
  /// first call only.
  Future<void> restore() =>
      _restored ??= Future<void>.delayed(const Duration(seconds: 1));

  /// Asks the "server" whether the user is logged in.
  Future<bool> check() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return _loggedIn;
  }

  void login() => _set(true);

  void logout() => _set(false);

  void _set(bool value) {
    if (_loggedIn == value) return;
    _loggedIn = value;
    notifyListeners();
  }

  /// Back to the state of a fresh launch.
  @visibleForTesting
  void reset() {
    _restored = null;
    _set(false);
  }
}

final session = Session();
