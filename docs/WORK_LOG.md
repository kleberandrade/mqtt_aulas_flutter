# Implementation log

- Inspected the original repository: README, MIT license and ignore rules only; clean working tree. Preserved original copyright.
- Read requested ub-mode guidance. Scope: Android and browser, MQTT 3.1.1, local broker, no public broker defaults and no push.
- Flutter 3.41.9 / Dart 3.11.5 available. Android doctor reports unaccepted SDK licenses; no physical device connected.
- Created Android/Web shells and pinned MQTT dependency plus application lockfile.
- TDD: validation tests failed because the domain API did not exist, then passed (3 tests) after implementing endpoint, topic/filter and UTF-8 payload validation.
- crapper, dryer and mutator are installed; their help lists no Dart support. No Dart complexity or mutation score is claimed. Use analyzer, behavioral tests and manual review instead.
- TDD: session tests initially failed on missing controller. Implemented injected transports, acknowledged subscriptions, bounded history, cancellation generations and a total retry budget per manual connection. Corrected the test expectation to match the documented total budget (successful reconnects do not replenish it).
- Local Mosquitto 2.0.22: TCP and native WebSocket roundtrips passed for QoS 0/1/2, empty retained payloads and unsubscribe ACKs.
- Widget tests caught small-screen dropdown and toolbar overflow; corrected both and reran successfully.
- Web release and Android debug builds succeeded. Android SDK doctor warning did not block compilation; no SDK licenses were accepted during this work.
- Added regression tests for retry timing (virtual clock), canceled retry timers, IPv4 octets and password-without-username. Observed input regression failure before fixing validation.
- Updated GitHub About through the signed-in repository UI. Existing topics were empty. Saved and visibly verified: android, dart, education, flutter, iot, mosquitto, mqtt, websocket. No code pushed.
- Real broker-restart test passed: TCP session reconnects, restores subscription, receives a new publication. Chrome WebSocket test passed for QoS 0/1/2 and unsubscribe.
- Simulated CLI publisher confirmed all five loopback samples. No sensor or third-party broker involved.
- Analyzer passed with fatal infos; final ordinary suite passed 11 tests (3 local integration cases skipped by design). Native local integrations passed all 3 serially; Chrome integration passed 1.
- Executed crapper/dryer/mutator against lib: all reported no source files to analyze/mutate, consistent with missing Dart support. No complexity, duplication or mutation pass is inferred from these no-op scans.
- CI uses verified action commit IDs, Flutter 3.41.9, committed pubspec.lock and a pinned Mosquitto image digest. Remote CI has not run because commits remain local.
