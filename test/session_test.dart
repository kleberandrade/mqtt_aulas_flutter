import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/models.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/session.dart';
import 'support/fake_transport.dart';

ConnectionConfig config() => ConnectionConfig(host: 'localhost', port: 1883);
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 10));
void main() {
  test(
    'connect, subscribe, publish, receive, unsubscribe and disconnect',
    () async {
      final fake = FakeTransport();
      final session = MqttSession(() => fake, historyLimit: 2);
      addTearDown(session.dispose);
      await session.connect(config());
      expect(session.phase, SessionPhase.connected);
      await session.subscribe('lab/+', 1);
      expect(session.subscriptions, {'lab/+': 1});
      await expectLater(session.subscribe('lab/+', 2), throwsStateError);
      session.publish('lab/temp', '20', 2, retain: true);
      expect(fake.published.single.retained, isTrue);
      expect(session.history.single.delivery, Delivery.queued);
      for (var i = 0; i < 3; i++) {
        fake.incoming.add(LabMessage(topic: 'lab/temp', payload: '$i', qos: 1));
      }
      expect(session.history.length, 2);
      expect(session.history.first.payload, '2');
      await session.unsubscribe('lab/+');
      expect(session.subscriptions, isEmpty);
      session.disconnect();
      expect(fake.closed, isTrue);
      expect(session.phase, SessionPhase.disconnected);
      expect(() => session.publish('lab/temp', '', 0), throwsStateError);
    },
  );
  test(
    'reconnect restores desired topics, bounded retries stop without leaking errors',
    () async {
      final clients = <FakeTransport>[];
      final session = MqttSession(
        () {
          final client = FakeTransport()..fail = clients.length > 1;
          clients.add(client);
          return client;
        },
        retryDelay: Duration.zero,
        maxRetries: 2,
      );
      addTearDown(session.dispose);
      await session.connect(config());
      await session.subscribe('lab/#', 2);
      clients.first.lost.add(null);
      await tick();
      expect(session.phase, SessionPhase.connected);
      expect(clients[1].subscriptions, {'lab/#': 2});
      clients[1].lost.add(null);
      await tick();
      expect(session.phase, SessionPhase.failed);
      expect(clients.length, 3);
      expect(session.error, isNot(contains('secret')));
    },
  );
  test(
    'disconnect cancels retries and an in-flight connection cannot revive session',
    () async {
      final fake = FakeTransport()..connection = Completer<void>();
      final session = MqttSession(() => fake);
      addTearDown(session.dispose);
      final pending = session.connect(config());
      session.disconnect();
      fake.connection!.complete();
      await pending;
      expect(session.phase, SessionPhase.disconnected);
      expect(fake.closed, isTrue);
    },
  );
  test(
    'failed subscription is not advertised; invalid operations never reach adapter',
    () async {
      final fake = FakeTransport()..rejectSubscription = true;
      final session = MqttSession(() => fake);
      addTearDown(session.dispose);
      await session.connect(config());
      await expectLater(session.subscribe('lab/#', 1), throwsStateError);
      expect(session.subscriptions, isEmpty);
      await expectLater(session.subscribe('bad#', 1), throwsFormatException);
      expect(() => session.publish('lab/+', 'text', 0), throwsFormatException);
      expect(
        () => session.publish('lab/temp', 'text', 3),
        throwsFormatException,
      );
      expect(fake.published, isEmpty);
    },
  );
}
