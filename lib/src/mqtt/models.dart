import 'dart:convert';

enum Transport { tcp, webSocket }

enum SessionPhase { disconnected, connecting, connected, reconnecting, failed }

enum Delivery { received, queued }

class ConnectionConfig {
  ConnectionConfig({
    required this.host,
    required this.port,
    this.transport = Transport.tcp,
    this.tls = false,
    String? clientId,
    this.username = '',
    this.password = '',
    this.path = '/mqtt',
  }) : clientId = clientId ?? 'lab-${DateTime.now().microsecondsSinceEpoch}';
  final String host, clientId, username, password, path;
  final int port;
  final Transport transport;
  final bool tls;

  void validate({bool web = false}) {
    final isIpv6 =
        host.contains(':') &&
        Uri.tryParse('http://[$host]')?.host.isNotEmpty == true;
    final isName =
        host.isNotEmpty &&
        host.length <= 253 &&
        host
            .split('.')
            .every(
              (label) => RegExp(
                r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
              ).hasMatch(label),
            );
    if (!isIpv6 && !isName) {
      throw const FormatException(
        'Enter a hostname or IP address without a scheme or path.',
      );
    }
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host) &&
        host.split('.').any((part) => int.parse(part) > 255)) {
      throw const FormatException('IPv4 octets must be 0–255.');
    }
    if (password.isNotEmpty && username.isEmpty) {
      throw const FormatException(
        'MQTT 3.1.1 requires a username when providing a password.',
      );
    }
    _unicode(password);
    if (port < 1 || port > 65535) {
      throw const FormatException('Port must be 1–65535.');
    }
    if (web && transport != Transport.webSocket) {
      throw const FormatException('Browsers require WebSocket transport.');
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(clientId)) {
      throw const FormatException(
        'Client ID must contain 1–64 letters, digits, _ or -.',
      );
    }
    _mqttString(username);
    if (utf8.encode(password).length > 65535) {
      throw const FormatException('Password exceeds 65535 bytes.');
    }
    if (!path.startsWith('/') ||
        path.contains('?') ||
        path.contains('#') ||
        path.contains(RegExp(r'\s'))) {
      throw const FormatException(
        'WebSocket path must start with / and have no query or fragment.',
      );
    }
  }
}

void _unicode(String text) {
  if (text.runes.any((r) => r >= 0xd800 && r <= 0xdfff)) {
    throw const FormatException('Text contains an unpaired Unicode surrogate.');
  }
}

void _mqttString(String text) {
  _unicode(text);
  if (text.contains('\u0000') || utf8.encode(text).length > 65535) {
    throw const FormatException(
      'MQTT strings cannot contain NUL or exceed 65535 UTF-8 bytes.',
    );
  }
}

void validateTopic(String topic, {bool filter = false}) {
  _mqttString(topic);
  if (topic.isEmpty) throw const FormatException('Topic cannot be empty.');
  final levels = topic.split('/');
  for (var i = 0; i < levels.length; i++) {
    final level = levels[i];
    if (level.contains('#') &&
        !(filter && level == '#' && i == levels.length - 1)) {
      throw const FormatException(
        '# must be the final whole level of a subscription filter.',
      );
    }
    if (level.contains('+') && !(filter && level == '+')) {
      throw const FormatException(
        '+ must be a whole level of a subscription filter.',
      );
    }
  }
}

void validatePayload(String payload) {
  _unicode(payload);
  if (utf8.encode(payload).length > 65536) {
    throw const FormatException(
      'This lab limits payloads to 64 KiB of UTF-8 text.',
    );
  }
}

void validateQos(int qos) {
  if (qos < 0 || qos > 2) throw const FormatException('QoS must be 0, 1 or 2.');
}

class LabMessage {
  LabMessage({
    required this.topic,
    required this.payload,
    required this.qos,
    this.retained = false,
    this.delivery = Delivery.received,
    DateTime? time,
  }) : time = time ?? DateTime.now();
  final String topic, payload;
  final int qos;
  final bool retained;
  final Delivery delivery;
  final DateTime time;
}
