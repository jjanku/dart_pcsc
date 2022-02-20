import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'generated/pcsc_lib.dart';

String _pcscLibName() {
  if (Platform.isLinux) return 'libpcsclite.so.1';
  throw UnsupportedError('Platform unsupported');
}

PcscLib pcscLibOpen() => PcscLib(DynamicLibrary.open(_pcscLibName()));

late final pcscLib = pcscLibOpen();

Iterable<String> multiStringToDart(Pointer<Utf8> multiString) sync* {
  while (multiString.cast<Int8>().value != 0) {
    final length = multiString.length;
    yield multiString.toDartString(length: length);
    multiString = Pointer.fromAddress(multiString.address + length + 1);
  }
}

extension CardIoRequest on PcscLib {
  SCARD_IO_REQUEST getIoRequest(int protocol) {
    switch (protocol) {
      case SCARD_PROTOCOL_T0:
        return g_rgSCardT0Pci;
      case SCARD_PROTOCOL_T1:
        return g_rgSCardT1Pci;
      case SCARD_PROTOCOL_RAW:
        return g_rgSCardRawPci;
      default:
        throw ArgumentError('Unknown protocol');
    }
  }
}
