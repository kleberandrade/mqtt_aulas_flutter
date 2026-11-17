# Implementation log

## Initial local delivery

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
- Visually exercised the compiled Web app in Chrome: Connect → Subscribe → Generate simulated telemetry → Publish. The visible session became connected and history reported QUEUED and RECEIVED. Saved screenshots of the app and GitHub metadata under docs/images.
- Added the pinned Cupertino icon font package after the Web compiler identified a missing adaptive-control font; no platform behavior was stubbed.
- Final verification after the adaptive font fix: enforced lockfile, formatting, fatal-info analysis and all 11 ordinary tests passed; 3 broker integrations remain opt-in in ordinary runs. Both Web release and Android debug builds passed without the missing-font warning.
- YAML syntax checks and git whitespace checks passed. This does not claim a GitHub Actions run or bit-for-bit artifact reproducibility.
- Closed the temporary HTTP server and removed only this project's Compose broker/network after verification. Retained build outputs locally; no unrelated worktrees or containers were removed.
- Limitations: no physical Android device, no live TLS/WSS broker or mutual TLS validation, no production signing/deployment, no remote CI run; crapper/dryer/mutator cannot inspect Dart. Unit/widget LCOV is available locally in coverage/lcov.info; no mutation score is claimed.

## Publication follow-up · 2026-11-17

- User explicitly authorized pushing the five implementation commits and monitoring GitHub Actions through success, including necessary fixes.
- Pushed master through b5b00fe; GitHub started CI run 44007926959 with verify and android jobs.
- Replaced the pre-publication CI badge/README wording with the actual master workflow badge. This documentation follow-up will trigger a fresh run, which is the run to monitor for the final delivered commit. CI results will be reported with a verified run link after completion; no deployment is authorized or configured.

## Tag-based release automation · 2026-11-17

- User requested future `v*` tags to build and publish the debug APK and SHA-256 checksum with English notes. Existing v1.0.0 must remain unchanged.
- Reused the complete CI workflow for release checks and the Android APK. Added a read-only packaging job and a separate contents-write publishing job; no new credentials or signing key are stored.
- Wrote failing preparation tests before implementation (missing module), then passed tests for exact artifact bytes, checksums, tag/version validation, prereleases and English metadata. Added publishing boundary tests for retryable draft failures, no publication before upload completion, checksum tampering and preservation of completed releases.
- Added a manual preparation-only workflow run to validate CI and packaging without creating a synthetic version tag or modifying the existing release. A real future tag is required to exercise live publication; CLI publication behavior is tested locally with a fake boundary.
- Documented semantic version/build-number updates, tag push commands, manual rehearsal, debug signing differences and artifact retention. Action revisions are pinned to verified official repository SHAs.
- Local checks passed: 19 release-tool tests, real-APK packaging with independently verified SHA-256, Python compilation and actionlint v1.7.12 for both workflow files. The official actionlint binary checksum was verified before use.
- Unlike the earlier Dart code, these Python helpers are supported by crapper/dryer/mutator: all measured functions had CRAP <= 6; dryer found no candidates at 0.8; mutation testing killed all 68 discovered sites after adding boundary regressions. GitHub CLI publication itself is tested through fake process/API boundaries, not by creating an extra public release.
