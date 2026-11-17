import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'models.dart';

MqttClient createClient(ConnectionConfig config) {
  final ws = config.transport == Transport.webSocket;
  final url = Uri(
    scheme: config.tls ? 'wss' : 'ws',
    host: config.host,
    path: config.path,
  ).toString();
  return MqttServerClient.withPort(
      ws ? url : config.host,
      config.clientId,
      config.port,
      maxConnectionAttempts: 1,
    )
    ..useWebSocket = ws
    ..secure = !ws && config.tls;
}
