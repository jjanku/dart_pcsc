import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'native_util.dart';
import 'worker.dart';

late final _pcscLib = pcscLibOpen();

class EstablishRequest {
  final Scope scope;
  EstablishRequest(this.scope);
}

class ReleaseRequest {}

class ListRequest {}

class WaitRequest {
  List<String> readers;
  List<int> states;
  final int timeout;
  WaitRequest(this.readers, this.states, {this.timeout = 1000}) {
    assert(readers.length == states.length);
  }
}

class ContextWorkerThread extends WorkerThread {
  late final int _hContext;

  ContextWorkerThread(SendPort sendPort) : super(sendPort);

  @override
  handleMessage(message) {
    try {
      if (message is EstablishRequest) return _establish(message.scope);
      if (message is ReleaseRequest) return _release();
      if (message is ListRequest) return _listReaders();
      if (message is WaitRequest) {
        return _waitForChange(
          message.timeout,
          message.readers,
          message.states,
        );
      }
    } on PcscException catch (e) {
      // send back as a result of the future,
      // other errors are thrown inside the worker
      return e;
    }
    throw UnimplementedError();
  }

  static void entryPoint(SendPort sendPort) {
    ContextWorkerThread(sendPort);
  }

  int _establish(Scope scope) {
    // FIXME: resource cleanup when isolate killed?
    return using((alloc) {
      final phContext = alloc<SCARDCONTEXT>();
      okOrThrow(_pcscLib.SCardEstablishContext(
          scope.value, nullptr, nullptr, phContext));
      _hContext = phContext.value;
      return _hContext;
    });
  }

  void _release() {
    okOrThrow(_pcscLib.SCardReleaseContext(_hContext));
  }

  List<String> _listReaders() {
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

  List<int> _waitForChange(
    int timeout,
    List<String> readers,
    List<int> states,
  ) {
    return using((alloc) {
      final length = readers.length;

      final pStates = alloc<SCARD_READERSTATE>(length);
      for (var i = 0; i < length; i++) {
        pStates[i].szReader = readers[i].toNativeUtf8(allocator: alloc).cast();
        pStates[i].dwCurrentState = states[i];
      }

      okOrThrow(
          _pcscLib.SCardGetStatusChange(_hContext, timeout, pStates, length));

      List<int> newStates = [];
      for (var i = 0; i < length; i++) {
        newStates.add(pStates[i].dwEventState);
      }
      return newStates;
    });
  }
}

class PcscContext {
  late final int _hContext;
  final _worker = Worker(ContextWorkerThread.entryPoint);

  Future<void> establish(Scope scope) async {
    await _worker.start();
    _hContext = await _worker.enqueueRequest(EstablishRequest(scope));
  }

  Future<void> release() async {
    await _worker.enqueueRequest(ReleaseRequest());
    _worker.stop();
  }

  Future<List<String>> listReaders() => _worker.enqueueRequest(ListRequest());

  // Future<void> waitForReader() async {}

  // void waitForCard() {}

  void cancel() {
    okOrThrow(_pcscLib.SCardCancel(_hContext));
  }
}
