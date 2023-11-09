import 'generated/pcsc_lib.dart';

/// Scope of [Context].
///
/// See [Context.establish].
enum Scope {
  /// User domain.
  user(SCARD_SCOPE_USER),

  /// Unused.
  terminal(SCARD_SCOPE_TERMINAL),

  /// System domain.
  ///
  /// Appropriate access permissions may be required.
  system(SCARD_SCOPE_SYSTEM),

  /// Unused.
  global(SCARD_SCOPE_GLOBAL);

  final int value;
  const Scope(this.value);
}

/// Protocol for communication with the card.
enum Protocol {
  /// T=0, character-oriented.
  t0(SCARD_PROTOCOL_T0),

  /// T=1, block-oriented.
  t1(SCARD_PROTOCOL_T1),

  /// Raw, for memory cards.
  raw(SCARD_PROTOCOL_RAW),

  /// T=15.
  t15(SCARD_PROTOCOL_T15),

  /// Either [t0] or [t1].
  ///
  /// When passed to [Context.connect], the used protocol is determined
  /// by the smart card service.
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

/// Type of connection to the card.
///
/// See [Context.connect]
enum ShareMode {
  /// No other applications may use the card.
  exclusive(SCARD_SHARE_EXCLUSIVE),

  /// Other application may use the card.
  shared(SCARD_SHARE_SHARED),

  /// Direct connection to the card reader.
  direct(SCARD_SHARE_DIRECT);

  final int value;
  const ShareMode(this.value);
}

/// Action to take upon disconnecting the card.
///
/// See [Card.disconnect]
enum Disposition {
  /// Do nothing.
  leaveCard(SCARD_LEAVE_CARD),

  /// Rest the card.
  resetCard(SCARD_RESET_CARD),

  /// Power down the card.
  unpowerCard(SCARD_UNPOWER_CARD),

  /// Eject the card.
  ejectCard(SCARD_EJECT_CARD);

  final int value;
  const Disposition(this.value);
}
