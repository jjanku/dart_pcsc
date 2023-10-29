import 'generated/pcsc_lib.dart';

enum Scope {
  user(SCARD_SCOPE_USER),
  terminal(SCARD_SCOPE_TERMINAL),
  system(SCARD_SCOPE_SYSTEM),
  global(SCARD_SCOPE_GLOBAL);

  final int value;
  const Scope(this.value);
}

enum Protocol {
  t0(SCARD_PROTOCOL_T0),
  t1(SCARD_PROTOCOL_T1),
  raw(SCARD_PROTOCOL_RAW),
  t15(SCARD_PROTOCOL_T15),
  any(SCARD_PROTOCOL_ANY);

  final int value;
  const Protocol(this.value);

  factory Protocol.value(int value) {
    return switch (value) {
      SCARD_PROTOCOL_T0 => t0,
      SCARD_PROTOCOL_T1 => t1,
      SCARD_PROTOCOL_RAW => raw,
      SCARD_PROTOCOL_T15 => t15,
      SCARD_PROTOCOL_ANY => any,
      _ => throw ArgumentError('Invalid value'),
    };
  }
}

enum ShareMode {
  exclusive(SCARD_SHARE_EXCLUSIVE),
  shared(SCARD_SHARE_SHARED),
  direct(SCARD_SHARE_DIRECT);

  final int value;
  const ShareMode(this.value);
}

enum Disposition {
  leaveCard(SCARD_LEAVE_CARD),
  resetCard(SCARD_RESET_CARD),
  unpowerCard(SCARD_UNPOWER_CARD),
  ejectCard(SCARD_EJECT_CARD);

  final int value;
  const Disposition(this.value);
}
