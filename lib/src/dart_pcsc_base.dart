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

  Iterable<String> _multiStringToDart(Pointer<Utf8> multiString) sync* {
    while (multiString.cast<Int8>().value != 0) {
      final length = multiString.length;
      yield multiString.toDartString(length: length);
      multiString = Pointer.fromAddress(multiString.address + length + 1);
    }
  }

  List<String> listReaders() {
    return using((alloc) {
      final pcchReaders = alloc<DWORD>();
      _okOrThrow(
          _pcscLib.SCardListReaders(_hContext, nullptr, nullptr, pcchReaders));

      if (pcchReaders.value == 0) return [];

      final mszReaders = alloc<Int8>(pcchReaders.value);
      _okOrThrow(_pcscLib.SCardListReaders(
          _hContext, nullptr, mszReaders, pcchReaders));

      return _multiStringToDart(mszReaders.cast<Utf8>()).toList();
    });
  }
}
