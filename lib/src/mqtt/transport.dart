import 'models.dart';

/// The adapter owns sockets; the controller owns retry policy and desired topics.
abstract interface class MqttTransport {
  Future<void> connect(ConnectionConfig config);
  Future<void> subscribe(String filter, int qos);
  Future<void> unsubscribe(String filter);
  void publish(String topic, String payload, int qos, {bool retain = false});
  Stream<LabMessage> get messages;
  Stream<void> get disconnected;
  void close();
}

typedef TransportFactory = MqttTransport Function();
