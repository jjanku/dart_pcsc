import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'generated/pcsc_lib.dart';
import 'native_util.dart';

void _okOrThrow(int result) {
  // constants extraced using ffigen are positive dart signed 64-bit ints,
  // pcsc functions return LONG which is unsigned 32-bit ints
  result = result.toUnsigned(8 * sizeOf<LONG>());
  if (result == SCARD_S_SUCCESS) return;

  switch (result) {
    case SCARD_E_TIMEOUT:
      throw TimeoutException();
    case SCARD_E_CANCELLED:
      throw CancelledException();
    case SCARD_E_NO_READERS_AVAILABLE:
      throw NoReaderException();
    default:
      throw CardException(result);
  }
}

extension _Wrapper on PcscLib {
  int establish(Scope scope) {
    return using((alloc) {
      final phContext = alloc<SCARDCONTEXT>();
      _okOrThrow(
        SCardEstablishContext(scope.value, nullptr, nullptr, phContext),
      );
      return phContext.value;
    });
  }

  void cancel(int hContext) {
    _okOrThrow(SCardCancel(hContext));
  }

  void release(int hContext) {
    _okOrThrow(SCardReleaseContext(hContext));
  }

  List<String> listReaders(int hContext) {
    return using((alloc) {
      final pcchReaders = alloc<DWORD>();
      _okOrThrow(SCardListReaders(hContext, nullptr, nullptr, pcchReaders));

      if (pcchReaders.value == 0) return [];

      final mszReaders = alloc<Char>(pcchReaders.value);
      _okOrThrow(SCardListReaders(hContext, nullptr, mszReaders, pcchReaders));

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

      _okOrThrow(
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

      _okOrThrow(
        SCardConnect(
          hContext,
          szReader,
          mode.value,
          protocol.value,
          phCard,
          pdwActiveProtocol,
        ),
      );

      final activeProtocol = switch (pdwActiveProtocol.value) {
        SCARD_PROTOCOL_T0 => Protocol.t0,
        SCARD_PROTOCOL_T1 => Protocol.t1,
        SCARD_PROTOCOL_RAW => Protocol.raw,
        SCARD_PROTOCOL_T15 => Protocol.t15,
        _ => throw ArgumentError('Invalid value'),
      };

      return (hCard: phCard.value, activeProtocol: activeProtocol);
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

      _okOrThrow(
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

PcscLib _pcscLibOpen() {
  if (Platform.isLinux) {
    return PcscLib(DynamicLibrary.open('libpcsclite.so.1'));
  }
  if (Platform.isWindows) {
    return PcscLibWin(DynamicLibrary.open('winscard.dll'));
  }
  if (Platform.isMacOS) {
    return PcscLib(DynamicLibrary.open('/System/Library/Frameworks/PCSC.framework/PCSC'));
  }
  throw UnsupportedError('Platform unsupported');
}

final _pcscLib = _pcscLibOpen();

// Note that these need to be standalone functions so that only the actual
// parameters needed are sent via the SendPort, see
// https://api.flutter.dev/flutter/dart-isolate/Isolate/run.html

Future<int> establish(Scope scope) =>
    Isolate.run(() => _pcscLib.establish(scope));

Future<void> cancel(int hContext) =>
    Isolate.run(() => _pcscLib.cancel(hContext));

Future<void> release(int hContext) =>
    Isolate.run(() => _pcscLib.release(hContext));

Future<List<String>> listReaders(int hContext) =>
    Isolate.run(() => _pcscLib.listReaders(hContext));

Future<Map<String, int>> waitForChange(
        int hContext, Duration timeout, Map<String, int> readerStates) =>
    Isolate.run(() => _pcscLib.waitForChange(hContext, timeout, readerStates));

Future<({int hCard, Protocol activeProtocol})> connect(
        int hContext, String reader, ShareMode mode, Protocol protocol) =>
    Isolate.run(() => _pcscLib.connect(hContext, reader, mode, protocol));

Future<Uint8List> transmit(
        int hCard, Protocol activeProtocol, Uint8List data) =>
    Isolate.run(() => _pcscLib.transmit(hCard, activeProtocol, data));

Future<void> disconnect(int hCard, Disposition disposition) =>
    Isolate.run(() => _pcscLib.disconnect(hCard, disposition));
