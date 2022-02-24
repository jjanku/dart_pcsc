import 'dart:typed_data';

import 'package:dart_pcsc/dart_pcsc.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () async {
      final ctx = PcscContext();
      await ctx.establish(Scope.user);
      final cancellable = ctx.waitForReaderChange();
      await Future.delayed(Duration(seconds: 2));
      // cancellable.cancel();
      print(await ctx.listReaders());
      // final readers = await ctx.listReaders();
      // print(readers);
      // final ready = await ctx.waitForCard(readers).value;
      // print(ready);
      // final card = await ctx.connect(ready[0], ShareMode.shared, Protocol.any);
      // final resp = await card.transmit(Uint8List.fromList([1, 2, 3, 4, 5, 6]));
      // print(resp);
      await ctx.release();
    });
  });
}
