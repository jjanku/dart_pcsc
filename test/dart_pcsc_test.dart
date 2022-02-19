import 'package:dart_pcsc/dart_pcsc.dart';
import 'package:dart_pcsc/src/constants.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () async {
      final ctx = PcscContext();
      await ctx.establish(Scope.user);
      print(await ctx.listReaders());
      await ctx.release();
    });
  });
}
