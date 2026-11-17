import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../mqtt/models.dart';
import '../mqtt/session.dart';

class LabApp extends StatelessWidget {
  const LabApp({super.key, required this.session, this.ownsSession = false});
  final MqttSession session;
  final bool ownsSession;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MQTT Lab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff006b61)),
      scaffoldBackgroundColor: const Color(0xfff3f6f5),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    ),
    home: LabScreen(session: session, ownsSession: ownsSession),
  );
}

class LabScreen extends StatefulWidget {
  const LabScreen({
    super.key,
    required this.session,
    required this.ownsSession,
  });
  final MqttSession session;
  final bool ownsSession;
  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  final _host = TextEditingController(text: kIsWeb ? '127.0.0.1' : '10.0.2.2');
  final _port = TextEditingController(text: kIsWeb ? '9001' : '1883');
  final _path = TextEditingController(text: '/mqtt');
  final _id = TextEditingController(
    text: 'lab-${DateTime.now().microsecondsSinceEpoch}',
  );
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _filter = TextEditingController(text: 'lab/telemetry/#');
  final _topic = TextEditingController(text: 'lab/telemetry/temperature');
  final _payload = TextEditingController(
    text: '{"simulated":true,"temperatureC":23.5}',
  );
  Transport _transport = kIsWeb ? Transport.webSocket : Transport.tcp;
  bool _tls = false, _retain = false, _working = false;
  int _qos = 1, _sample = 0;
  String? _feedback;
  MqttSession get session => widget.session;
  bool get connected => session.phase == SessionPhase.connected;
  bool get idle =>
      session.phase == SessionPhase.disconnected ||
      session.phase == SessionPhase.failed;

  @override
  void dispose() {
    for (final controller in [
      _host,
      _port,
      _path,
      _id,
      _username,
      _password,
      _filter,
      _topic,
      _payload,
    ]) {
      controller.dispose();
    }
    if (widget.ownsSession) session.dispose();
    super.dispose();
  }

