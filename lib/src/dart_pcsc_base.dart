import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';

String _pcscLibName() {
  if (Platform.isLinux) return 'libpcsclite.so.1';
  throw UnsupportedError('Platform unsupported');
}

PcscLib _pcscLibOpen() => PcscLib(DynamicLibrary.open(_pcscLibName()));

late final _pcscLib = _pcscLibOpen();

class PcscContext {
  late final int _hContext;

  PcscContext.establish(Scope scope) {
    using((alloc) {
      final phContext = alloc<SCARDCONTEXT>();
      okOrThrow(_pcscLib.SCardEstablishContext(
          scope.value, nullptr, nullptr, phContext));
      _hContext = phContext.value;
    });
  }

  void release() {
    okOrThrow(_pcscLib.SCardReleaseContext(_hContext));
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
      okOrThrow(
          _pcscLib.SCardListReaders(_hContext, nullptr, nullptr, pcchReaders));

      if (pcchReaders.value == 0) return [];

      final mszReaders = alloc<Int8>(pcchReaders.value);
      okOrThrow(_pcscLib.SCardListReaders(
          _hContext, nullptr, mszReaders, pcchReaders));

      return _multiStringToDart(mszReaders.cast<Utf8>()).toList();
    });
  }

  List<String> _waitForState(int timeout, List<String> readers, int state) {
    return using((alloc) {
      final length = readers.length;

      final states = alloc<SCARD_READERSTATE>(length);
      for (var i = 0; i < length; i++) {
        states[i].szReader = readers[i].toNativeUtf8(allocator: alloc).cast();
        states[i].dwCurrentState = SCARD_STATE_UNAWARE;
      }

      while (true) {
        okOrThrow(
            _pcscLib.SCardGetStatusChange(_hContext, timeout, states, length));

        // TODO: check wanted state
        for (var i = 0; i < length; i++) {
          final newState = states[i].dwEventState;
          if (newState == state) ;
          states[i].dwCurrentState = newState;
        }
      }
    });
  }

  void waitForReader() {}

  void waitForCard() {}

  void cancel() {
    okOrThrow(_pcscLib.SCardCancel(_hContext));
  }
}
