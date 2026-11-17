import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_aulas_flutter/src/mqtt/client_transport.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/models.dart';

/// Publishes five explicitly simulated samples to your loopback broker only.
Future<void> main() async {
  final client = ClientTransport();
  try {
    await client.connect(ConnectionConfig(host: '127.0.0.1', port: 1883));
    for (var sample = 1; sample <= 5; sample++) {
      final echo = client.messages.first.timeout(const Duration(seconds: 5));
      if (sample == 1) await client.subscribe('lab/telemetry/temperature', 1);
      client.publish(
        'lab/telemetry/temperature',
        jsonEncode({
          'simulated': true,
          'sample': sample,
          'temperatureC': 20 + sample * 0.5,
        }),
        1,
      );
      final received = await echo;
      stdout.writeln('Local broker roundtrip: ${received.payload}');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await client.unsubscribe('lab/telemetry/temperature');
  } finally {
    client.close();
  }
}
