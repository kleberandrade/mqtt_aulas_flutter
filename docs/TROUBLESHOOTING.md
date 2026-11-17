# Troubleshooting

## Cannot connect

1. Check `docker compose ps` and `docker compose logs broker`.
2. Use WebSocket port 9001 for browsers, TCP port 1883 for Android TCP. Do not include `tcp://`, `ws://` or a path in Host; set the WebSocket path separately.
3. On an Android emulator use `10.0.2.2`; on the browser use `127.0.0.1`. For physical USB devices use the README's `adb reverse` instructions.
4. The local broker has no TLS listener or authentication. TLS on port 1883 or 9001 will fail. Remote brokers need matching trusted certificates and credentials.
5. If another process uses 1883/9001, stop only that process if safe, or change the Compose host ports and enter those ports in the app. Automated integration tests assume the original ports.
6. A second client using the same ID disconnects the first. Use separate IDs for separate app tabs.
7. Automatic retries have a total budget per manual connection. After exhaustion, press Reconnect. Disconnect cancels scheduled retries.

## Connected but no incoming message

Subscribe before publishing, check case-sensitive topic/filter spelling, and wait for the subscription row (broker acknowledgment). QUEUED is not proof of delivery. Match the default `lab/telemetry/#` filter with `lab/telemetry/temperature`. QoS cannot compensate for a nonmatching topic or a broker ACL denial. Rejected subscriptions produce an error rather than a confirmed row. If an acknowledgment times out, reconnect before retrying to avoid uncertain client/broker state.

Retain is opt-in. A new subscriber receives the broker's last retained value; an empty retained payload clears it. Non-retained messages published before a clean subscription are not replayed. Binary payloads are shown as a lossy text preview.

## Browser security and TLS

Use a broker WebSocket listener or reverse proxy supporting MQTT subprotocol `mqtt`. A native TCP listener cannot accept WebSocket handshakes. HTTPS pages generally block plain `ws` mixed content; use `wss` with a trusted certificate. Verify CSP, origin restrictions, DNS and proxy routing. Browser and native certificate trust stores can differ. Self-signed certificates are not automatically accepted; provision an appropriate trust chain outside the app. The app deliberately provides no insecure certificate bypass.

## Android build/setup

Run `flutter doctor -v`. Install the required SDK/JDK and complete Android license setup yourself if doctor reports missing acceptance. `flutter pub get`/Flutter tooling regenerates the ignored Gradle launchers. Debug builds do not require a private release key. Production signing is not configured.

## Diagnostics and privacy

Error messages are intentionally generic and do not expose raw library exceptions. MQTT debug logging is off, and credentials are not written to disk. Broker development logs may contain topic names and client IDs; do not publish sensitive payloads or copy private configuration into reports. Clear history to remove visible messages, then close the app to discard in-memory state.
