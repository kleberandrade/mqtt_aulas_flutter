import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/models.dart';

void main() {
  test(
    'connection validates endpoints, ports, identities and web transport',
    () {
      expect(
        () => ConnectionConfig(host: 'https://host', port: 1883).validate(),
        throwsFormatException,
      );
      expect(
        () => ConnectionConfig(host: 'localhost', port: 0).validate(),
        throwsFormatException,
      );
      expect(
        () => ConnectionConfig(host: 'localhost', port: 65536).validate(),
        throwsFormatException,
      );
      expect(
        () =>
            ConnectionConfig(host: 'localhost', port: 1883).validate(web: true),
        throwsFormatException,
      );
      expect(
        () => ConnectionConfig(
          host: 'localhost',
          port: 1883,
          clientId: '',
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => ConnectionConfig(host: '999.0.0.1', port: 1883).validate(),
        throwsFormatException,
      );
      expect(
        () => ConnectionConfig(
          host: 'localhost',
          port: 1883,
          password: 'secret',
        ).validate(),
        throwsFormatException,
      );
      ConnectionConfig(host: '::1', port: 1883).validate();
      ConnectionConfig(
        host: '127.0.0.1',
        port: 9001,
        transport: Transport.webSocket,
      ).validate(web: true);
    },
  );
  test(
    'filters allow whole-level wildcards only; publish topics forbid them',
    () {
      for (final filter in ['lab/+', 'lab/#', '#', '+/temperature', '/lab/']) {
        validateTopic(filter, filter: true);
      }
      for (final filter in ['', 'lab/#/x', 'lab/a+', 'lab/#x', 'lab/\u0000']) {
        expect(
          () => validateTopic(filter, filter: true),
          throwsFormatException,
        );
      }
      expect(() => validateTopic('lab/+'), throwsFormatException);
      expect(() => validateTopic('a' * 65536), throwsFormatException);
      expect(
        () => validateTopic(String.fromCharCode(0xd800)),
        throwsFormatException,
      );
      validateTopic('lab/温度');
    },
  );
  test(
    'payload supports empty and binary-control text but bounds encoded bytes',
    () {
      validatePayload('');
      validatePayload('\u0000');
      validatePayload('a' * 65536);
      expect(() => validatePayload('é' * 32769), throwsFormatException);
      expect(
        () => validatePayload(String.fromCharCode(0xd800)),
        throwsFormatException,
      );
    },
  );
}
