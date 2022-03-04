import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:ffi/ffi.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'native_util.dart';
import 'worker.dart';

class EstablishRequest {
  final Scope scope;
  const EstablishRequest(this.scope);
}

class ReleaseRequest {
  const ReleaseRequest();
}

class ListRequest {
  const ListRequest();
}

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

class Connection {
  final int hCard;
  final int activeProtocol;
  const Connection(this.hCard, this.activeProtocol);
}

class TransmitRequest {
  final Connection connection;
  final TransferableTypedData data;
  TransmitRequest(this.connection, this.data);
}

class DisconnectRequest {
  final int hCard;
  final Disposition disposition;
  const DisconnectRequest(this.hCard, this.disposition);
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
      if (message is TransmitRequest) {
        return _transmit(message.connection.hCard,
            message.connection.activeProtocol, message.data);
      }
      if (message is DisconnectRequest) {
        return _disconnect(message.hCard, message.disposition);
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

  Connection _connect(String reader, ShareMode mode, Protocol protocol) {
    return using((alloc) {
      final szReader = reader.toNativeUtf8(allocator: alloc).cast<Int8>();
      final phCard = alloc<SCARDHANDLE>();
      final pdwActiveProtocol = alloc<DWORD>();

      okOrThrow(pcscLib.SCardConnect(_hContext, szReader, mode.value,
          protocol.value, phCard, pdwActiveProtocol));

      return Connection(phCard.value, pdwActiveProtocol.value);
    });
  }

  TransferableTypedData _transmit(
    int hCard,
    int activeProtocol,
    TransferableTypedData transData,
  ) {
    return using((alloc) {
      final pcbRecvLength = alloc<DWORD>();
      pcbRecvLength.value = MAX_BUFFER_SIZE_EXTENDED;
      final pbRecvBuffer = alloc<Uint8>(pcbRecvLength.value);

      final pioSendPci = pcscLib.getIoRequest(activeProtocol);

      final data = transData.materialize().asUint8List();
      final pbSendBuffer = alloc<Uint8>(data.length);
      pbSendBuffer.asTypedList(data.length).setAll(0, data);

      okOrThrow(pcscLib.SCardTransmit(hCard, pioSendPci, pbSendBuffer,
          data.length, nullptr, pbRecvBuffer, pcbRecvLength));

      final recvBufferList = pbRecvBuffer.asTypedList(pcbRecvLength.value);
      return TransferableTypedData.fromList([recvBufferList]);
    });
  }

  void _disconnect(int hCard, Disposition disposition) {
    pcscLib.SCardDisconnect(hCard, disposition.value);
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
    await _worker.enqueueRequest(const ReleaseRequest());
    _worker.stop();
  }

  Future<List<String>> listReaders() async {
    try {
      return await _worker.enqueueRequest(const ListRequest());
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

  Future<PcscCard> connect(
    String reader,
    ShareMode mode,
    Protocol protocol,
  ) async {
    Connection connection = await _worker.enqueueRequest(
      ConnectRequest(reader, mode, protocol),
    );
    return PcscCard._internal(connection, this);
  }

  Future<TransferableTypedData> _transmit(
    Connection connection,
    TransferableTypedData data,
  ) =>
      _worker.enqueueRequest(TransmitRequest(connection, data));

  Future<void> _disconnect(Connection connection, Disposition disposition) =>
      _worker.enqueueRequest(DisconnectRequest(connection.hCard, disposition));
}

class PcscCard {
  final Connection _connection;
  final PcscContext _context;

  PcscCard._internal(this._connection, this._context);

  // TODO: add transactions

  Future<Uint8List> transmit(Uint8List data) async {
    final transData = TransferableTypedData.fromList([data]);
    final response = await _context._transmit(_connection, transData);
    return response.materialize().asUint8List();
  }

  Future<void> disconnect(Disposition disposition) =>
      _context._disconnect(_connection, disposition);
}
