import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'constants.dart';
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

class PcscContext {
  late final int _hContext;

  PcscContext.establish(Scope scope) {
    using((alloc) {
      final phContext = alloc<SCARDCONTEXT>();
      _okOrThrow(_pcscLib.SCardEstablishContext(
          scope.value, nullptr, nullptr, phContext));
      _hContext = phContext.value;
    });
  }

  void release() {
    _okOrThrow(_pcscLib.SCardReleaseContext(_hContext));
  }
}
