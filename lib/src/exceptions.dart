import 'generated/pcsc_lib.dart';

class PcscException implements Exception {
  final int errorCode;
  PcscException(this.errorCode);
}

void okOrThrow(int result) {
  if (result == SCARD_S_SUCCESS) return;
  throw PcscException(result);
}
