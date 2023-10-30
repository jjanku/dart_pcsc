import 'dart:typed_data';

import 'package:dart_pcsc/dart_pcsc.dart';

void main() async {
  final context = Context(Scope.user);
  try {
    await context.establish();

    List<String> readers = await context.listReaders();

    if (readers.isEmpty) {
      print('No readers');
      return;
    }
    print('Readers: $readers');

    print('Waiting for card');
    List<String> withCard = await context.waitForCard(readers).value;

    print('Connecting to card in ${withCard.first}');
    Card card = await context.connect(
      withCard.first,
      ShareMode.shared,
      Protocol.any,
    );

    print('Transmitting');
    Uint8List resp = await card.transmit(
      Uint8List.fromList([0x00, 0xa4, 0x04, 0x00, 1, 2, 3]),
    );
    int status = (resp[0] << 8) + resp[1];
    print('Status: 0x${status.toRadixString(16)}');

    await card.disconnect(Disposition.resetCard);
  } finally {
    await context.release();
  }
}
