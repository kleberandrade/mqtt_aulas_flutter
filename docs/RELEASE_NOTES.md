MQTT Lab {tag} provides an Android debug test build of the local-first Flutter MQTT learning app.

## Build details

- App version: **{version} (build {build})**.
- Source commit: [`{sha}`](https://github.com/{repository}/commit/{sha}).
- [Build and validation run](https://github.com/{repository}/actions/runs/{run_id}).
- [Source history for this version](https://github.com/{repository}/commits/{tag}).

## Android test APK

Download **{apk}** and **{apk}.sha256** from the release assets. This is a **debug-signed APK for testing**, not a production-signed or app-store release. Hosted runners may generate different debug keys between builds; installing over a previous test build may require uninstalling that build first (which clears its app data).

```sh
sha256sum -c {apk}.sha256
adb install -r {apk}
```

On macOS, use `shasum -a 256 -c {apk}.sha256` for checksum verification.

## Local broker exercise

Run `docker compose up -d --wait` in the source checkout. In an Android emulator, connect to `10.0.2.2:1883` using TCP with TLS off and no credentials. Subscribe to `lab/telemetry/#`, generate explicitly simulated telemetry, and publish to `lab/telemetry/temperature`.

For a physical Android device attached through USB, run `adb reverse tcp:1883 tcp:1883` and use `127.0.0.1` as the app host. Web requires WebSocket (`127.0.0.1:9001`, path `/mqtt`); browsers cannot use raw MQTT TCP. The included local broker has no TLS listener and is intended for local exercises only. Stop it with `docker compose down`.

## Validation and scope

The linked workflow runs formatting, static analysis, unit/widget tests, local Mosquitto TCP/WebSocket integration tests, broker-restart recovery, a Chrome WebSocket integration test, the simulated publisher, and Web/Android builds before preparing these assets. Publication occurs only after those checks succeed.

Physical-device, live TLS/WSS, mutual-TLS, production-signing, and app-store validation are not claimed. No public broker is configured, and no credentials are bundled.

See the [README](https://github.com/{repository}/blob/{tag}/README.md) and [troubleshooting guide](https://github.com/{repository}/blob/{tag}/docs/TROUBLESHOOTING.md). MIT license; original copyright © 2019 Kléber de Oliveira Andrade preserved. Dependencies retain their own licenses and notices.
