import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/client_transport.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/models.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/session.dart';

void main() {
  test(
    'broker restart reconnects session and restores acknowledged subscriptions',
    () async {
      final session = MqttSession(ClientTransport.new);
      addTearDown(session.dispose);
      await session.connect(ConnectionConfig(host: '127.0.0.1', port: 1883));
      expect(session.phase, SessionPhase.connected);
      await session.subscribe('lab/reconnect', 1);
      final restart = await Process.run('docker', [
        'compose',
        'restart',
        'broker',
      ]);
      expect(
        restart.exitCode,
        0,
        reason: 'Cannot restart project-local broker.',
      );
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while ((session.phase != SessionPhase.connected ||
              session.retryCount == 0) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(session.phase, SessionPhase.connected);
      expect(session.retryCount, greaterThan(0));
      session.publish('lab/reconnect', 'restored', 1);
      while (!session.history.any((m) => m.delivery == Delivery.received) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        session.history
            .where((m) => m.delivery == Delivery.received)
            .single
            .payload,
        'restored',
      );
    },
    skip: !const bool.fromEnvironment('LOCAL_BROKER'),
    timeout: const Timeout(Duration(seconds: 40)),
  );
}
