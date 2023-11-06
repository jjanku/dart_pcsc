import 'dart:async';
import 'dart:typed_data';

import 'package:dart_pcsc/dart_pcsc.dart';
import 'package:test/test.dart';

void main() {
  late Context context;
  late Card card;

  setUp(() async {
    context = Context(Scope.user);
    await context.establish();
  });

  group('Context', () {
    test('list readers', () async {
      await context.listReaders();
    });

    test('wait for reader change', () async {
      final readers1 = await context.listReaders();
      print('waiting for reader change');
      await context.waitForReaderChange().value;
      final readers2 = await context.listReaders();
      expect(readers1, isNot(equals(readers2)));
    }, tags: 'interactive');

    test('cancel wait for reader change', () async {
      final wait = context.waitForReaderChange();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(wait.isCanceled, isFalse);
      await wait.cancel().timeout(
            const Duration(milliseconds: 100),
            onTimeout: () => throw TimeoutException(
              'Cancellation took too long',
            ),
          );
      expect(wait.isCanceled, isTrue);
    });

    test('wait for card', () async {
      final readers = await context.listReaders();
      final withCard = await context.waitForCard(readers).value;
      expect(withCard, isNotEmpty);
      for (var r in withCard) {
        expect(r, isIn(readers));
      }
    });
  });

  group('Card', () {
    setUp(() async {
      final reader = (await context.listReaders()).first;
      card = await context.connect(reader, ShareMode.shared, Protocol.any);
    });

    test('transmit', () async {
      final cmd = Uint8List.fromList([0x00, 0xa4, 0x04, 0x00]);
      final resp = await card.transmit(cmd);
      expect(resp, isNotEmpty);
    });

    tearDown(() async {
      await card.disconnect(Disposition.leaveCard);
    });
  });

  tearDown(() async {
    await context.release();
  });
}
