import 'dart:async';
import 'package:mqtt_aulas_flutter/src/mqtt/models.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/transport.dart';

class FakeTransport implements MqttTransport {
  final incoming = StreamController<LabMessage>.broadcast(sync: true);
  final lost = StreamController<void>.broadcast(sync: true);
  final subscriptions = <String, int>{};
  final published = <LabMessage>[];
  bool fail = false, closed = false, rejectSubscription = false;
  Completer<void>? connection;
  @override
  Stream<LabMessage> get messages => incoming.stream;
  @override
  Stream<void> get disconnected => lost.stream;
  @override
  Future<void> connect(ConnectionConfig config) async {
    if (fail) throw StateError('secret must never reach UI');
    await connection?.future;
  }

  @override
  Future<void> subscribe(String filter, int qos) async {
    if (rejectSubscription) throw StateError('rejected');
    subscriptions[filter] = qos;
  }

  @override
  Future<void> unsubscribe(String filter) async {
    subscriptions.remove(filter);
  }

  @override
  void publish(String topic, String payload, int qos, {bool retain = false}) {
    published.add(
      LabMessage(topic: topic, payload: payload, qos: qos, retained: retain),
    );
  }

  @override
  void close() {
    closed = true;
  }
}
