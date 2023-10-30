import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'native_util.dart';

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

  Map<String, int> waitForChange(
    int hContext,
    Duration timeout,
    Map<String, int> readerStates,
  ) {
    return using((alloc) {
      final length = readerStates.length;

      final pStates = alloc<SCARD_READERSTATE>(length);
      for (var (i, MapEntry(key: reader, value: state))
          in readerStates.entries.indexed) {
        pStates[i].szReader = reader.toNativeUtf8(allocator: alloc).cast();
        pStates[i].dwCurrentState = state;
      }

      okOrThrow(
        SCardGetStatusChange(hContext, timeout.inMilliseconds, pStates, length),
      );

      return {
        for (var (i, reader) in readerStates.keys.indexed)
          reader: pStates[i].dwEventState
      };
    });
  }

  ({int hCard, Protocol activeProtocol}) connect(
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

      return (
        hCard: phCard.value,
        activeProtocol: Protocol.value(pdwActiveProtocol.value),
      );
    });
  }

  Pointer<SCARD_IO_REQUEST> _getIoRequest(Protocol protocol) =>
      switch (protocol) {
        Protocol.t0 => addresses.g_rgSCardT0Pci,
        Protocol.t1 => addresses.g_rgSCardT1Pci,
        Protocol.raw => addresses.g_rgSCardRawPci,
        _ => throw ArgumentError('Invalid value'),
      };

  Uint8List transmit(
    int hCard,
    Protocol activeProtocol,
    Uint8List data,
  ) {
    return using((alloc) {
      final pcbRecvLength = alloc<DWORD>();
      pcbRecvLength.value = MAX_BUFFER_SIZE_EXTENDED;
      final pbRecvBuffer = alloc<Uint8>(pcbRecvLength.value);

      final pioSendPci = _getIoRequest(activeProtocol);

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

PcscLib pcscLibOpen() {
  if (Platform.isLinux) {
    return PcscLib(DynamicLibrary.open('libpcsclite.so.1'));
  }
  if (Platform.isWindows) {
    return PcscLibWin(DynamicLibrary.open('winscard.dll'));
  }
  throw UnsupportedError('Platform unsupported');
}

final pcscLib = pcscLibOpen();

Future<int> establish(Scope scope) =>
    Isolate.run(() => pcscLib.establish(scope));

Future<void> cancel(int hContext) =>
    Isolate.run(() => pcscLib.cancel(hContext));

Future<void> release(int hContext) =>
    Isolate.run(() => pcscLib.release(hContext));

Future<List<String>> listReaders(int hContext) =>
    Isolate.run(() => pcscLib.listReaders(hContext));

Future<Map<String, int>> waitForChange(
        int hContext, Duration timeout, Map<String, int> readerStates) =>
    Isolate.run(() => pcscLib.waitForChange(hContext, timeout, readerStates));

Future<({int hCard, Protocol activeProtocol})> connect(
        int hContext, String reader, ShareMode mode, Protocol protocol) =>
    Isolate.run(() => pcscLib.connect(hContext, reader, mode, protocol));

Future<Uint8List> transmit(
        int hCard, Protocol activeProtocol, Uint8List data) =>
    Isolate.run(() => pcscLib.transmit(hCard, activeProtocol, data));

Future<void> disconnect(int hCard, Disposition disposition) =>
    Isolate.run(() => pcscLib.disconnect(hCard, disposition));
