import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

abstract class WorkerThread {
  final ReceivePort _receivePort;
  final SendPort _sendPort;

  WorkerThread(this._sendPort) : _receivePort = ReceivePort() {
    // establish 2-way communication
    _receivePort.listen(_onMessage);
    _sendPort.send(_receivePort.sendPort);
  }

  void _onMessage(dynamic message) {
    final result = handleMessage(message);
    _sendPort.send(result);
  }

  dynamic handleMessage(message);
}

class Worker {
  final String debugName;
  final void Function(SendPort) entryPoint;

  late final Isolate _isolate;
  late final ReceivePort _receivePort;
  late final SendPort _sendPort;

  // FIXME: this is ok as long as we don't use async
  // functions in the worker isolate
  final Queue<Completer> _requests = ListQueue();

  Worker(this.entryPoint, {this.debugName = 'worker'});

  Future<void> start() async {
    // FIXME: reinit
    _receivePort = ReceivePort();
    _receivePort.listen(_onResponse);
    _isolate = await Isolate.spawn(
      entryPoint,
      _receivePort.sendPort,
      debugName: debugName,
    );
  }

  void stop() => _isolate.kill();

  void _onResponse(dynamic response) {
    if (response is SendPort) {
      _sendPort = response;
      return;
    }

    final completer = _requests.removeFirst();
    completer.complete(response);
  }

  Future<T> enqueueRequest<T>(request) {
    // FIXME: wait for sendPort?
    final completer = Completer<T>();
    _requests.addLast(completer);
    _sendPort.send(request);
    return completer.future;
  }
}
