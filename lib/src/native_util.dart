import 'dart:ffi';

import 'package:ffi/ffi.dart';

Iterable<String> multiStringToDart(Pointer<Utf8> multiString) sync* {
  while (multiString.cast<Int8>().value != 0) {
    final length = multiString.length;
    yield multiString.toDartString(length: length);
    multiString = Pointer.fromAddress(multiString.address + length + 1);
  }
}
