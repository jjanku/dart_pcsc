import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'wrapper.dart' as pcsc;

class PcscContext {
  final Scope scope;

  late final int _hContext;
  CancelableCompleter<List<String>>? _waitCompleter;

  PcscContext(this.scope);

  Future<void> establish() async {
    _hContext = await pcsc.establish(scope);
  }

  Future<void> release() async {
    await _waitCompleter?.operation.cancel();
    await pcsc.release(_hContext);
  }

  Future<List<String>> listReaders() async {
    try {
      return await pcsc.listReaders(_hContext);
    } on NoReaderException {
      return [];
    }
  }

  void _completeOnState(
    List<String> readers,
    int state,
    CancelableCompleter<List<String>> completer,
  ) async {
    var readerStates = {
      for (var reader in readers) reader: SCARD_STATE_UNAWARE
    };

    // this loop is on the main isolate and infinite pcsc timeout is not used,
    // otherwise there might be a race where SCardCancel is called before
    // the operation starts
    while (!completer.isCanceled) {
      late Map<String, int> newReaderStates;
      try {
        newReaderStates = await pcsc.waitForChange(
            _hContext, const Duration(seconds: 1), readerStates);
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

      final satisfied = [
        for (var MapEntry(key: reader, value: newState)
            in newReaderStates.entries)
          if (newState & state != 0) reader
      ];
      if (satisfied.isNotEmpty) {
        completer.complete(satisfied);
        break;
      }

      readerStates = newReaderStates;
    }

    _waitCompleter = null;
  }

  CancelableOperation<List<String>> _waitForState(
    List<String> readers,
    int state,
  ) {
    if (readers.isEmpty) {
      throw ArgumentError('Cannot wait for nothing');
    }
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

  Future<void> _cancel() async {
    await pcsc.cancel(_hContext);
    _waitCompleter = null;
  }

  Future<PcscCard> connect(
    String reader,
    ShareMode mode,
    Protocol protocol,
  ) async {
    final connection = await pcsc.connect(_hContext, reader, mode, protocol);
    return PcscCard._internal(connection.hCard, connection.activeProtocol);
  }
}

class PcscCard {
  final int _hCard;
  final Protocol activeProtocol;

  PcscCard._internal(this._hCard, this.activeProtocol);

  // TODO: add transactions

  Future<Uint8List> transmit(Uint8List data) =>
      pcsc.transmit(_hCard, activeProtocol, data);

  Future<void> disconnect(Disposition disposition) =>
      pcsc.disconnect(_hCard, disposition);
}
