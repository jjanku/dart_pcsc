// ignore_for_file: overridden_fields, non_constant_identifier_names

part of 'pcsc_lib.dart';

// TODO: find a cleaner way of doing this
class PcscLibWin extends PcscLib {
  PcscLibWin(ffi.DynamicLibrary dynamicLibrary) : super(dynamicLibrary);

  @override
  late final _SCardConnectPtr = _lookup<
      ffi.NativeFunction<
          LONG Function(SCARDCONTEXT, LPCSTR, DWORD, DWORD, LPSCARDHANDLE,
              LPDWORD)>>('SCardConnectA');

  @override
  late final _SCardStatusPtr = _lookup<
      ffi.NativeFunction<
          LONG Function(SCARDHANDLE, LPSTR, LPDWORD, LPDWORD, LPDWORD, LPBYTE,
              LPDWORD)>>('SCardStatusA');

  @override
  late final _SCardGetStatusChangePtr = _lookup<
      ffi.NativeFunction<
          LONG Function(SCARDCONTEXT, DWORD, ffi.Pointer<SCARD_READERSTATE>,
              DWORD)>>('SCardGetStatusChangeA');

  @override
  late final _SCardListReaderGroupsPtr =
      _lookup<ffi.NativeFunction<LONG Function(SCARDCONTEXT, LPSTR, LPDWORD)>>(
          'SCardListReaderGroupsA');

  @override
  late final _SCardListReadersPtr = _lookup<
      ffi.NativeFunction<
          LONG Function(
              SCARDCONTEXT, LPCSTR, LPSTR, LPDWORD)>>('SCardListReadersA');
}
