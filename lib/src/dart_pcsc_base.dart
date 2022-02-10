import 'dart:ffi';
import 'dart:io';

import 'generated/pcsc_lib.dart';

String _pcscLibName() {
  if (Platform.isLinux) return 'libpcsclite.so.1';
  throw UnsupportedError('Platform unsupported');
}

PcscLib _pcscLibOpen() => PcscLib(DynamicLibrary.open(_pcscLibName()));

late final _pcscLib = _pcscLibOpen();
