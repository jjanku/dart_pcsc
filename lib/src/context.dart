import 'dart:ffi';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:ffi/ffi.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'native_util.dart';
import 'worker.dart';

class EstablishRequest {
  final Scope scope;
  EstablishRequest(this.scope);
}

class ReleaseRequest {}

class ListRequest {}

class WaitRequest {
  final List<String> readers;
  List<int> states;
  final int timeout;
  WaitRequest(this.readers, this.states, {this.timeout = 1000}) {
    assert(readers.length == states.length);
  }
}

class ConnectRequest {
  final String reader;
  final ShareMode mode;
  final Protocol protocol;
  const ConnectRequest(this.reader, this.mode, this.protocol);
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
      if (message is ConnectRequest) {
        return _connect(message.reader, message.mode, message.protocol);
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
      okOrThrow(pcscLib.SCardEstablishContext(
          scope.value, nullptr, nullptr, phContext));
      _hContext = phContext.value;
      return _hContext;
    });
  }

  void _release() {
    okOrThrow(pcscLib.SCardReleaseContext(_hContext));
  }

  List<String> _listReaders() {
    return using((alloc) {
      final pcchReaders = alloc<DWORD>();
      okOrThrow(
          pcscLib.SCardListReaders(_hContext, nullptr, nullptr, pcchReaders));

      if (pcchReaders.value == 0) return [];

      final mszReaders = alloc<Int8>(pcchReaders.value);
      okOrThrow(pcscLib.SCardListReaders(
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
          pcscLib.SCardGetStatusChange(_hContext, timeout, pStates, length));

      List<int> newStates = [];
      for (var i = 0; i < length; i++) {
        newStates.add(pStates[i].dwEventState);
      }
      return newStates;
    });
  }

  int _connect(String reader, ShareMode mode, Protocol protocol) {
    return using((alloc) {
      final szReader = reader.toNativeUtf8(allocator: alloc).cast<Int8>();
      final phCard = alloc<SCARDHANDLE>();
      final pdwActiveProtocol = alloc<DWORD>();

      okOrThrow(pcscLib.SCardConnect(_hContext, szReader, mode.value,
          protocol.value, phCard, pdwActiveProtocol));

      return phCard.value;
    });
  }
}

class PcscContext {
  late final int _hContext;
  final _worker = Worker(ContextWorkerThread.entryPoint);

  CancelableCompleter<List<String>>? _waitCompleter;

  // TODO: disallow concurrent async ops on context?
  // maybe we could perform some operations on the main isolate this way

  Future<void> establish(Scope scope) async {
    await _worker.start();
    _hContext = await _worker.enqueueRequest(EstablishRequest(scope));
  }

  Future<void> release() async {
    await _worker.enqueueRequest(ReleaseRequest());
    _worker.stop();
  }

  Future<List<String>> listReaders() async {
    try {
      return await _worker.enqueueRequest(ListRequest());
    } on NoReaderException {
      return [];
    }
  }

  void _completeOnState(
    List<String> readers,
    int state,
    CancelableCompleter<List<String>> completer,
  ) async {
    final initStates = List<int>.filled(readers.length, SCARD_STATE_UNAWARE);
    final request = WaitRequest(readers, initStates);

    // this loop is on the main isolate and infinite pcsc timeout is not used,
    // otherwise there might be a race where SCardCancel is called before
    // the operation starts
    while (!completer.isCanceled) {
      late List<int> newStates;
      try {
        newStates = await _worker.enqueueRequest(request);
      } on CancelledException {
        break;
      } on TimeoutException {
        // no change, try again
        continue;
      } on Exception catch (e) {
        // FIXME: ignore more exceptions?
        completer.completeError(e);
        break;
      }

      List<String> satisfied = [];
      for (int i = 0; i < readers.length; i++) {
        if (newStates[i] & state != 0) {
          satisfied.add(readers[i]);
        }
      }
      if (satisfied.isNotEmpty) {
        completer.complete(satisfied);
        break;
      }

      request.states = newStates;
    }

    _waitCompleter = null;
  }

  CancelableOperation<List<String>> _waitForState(
    List<String> readers,
    int state,
  ) {
    if (_waitCompleter != null) {
      throw StateError('Parallel wait operations not allowed');
    }

    final completer = CancelableCompleter<List<String>>(onCancel: _cancel);
    _completeOnState(readers, state, completer);
    _waitCompleter = completer;
    return completer.operation;
  }

  CancelableOperation<void> waitForReaderChange() {
    return _waitForState([r'\\?PnP?\Notification'], SCARD_STATE_CHANGED);
  }

  CancelableOperation<List<String>> waitForCard(List<String> readers) {
    return _waitForState(readers, SCARD_STATE_PRESENT);
  }

  void _cancel() {
    okOrThrow(pcscLib.SCardCancel(_hContext));
    _waitCompleter = null;
  }
}
