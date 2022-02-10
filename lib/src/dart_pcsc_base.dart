import 'dart:ffi';
import 'dart:io';

import 'generated/pcsc_lib.dart';

String _pcscLibName() {
  if (Platform.isLinux) return 'libpcsclite.so.1';
  throw UnsupportedError('Platform unsupported');
}

PcscLib _pcscLibOpen() => PcscLib(DynamicLibrary.open(_pcscLibName()));

late final _pcscLib = _pcscLibOpen();

class PcscException implements Exception {
  final int errorCode;
  PcscException(this.errorCode);
}

void _okOrThrow(int result) {
  if (result == SCARD_S_SUCCESS) return;
  throw PcscException(result);
}
