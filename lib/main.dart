import 'package:flutter/material.dart';
import 'src/mqtt/client_transport.dart';
import 'src/mqtt/session.dart';
import 'src/ui/lab_app.dart';

void main() => runApp(
  LabApp(session: MqttSession(ClientTransport.new), ownsSession: true),
);
