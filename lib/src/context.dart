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

  int? _hContextValue;
  int get _hContext => _hContextValue ?? (throw StateError('Invalid context'));

  CancelableCompleter<List<String>>? _waitCompleter;

  Context(this.scope);

  /// Establishes this context.
  ///
  /// This must be the first method called on this.
  /// Await the result before calling other methods.
  Future<void> establish() async {
    _hContextValue = await pcsc.establish(scope);
  }

  /// Releases this context.
  ///
  /// Context cannot be used further after this call.
  Future<void> release() async {
    if (_hContextValue == null) return;
    await _waitCompleter?.operation.cancel();
    await pcsc.release(_hContext);
    _hContextValue = null;
  }

  /// Returns a list of connected card readers.
  Future<List<String>> listReaders() async {
    try {
      return await pcsc.listReaders(_hContext);
    } on NoReaderException {
      return [];
    }
  }

  Future<void> _completeOnState(
    List<String> readers,
    int state,
    CancelableCompleter<List<String>> completer,
  ) async {
    var readerStates = {
      for (var reader in readers) reader: SCARD_STATE_UNAWARE
    };

    while (!completer.isCanceled) {
      late Map<String, int> newReaderStates;
      try {
        newReaderStates = await pcsc.waitForChange(
            _hContext, const Duration(minutes: 1), readerStates);
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

    late Future<void> finished;

    Future<void> cancel() async {
      bool repeat;
      do {
        await pcsc.cancel(_hContext);
        // Ensures that _completeOnState returns before this function returns.
        // If SCardCancel gets called before SCardGetStatusChange, it has no
        // effect and thus the context is blocked. In that case, we repeat
        // the cancellation.
        repeat = await finished
            .then((_) => false)
            .timeout(const Duration(milliseconds: 50), onTimeout: () => true);
        print(repeat);
      } while (repeat);

      _waitCompleter = null;
    }

    final completer = CancelableCompleter<List<String>>(onCancel: cancel);
    finished = _completeOnState(readers, state, completer);
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
