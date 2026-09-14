import 'package:flutter/widgets.dart';

/// Widget keys for the lock that covers an idle device.
abstract final class SessionLockKeys {
  static const Key screen = Key('session_lock_screen');
  static const Key password = Key('session_lock_password');
  static const Key unlock = Key('session_lock_unlock');
  static const Key notMe = Key('session_lock_not_me');
  static const Key error = Key('session_lock_error');
}
