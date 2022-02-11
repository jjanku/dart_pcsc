import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'native_util.dart';

late final _pcscLib = pcscLibOpen();

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

  List<String> listReaders() {
    return using((alloc) {
      final pcchReaders = alloc<DWORD>();
      okOrThrow(
          _pcscLib.SCardListReaders(_hContext, nullptr, nullptr, pcchReaders));

      if (pcchReaders.value == 0) return [];

      final mszReaders = alloc<Int8>(pcchReaders.value);
      okOrThrow(_pcscLib.SCardListReaders(
          _hContext, nullptr, mszReaders, pcchReaders));

      return multiStringToDart(mszReaders.cast<Utf8>()).toList();
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
