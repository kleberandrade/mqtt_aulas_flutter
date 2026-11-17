import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_aulas_flutter/src/mqtt/session.dart';
import 'package:mqtt_aulas_flutter/src/ui/lab_app.dart';
import 'support/fake_transport.dart';

void main() {
  testWidgets('connect, subscribe, generate sample, publish and disconnect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = FakeTransport();
    final session = MqttSession(() => fake);
    addTearDown(session.dispose);
    await tester.pumpWidget(LabApp(session: session));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Status: connected'), findsOneWidget);
    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();
    expect(find.text('Requested QoS 1'), findsOneWidget);
    await tester.ensureVisible(find.text('Generate simulated telemetry'));
    await tester.tap(find.text('Generate simulated telemetry'));
    await tester.pump();
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    expect(fake.published.single.payload, contains('"simulated":true'));
    expect(session.history.single.payload, contains('"sample":1'));
    await tester.ensureVisible(find.text('Disconnect'));
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Status: disconnected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('small screen stays usable and shows validation errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = MqttSession(FakeTransport.new);
    addTearDown(session.dispose);
    await tester.pumpWidget(LabApp(session: session));
    await tester.enterText(
      find.widgetWithText(TextField, 'Host'),
      'https://invalid/',
    );
    await tester.ensureVisible(find.text('Connect'));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