  Future<void> _action(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _feedback = null;
    });
    try {
      await action();
    } on FormatException catch (e) {
      if (mounted) setState(() => _feedback = e.message);
    } on StateError catch (e) {
      if (mounted) setState(() => _feedback = e.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _feedback = 'Operation failed. Check your connection and broker.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _connect() => _action(() async {
    final port = int.tryParse(_port.text);
    if (port == null) {
      throw const FormatException('Port must be a number from 1 to 65535.');
    }
    await session.connect(
      ConnectionConfig(
        host: _host.text.trim(),
        port: port,
        transport: _transport,
        tls: _tls,
        clientId: _id.text.trim(),
        path: _path.text,
        username: _username.text,
        password: _password.text,
      ),
    );
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      final color = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(
          title: const Text('MQTT Lab'),
          actions: [
            IconButton(
              tooltip: 'Open source licenses',
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'MQTT Lab',
                applicationVersion: '1.0.0',
              ),
              icon: const Icon(Icons.info_outline),
            ),
            if (MediaQuery.sizeOf(context).width >= 600)
              const Padding(
                padding: EdgeInsets.only(right: 20),
                child: Center(child: Text('LEARN · CONNECT · EXPLORE')),
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your local IoT workbench',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Connect to your own broker. Subscribe to a topic, publish a sample, and watch it arrive.',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(connected ? Icons.wifi : Icons.wifi_off),
                          Text(
                            'Status: ${session.phase.name}',
                            key: const Key('connection-status'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Automatic retries: ${session.retryCount}/${session.maxRetries}',
                          ),
                          if (!idle)
                            OutlinedButton(
                              onPressed: () {
                                session.disconnect();
                              },
                              child: const Text('Disconnect'),
                            ),
                        ],
                      ),
                    ),
                    if (_feedback ?? session.error case final String message)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            key: const Key('error'),
                            style: TextStyle(color: color.error),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final connection = _connectionCard();
                        final messaging = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _subscriptionCard(),
                            const SizedBox(height: 16),
                            _publishCard(),
                          ],
                        );
                        if (constraints.maxWidth < 800) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              connection,
                              const SizedBox(height: 16),
                              messaging,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 370, child: connection),
                            const SizedBox(width: 16),
                            Expanded(child: messaging),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _historyCard(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'MQTT 3.1.1 · Text payloads up to 64 KiB · Session data stays in memory',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _card(String title, String subtitle, List<Widget> children) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    ),
  );
  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    bool secret = false,
    TextInputType? type,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: enabled,
      obscureText: secret,
      enableSuggestions: !secret,
      autocorrect: false,
      keyboardType: type,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _connectionCard() => _card(
    '1. Broker connection',
    kIsWeb
        ? 'Web uses ws:// or wss:// only.'
        : 'Android emulator: 10.0.2.2 reaches your computer.',
    [
      DropdownButtonFormField<Transport>(
        initialValue: _transport,
        decoration: const InputDecoration(labelText: 'Transport'),
        items: Transport.values
            .where((t) => !kIsWeb || t == Transport.webSocket)
            .map(
              (t) => DropdownMenuItem(
                value: t,
                child: Text(t == Transport.tcp ? 'TCP' : 'WebSocket'),
              ),
            )
            .toList(),
        onChanged: idle && !_working
            ? (value) => setState(() {
                _transport = value!;
                _port.text = value == Transport.tcp ? '1883' : '9001';
              })
            : null,
      ),
      const SizedBox(height: 12),
      _field(_host, 'Host', enabled: idle && !_working),
      _field(
        _port,
        'Port',
        enabled: idle && !_working,
        type: TextInputType.number,
      ),
      if (_transport == Transport.webSocket)
        _field(_path, 'WebSocket path', enabled: idle && !_working),
      _field(_id, 'Client ID', enabled: idle && !_working),
      _field(_username, 'Username (optional)', enabled: idle && !_working),
      _field(
        _password,
        'Password (optional)',
        enabled: idle && !_working,
        secret: true,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('TLS encryption'),
        subtitle: const Text(
          'Requires a trusted broker certificate and matching secure port.',
        ),
        value: _tls,
        onChanged: idle && !_working ? (v) => setState(() => _tls = v) : null,
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: idle && !_working ? _connect : null,
        icon: const Icon(Icons.power_settings_new),
        label: Text(
          session.phase == SessionPhase.failed ? 'Reconnect' : 'Connect',
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'No public broker is configured. Credentials are never saved or logged.',
      ),
    ],
  );
  Widget _qosSelector() => DropdownButtonFormField<int>(
    isExpanded: true,
    initialValue: _qos,
    decoration: const InputDecoration(labelText: 'QoS (subscribe & publish)'),
    items: const [
      DropdownMenuItem(value: 0, child: Text('0 · At most once')),
      DropdownMenuItem(value: 1, child: Text('1 · At least once')),
      DropdownMenuItem(
        value: 2,
        child: Text('2 · Exactly once', overflow: TextOverflow.ellipsis),
      ),
    ],
    onChanged: _working ? null : (v) => setState(() => _qos = v!),
  );
  Widget _subscriptionCard() => _card(
    '2. Subscriptions',
    '+ matches one level; # matches remaining levels. QoS shown is requested.',
    [
      _field(_filter, 'Topic filter'),
      _qosSelector(),
      const SizedBox(height: 12),
      FilledButton.tonal(
        onPressed: connected && !_working
            ? () => _action(() => session.subscribe(_filter.text, _qos))
            : null,
        child: const Text('Subscribe'),
      ),
      for (final topic in session.subscriptions.entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(topic.key),
          subtitle: Text('Requested QoS ${topic.value}'),
          trailing: IconButton(
            tooltip: 'Unsubscribe ${topic.key}',
            icon: const Icon(Icons.close),
            onPressed: connected && !_working
                ? () => _action(() => session.unsubscribe(topic.key))
                : null,
          ),
        ),
    ],
  );
  Widget _publishCard() => _card(
    '3. Publish a message',
    'Outgoing entries mean queued locally. Incoming entries confirm broker roundtrip.',
    [
      _field(_topic, 'Publish topic'),
      _field(_payload, 'UTF-8 payload', lines: 3),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Retain message'),
        subtitle: const Text(
          'An empty retained payload clears the broker’s retained value.',
        ),
        value: _retain,
        onChanged: (v) => setState(() => _retain = v!),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: connected && !_working
                ? () => _action(() async {
                    session.publish(
                      _topic.text,
                      _payload.text,
                      _qos,
                      retain: _retain,
                    );
                  })
                : null,
            icon: const Icon(Icons.send),
            label: const Text('Publish'),
          ),
          OutlinedButton(
            onPressed: () => setState(() {
              _sample++;
              _payload.text = jsonEncode({
                'simulated': true,
                'sample': _sample,
                'temperatureC': 20 + (_sample % 10) * 0.5,
              });
            }),
            child: const Text('Generate simulated telemetry'),
          ),
        ],
      ),
    ],
  );
  Widget _historyCard() => _card(
    '4. Message history',
    'Latest ${session.historyLimit} entries, newest first. Binary input is shown as a UTF-8 preview.',
    [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: session.clearHistory,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear history'),
        ),
      ),
      if (session.history.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No messages yet. Subscribe to lab/telemetry/#, then publish a simulated sample.',
          ),
        ),
      for (final message in session.history)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${message.delivery == Delivery.received ? '↓ RECEIVED' : '↑ QUEUED'} · QoS ${message.qos}'
                '${message.retained ? ' · retained' : ''} · ${message.time.toLocal().toIso8601String()}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              SelectableText(
                message.topic,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                message.payload.isEmpty ? '(empty payload)' : message.payload,
                maxLines: 8,
              ),
              const Divider(),
            ],
          ),
        ),
    ],
  );
}
