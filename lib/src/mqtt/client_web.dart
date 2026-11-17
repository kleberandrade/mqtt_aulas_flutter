import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'models.dart';

MqttClient createClient(ConnectionConfig config) {
  config.validate(web: true);
  final url = Uri(
    scheme: config.tls ? 'wss' : 'ws',
    host: config.host,
    path: config.path,
  ).toString();
  return MqttBrowserClient.withPort(
    url,
    config.clientId,
    config.port,
    maxConnectionAttempts: 1,
  );
}
