import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/models.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/session.dart';
import 'support/fake_transport.dart';

void main() {
  test('initial failure consumes 1s, 2s, 4s retry budget then stops', () {
    fakeAsync((clock) {
      var attempts = 0;
      final session = MqttSession(() {
        attempts++;
        return FakeTransport()..fail = true;
      });
      session.connect(ConnectionConfig(host: 'localhost', port: 1883));
      clock.flushMicrotasks();
      expect(attempts, 1);
      expect(session.phase, SessionPhase.reconnecting);
      clock.elapse(const Duration(milliseconds: 999));
      expect(attempts, 1);
      clock.elapse(const Duration(milliseconds: 1));
      expect(attempts, 2);
      clock.elapse(const Duration(seconds: 2));
      expect(attempts, 3);
      clock.elapse(const Duration(seconds: 4));
      expect(attempts, 4);
      expect(session.phase, SessionPhase.failed);
      clock.elapse(const Duration(hours: 1));
      expect(attempts, 4);
      session.dispose();
    });
  });
  test('manual disconnect cancels scheduled retry', () {
    fakeAsync((clock) {
      var attempts = 0;
      final session = MqttSession(() {
        attempts++;
        return FakeTransport()..fail = true;
      });
      session.connect(ConnectionConfig(host: 'localhost', port: 1883));
      clock.flushMicrotasks();
      session.disconnect();
      clock.elapse(const Duration(minutes: 1));
      expect(attempts, 1);
      expect(session.phase, SessionPhase.disconnected);
      session.dispose();
    });
  });
}
