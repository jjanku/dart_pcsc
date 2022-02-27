import 'generated/pcsc_lib.dart';

// TODO: Dart does not support enum with values;
// if there's a better way, I'm all ears
class Scope {
  final int value;
  const Scope._(this.value);

  static const user = Scope._(SCARD_SCOPE_USER);
  static const terminal = Scope._(SCARD_SCOPE_TERMINAL);
  static const system = Scope._(SCARD_SCOPE_SYSTEM);
  static const global = Scope._(SCARD_SCOPE_GLOBAL);
}

class Protocol {
  final int value;
  const Protocol._(this.value);

  static const t0 = Protocol._(SCARD_PROTOCOL_T0);
  static const t1 = Protocol._(SCARD_PROTOCOL_T1);
  static const raw = Protocol._(SCARD_PROTOCOL_RAW);
  static const t15 = Protocol._(SCARD_PROTOCOL_T15);
  static const any = Protocol._(SCARD_PROTOCOL_ANY);
}

class ShareMode {
  final int value;
  const ShareMode._(this.value);

  static const exclusive = ShareMode._(SCARD_SHARE_EXCLUSIVE);
  static const shared = ShareMode._(SCARD_SHARE_SHARED);
  static const direct = ShareMode._(SCARD_SHARE_DIRECT);
}

class Disposition {
  final int value;
  const Disposition._(this.value);

  static const leaveCard = Disposition._(SCARD_LEAVE_CARD);
  static const resetCard = Disposition._(SCARD_RESET_CARD);
  static const unpowerCard = Disposition._(SCARD_UNPOWER_CARD);
  static const ejectCard = Disposition._(SCARD_EJECT_CARD);
}
