import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/client_transport.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/models.dart';

// Opt in explicitly; ordinary unit tests never contact a broker.
const brokerEnabled = bool.fromEnvironment('LOCAL_BROKER');
void main() {
  for (final transport in Transport.values.where(
    (t) => !kIsWeb || t == Transport.webSocket,
  )) {
    test(
      '${transport.name}: SUBACK, QoS 0/1/2 roundtrip, UNSUBACK and empty retained payload',
      () async {
        final client = ClientTransport();
        addTearDown(client.close);
        final topic = 'lab/test/${DateTime.now().microsecondsSinceEpoch}';
        await client.connect(
          ConnectionConfig(
            host: '127.0.0.1',
            port: transport == Transport.tcp ? 1883 : 9001,
            transport: transport,
          ),
        );
        final received = <LabMessage>[];
        final subscription = client.messages.listen(received.add);
        addTearDown(subscription.cancel);
        await client.subscribe(topic, 2);
        for (var qos = 0; qos <= 2; qos++) {
          final message = client.messages.first.timeout(
            const Duration(seconds: 5),
          );
          client.publish(topic, 'temperature: ${20 + qos} °C', qos);
          final result = await message;
          expect(result.payload, 'temperature: ${20 + qos} °C');
          expect(result.qos, qos);
        }
        final empty = client.messages.first.timeout(const Duration(seconds: 5));
        client.publish(topic, '', 1, retain: true);
        expect((await empty).payload, '');
        await client.unsubscribe(topic);
        final count = received.length;
        client.publish(topic, 'unsubscribed', 1);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(received.length, count);
      },
      skip: !brokerEnabled,
    );
  }
}
