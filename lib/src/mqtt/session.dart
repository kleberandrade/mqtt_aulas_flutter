import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'transport.dart';

class MqttSession extends ChangeNotifier {
  MqttSession(
    this._factory, {
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.historyLimit = 100,
  }) : assert(maxRetries >= 0),
       assert(historyLimit > 0);
  final TransportFactory _factory;
  final int maxRetries, historyLimit;
  final Duration retryDelay;
  SessionPhase _phase = SessionPhase.disconnected;
  SessionPhase get phase => _phase;
  String? error;
  int retryCount = 0;
  final _topics = <String, int>{};
  final _history = <LabMessage>[];
  Map<String, int> get subscriptions => Map.unmodifiable(_topics);
  List<LabMessage> get history => List.unmodifiable(_history);
  MqttTransport? _client;
  ConnectionConfig? _config;
  StreamSubscription<LabMessage>? _messages;
  StreamSubscription<void>? _lost;
  Timer? _retry;
  int _generation = 0;
  bool _disposed = false;

  Future<void> connect(ConnectionConfig config) async {
    config.validate(web: kIsWeb);
    disconnect();
    _topics.clear();
    _config = config;
    retryCount = 0;
    error = null;
    _setPhase(SessionPhase.connecting);
    await _open(_generation);
  }

  Future<void> _open(int generation) async {
    final client = _factory();
    _client = client;
    try {
      await client.connect(_config!);
      if (generation != _generation) {
        client.close();
        return;
      }
      _messages = client.messages.listen(_record);
      _lost = client.disconnected.listen((_) => _connectionLost(generation));
      for (final topic in _topics.entries) {
        await client.subscribe(topic.key, topic.value);
        if (generation != _generation) return;
      }
      error = null;
      _setPhase(SessionPhase.connected);
    } catch (_) {
      if (generation == _generation) _connectionLost(generation);
      client.close();
    }
  }

  void _connectionLost(int generation) {
    if (generation != _generation || _disposed) return;
    // Invalidate callbacks before closing; close may itself emit disconnected.
    final next = ++_generation;
    _release();
    if (retryCount >= maxRetries) {
      error =
          'Connection failed. Check address, transport, credentials and broker. Retry limit reached.';
      _setPhase(SessionPhase.failed);
      return;
    }
    final delay = retryDelay * (1 << retryCount);
    retryCount++;
    error = 'Connection interrupted. Retry $retryCount of $maxRetries.';
    _setPhase(SessionPhase.reconnecting);
    _retry = Timer(delay, () => unawaited(_open(next)));
  }

  Future<void> subscribe(String filter, int qos) async {
    validateTopic(filter, filter: true);
    validateQos(qos);
    final client = _connected();
    if (_topics.containsKey(filter)) {
      throw StateError('Already subscribed. Unsubscribe before changing QoS.');
    }
    final generation = _generation;
    try {
      await client.subscribe(filter, qos);
    } catch (_) {
      throw StateError('Broker did not acknowledge the subscription.');
    }
    _ensureCurrent(generation);
    _topics[filter] = qos;
    notifyListeners();
  }

  Future<void> unsubscribe(String filter) async {
    final client = _connected();
    final generation = _generation;
    try {
      await client.unsubscribe(filter);
    } catch (_) {
      throw StateError('Broker did not acknowledge unsubscribe.');
    }
    _ensureCurrent(generation);
    _topics.remove(filter);
    notifyListeners();
  }

  void _ensureCurrent(int generation) {
    if (generation != _generation || _phase != SessionPhase.connected) {
      throw StateError('Connection changed; try again after reconnecting.');
    }
  }

  void publish(String topic, String payload, int qos, {bool retain = false}) {
    validateTopic(topic);
    validatePayload(payload);
    validateQos(qos);
    try {
      _connected().publish(topic, payload, qos, retain: retain);
    } catch (_) {
      throw StateError('Message could not be queued. Check connection.');
    }
    _record(
      LabMessage(
        topic: topic,
        payload: payload,
        qos: qos,
        retained: retain,
        delivery: Delivery.queued,
      ),
    );
  }

  MqttTransport _connected() {
    if (_phase != SessionPhase.connected || _client == null) {
      throw StateError('Connect to a broker first.');
    }
    return _client!;
  }

  void _record(LabMessage message) {
    if (_disposed) return;
    _history.insert(0, message);
    if (_history.length > historyLimit) _history.removeLast();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  void disconnect() {
    ++_generation;
    _retry?.cancel();
    _release();
    error = null;
    _setPhase(SessionPhase.disconnected);
  }

  void _release() {
    unawaited(_messages?.cancel());
    unawaited(_lost?.cancel());
    _messages = null;
    _lost = null;
    final old = _client;
    _client = null;
    old?.close();
  }

  void _setPhase(SessionPhase value) {
    _phase = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }
}
