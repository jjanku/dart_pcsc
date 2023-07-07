import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'native_util.dart';

class Connection {
  final int hCard;
  final int activeProtocol;

  const Connection(this.hCard, this.activeProtocol);
}

extension Wrapper on PcscLib {
  int establish(Scope scope) {
    return using((alloc) {
      final phContext = alloc<SCARDCONTEXT>();
      okOrThrow(
        SCardEstablishContext(scope.value, nullptr, nullptr, phContext),
      );
      return phContext.value;
    });
  }

  void cancel(int hContext) {
    okOrThrow(SCardCancel(hContext));
  }

  void release(int hContext) {
    okOrThrow(SCardReleaseContext(hContext));
  }

  List<String> listReaders(int hContext) {
    return using((alloc) {
      final pcchReaders = alloc<DWORD>();
      okOrThrow(SCardListReaders(hContext, nullptr, nullptr, pcchReaders));

      if (pcchReaders.value == 0) return [];

      final mszReaders = alloc<Char>(pcchReaders.value);
      okOrThrow(SCardListReaders(hContext, nullptr, mszReaders, pcchReaders));

      return multiStringToDart(mszReaders.cast<Utf8>()).toList();
    });
  }

  List<int> waitForChange(
    int hContext,
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

      okOrThrow(SCardGetStatusChange(hContext, timeout, pStates, length));

      List<int> newStates = [];
      for (var i = 0; i < length; i++) {
        newStates.add(pStates[i].dwEventState);
      }
      return newStates;
    });
  }

  Connection connect(
    int hContext,
    String reader,
    ShareMode mode,
    Protocol protocol,
  ) {
    return using((alloc) {
      final szReader = reader.toNativeUtf8(allocator: alloc).cast<Char>();
      final phCard = alloc<SCARDHANDLE>();
      final pdwActiveProtocol = alloc<DWORD>();

      okOrThrow(
        SCardConnect(
          hContext,
          szReader,
          mode.value,
          protocol.value,
          phCard,
          pdwActiveProtocol,
        ),
      );

      return Connection(phCard.value, pdwActiveProtocol.value);
    });
  }

  Uint8List transmit(
    int hCard,
    int activeProtocol,
    Uint8List data,
  ) {
    return using((alloc) {
      final pcbRecvLength = alloc<DWORD>();
      pcbRecvLength.value = MAX_BUFFER_SIZE_EXTENDED;
      final pbRecvBuffer = alloc<Uint8>(pcbRecvLength.value);

      final pioSendPci = getIoRequest(activeProtocol);

      final pbSendBuffer = alloc<Uint8>(data.length);
      pbSendBuffer.asTypedList(data.length).setAll(0, data);

      okOrThrow(
        SCardTransmit(
          hCard,
          pioSendPci,
          pbSendBuffer.cast<UnsignedChar>(),
          data.length,
          nullptr,
          pbRecvBuffer.cast<UnsignedChar>(),
          pcbRecvLength,
        ),
      );

      return pbRecvBuffer.asTypedList(pcbRecvLength.value);
    });
  }

  void disconnect(int hCard, Disposition disposition) {
    SCardDisconnect(hCard, disposition.value);
  }
}

Future<int> establish(Scope scope) =>
    Isolate.run(() => pcscLib.establish(scope));

Future<void> cancel(int hContext) =>
    Isolate.run(() => pcscLib.cancel(hContext));

Future<void> release(int hContext) =>
    Isolate.run(() => pcscLib.release(hContext));

Future<List<String>> listReaders(int hContext) =>
    Isolate.run(() => pcscLib.listReaders(hContext));

Future<List<int>> waitForChange(
        int hContext, int timeout, List<String> readers, List<int> states) =>
    Isolate.run(
        () => pcscLib.waitForChange(hContext, timeout, readers, states));

Future<Connection> connect(
        int hContext, String reader, ShareMode mode, Protocol protocol) =>
    Isolate.run(() => pcscLib.connect(hContext, reader, mode, protocol));

Future<Uint8List> transmit(int hCard, int activeProtocol, Uint8List data) =>
    Isolate.run(() => pcscLib.transmit(hCard, activeProtocol, data));

Future<void> disconnect(int hCard, Disposition disposition) =>
    Isolate.run(() => pcscLib.disconnect(hCard, disposition));
