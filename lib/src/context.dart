import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'wrapper.dart' as pcsc;

/// Connection to the smart card service.
///
/// A created context must be [establish]-ed before any other methods
/// can be used. Once the context is no longer needed, it must be [release]-ed
/// so that all allocated resources are freed properly.
/// ```dart
/// final context = Context(Scope.user);
/// await context.establish();
/// // do something useful with the context
/// await context.release();
/// ```
///
/// All operations requested from a given context are handled synchronously.
/// Calling a method while another one has not finished yet may become an error
/// in the future. If you need to perform some operations in parallel, allocate
/// multiple contexts.
class Context {
  final Scope scope;

  late final int _hContext;
  CancelableCompleter<List<String>>? _waitCompleter;

  Context(this.scope);

  /// Establishes this context.
  ///
  /// This must be the first method called on this.
  /// Await the result before calling other methods.
  Future<void> establish() async {
    _hContext = await pcsc.establish(scope);
  }

  /// Releases this context.
  ///
  /// Context cannot be used further after this call.
  Future<void> release() async {
    await _waitCompleter?.operation.cancel();
    await pcsc.release(_hContext);
  }

  /// Returns a list of connected card readers.
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

  /// Waits for a reader to be added or removed.
  ///
  /// This operation can be cancelled.
  CancelableOperation<void> waitForReaderChange() {
    return _waitForState([r'\\?PnP?\Notification'], SCARD_STATE_CHANGED);
  }

  /// Waits until a card is present in one of the [readers].
  ///
  /// Returns a subset of [readers] that do contain a card.
  /// This operation can be cancelled.
  CancelableOperation<List<String>> waitForCard(List<String> readers) {
    return _waitForState(readers, SCARD_STATE_PRESENT);
  }

  Future<void> _cancel() async {
    await pcsc.cancel(_hContext);
    _waitCompleter = null;
  }

  /// Connects to a card in the [reader].
  Future<Card> connect(
    String reader,
    ShareMode mode,
    Protocol protocol,
  ) async {
    final connection = await pcsc.connect(_hContext, reader, mode, protocol);
    return Card._internal(connection.hCard, connection.activeProtocol);
  }
}

/// Connection to a smart card.
///
/// This can be established using [Context.connect].
class Card {
  final int _hCard;
  final Protocol activeProtocol;

  Card._internal(this._hCard, this.activeProtocol);

  // TODO: add transactions

  /// Sends [data] to this card and returns its response.
  Future<Uint8List> transmit(Uint8List data) =>
      pcsc.transmit(_hCard, activeProtocol, data);

  /// Disconnects this card.
  Future<void> disconnect(Disposition disposition) =>
      pcsc.disconnect(_hCard, disposition);
}
