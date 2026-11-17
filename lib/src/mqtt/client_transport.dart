import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'client_factory.dart';
import 'models.dart';
import 'transport.dart';

class ClientTransport implements MqttTransport {
  MqttClient? _client;
  final _messages = StreamController<LabMessage>.broadcast();
  final _disconnected = StreamController<void>.broadcast();
  final _subscribing = <String, Completer<void>>{};
  final _unsubscribing = <String, Completer<void>>{};
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  bool _closed = false;
  @override
  Stream<LabMessage> get messages => _messages.stream;
  @override
  Stream<void> get disconnected => _disconnected.stream;

  @override
  Future<void> connect(ConnectionConfig config) async {
    config.validate();
    final client = createClient(config);
    _client = client;
    client
      ..logging(on: false)
      ..setProtocolV311()
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 5000
      ..autoReconnect = false
      ..websocketProtocols = ['mqtt']
      ..connectionMessage = MqttConnectMessage()
          .withClientIdentifier(config.clientId)
          .startClean()
      ..onDisconnected = () {
        if (!_closed) _disconnected.add(null);
      }
      ..onSubscribed = (topic) {
        _finish(_subscribing, topic);
      }
      ..onSubscribeFail = (topic) {
        _finish(_subscribing, topic, rejected: true);
      }
      ..onUnsubscribed = (topic) {
        if (topic != null) _finish(_unsubscribing, topic);
      };
    try {
      await client
          .connect(
            config.username.isEmpty ? null : config.username,
            config.password.isEmpty ? null : config.password,
          )
          .timeout(const Duration(seconds: 8));
      if (_closed ||
          client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('Connection refused.');
      }
      _updates = client.updates!.listen(_receive);
    } catch (_) {
      close();
      throw StateError('MQTT connection failed.');
    }
  }

  void _receive(List<MqttReceivedMessage<MqttMessage>> batch) {
    for (final received in batch) {
      final message = received.payload;
      if (message is! MqttPublishMessage) continue;
      final bytes = message.payload.message;
      // Incoming MQTT payloads can be binary. Decode safely and cap display size.
      final preview = bytes.length > 65536 ? bytes.take(65536).toList() : bytes;
      final text = utf8.decode(preview, allowMalformed: true);
      _messages.add(
        LabMessage(
          topic: received.topic,
          payload: bytes.length > 65536 ? '$text… [truncated]' : text,
          qos: message.header!.qos.index,
          retained: message.header!.retain,
        ),
      );
    }
  }

  void _finish(
    Map<String, Completer<void>> pending,
    String topic, {
    bool rejected = false,
  }) {
    final completer = pending[topic];
    if (completer == null || completer.isCompleted) return;
    if (rejected) {
      completer.completeError(StateError('Subscription rejected.'));
    } else {
      completer.complete();
    }
  }

  Future<void> _ack(
    Map<String, Completer<void>> pending,
    String topic,
    void Function() send,
  ) async {
    if (pending.containsKey(topic)) {
      throw StateError('Operation already pending for this topic.');
    }
    final completer = Completer<void>();
    pending[topic] = completer;
    // Attach the timeout handler before the library may synchronously complete it.
    final result = completer.future.timeout(const Duration(seconds: 5));
    try {
      try {
        send();
      } catch (_) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('MQTT operation failed.'));
        }
      }
      await result;
    } finally {
      pending.remove(topic);
    }
  }

  @override
  Future<void> subscribe(String filter, int qos) {
    validateTopic(filter, filter: true);
    validateQos(qos);
    return _ack(_subscribing, filter, () {
      if (_client!.subscribe(filter, MqttQos.values[qos]) == null) {
        _finish(_subscribing, filter, rejected: true);
      }
    });
  }

  @override
  Future<void> unsubscribe(String filter) =>
      _ack(_unsubscribing, filter, () => _client!.unsubscribe(filter));
  @override
  void publish(String topic, String payload, int qos, {bool retain = false}) {
    validateTopic(topic);
    validatePayload(payload);
    validateQos(qos);
    final builder = MqttClientPayloadBuilder()..addUTF8String(payload);
    _client!.publishMessage(
      topic,
      MqttQos.values[qos],
      builder.payload!,
      retain: retain,
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_updates?.cancel());
    _client?.disconnect();
    for (final pending in [_subscribing, _unsubscribing]) {
      for (final completer in pending.values) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('Disconnected.'));
        }
      }
    }
    unawaited(_messages.close());
    unawaited(_disconnected.close());
  }
}
