# Apple Watch Companion

## Purpose and Scope

The companion brings Daily 3's existing three-priority rule to the wrist.
It shows today's priorities and a completion count. Tapping a filled
priority toggles its completion state. Empty slots are disabled.

Planning and editing titles remain on iPhone. Calendar, statistics,
notification settings, complications, and independent Watch planning are
outside this phase. Keeping the Watch experience small makes it useful for
quick checks without duplicating the entire phone application.

Status: implemented, with paired-device verification still pending.

## Why WatchConnectivity?

An App Group shares files between an app and its extensions on the same
device. It does not synchronize an iPhone database with an Apple Watch.
The Watch therefore receives small Codable messages through
WatchConnectivity instead of opening the phone's SwiftData store.

iPhone remains the source of truth. The Watch keeps a local copy of the
latest snapshot and any completion changes awaiting confirmation. This
avoids introducing a second database and a general-purpose merge system.
Apple documents the delivery options in
[Transferring data with Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity).

The existing `TodayWidgetSnapshot` and `WidgetPriority` value types are
reused. Despite their widget-oriented names, they contain only a day and
three priorities; they do not depend on WidgetKit or SwiftData.

## Project Structure

| File or directory | Responsibility |
| --- | --- |
| `Daily3Watch/Daily3WatchApp.swift` | Watch application entry point, navigation, refresh action, and scene lifecycle |
| `Daily3Watch/WatchSessionStore.swift` | Observable Watch state, WCSession delegate, persistence, and delivery |
| `WatchShared/WatchTodayView.swift` | Three-priority interface and synchronization status |
| `WatchShared/WatchSyncMessage.swift` | Codable protocol and locally pending changes |
| `Daily3/PhoneWatchSync.swift` | iPhone WCSession lifecycle and transport |
| `Daily3/WatchCommandProcessor.swift` | Validation, SwiftData updates, receipts, and ordering |
| `Daily3Tests/WatchSyncTests.swift` | Deterministic state and command-processing tests |
| `Daily3Tests/WatchRenderingTests.swift` | Shared content layout checks at a narrow width |
| `Configuration/Daily3Watch-Info.plist` | Association with the companion iPhone app |

The modern single-target Watch application is embedded in the iPhone app.
It has bundle identifier `com.anayaydin.Daily3.watchkitapp` and is associated
with `com.anayaydin.Daily3`. It does not advertise independent operation.
See Apple's [watchOS project setup](https://developer.apple.com/documentation/watchos-apps/setting-up-a-watchos-project).

## How Synchronization Works

### 1. Send the Current Day from iPhone

The iPhone session starts when `Daily3App` creates the SwiftData container,
not only when Today appears. This lets incoming Watch messages reach the
same save and validation logic when the system launches the phone app.

The phone publishes after daily data changes, when the app becomes active
or enters the background, and when the Watch session activates or changes.
Editing is debounced alongside widget publishing.

`updateApplicationContext` sends the latest complete state. Older pending
contexts can be replaced because the Watch needs the latest snapshot, not
every intermediate edit. If the Watch is reachable, `sendMessageData`
also delivers the update immediately.

Each state includes a phone identity, an increasing revision, and recent
command receipts. The Watch ignores an older revision from the same phone.
See [WCSession](https://developer.apple.com/documentation/watchconnectivity/wcsession).

### 2. Toggle a Priority on Watch

The Watch records the desired completion value before attempting delivery.
It immediately overlays that pending value on the visible snapshot. This
is an **optimistic update**: the screen responds immediately, but the change
remains pending until the phone acknowledges it.

The cached state and pending changes are encoded with JSONEncoder and
stored in UserDefaults. Only the latest pending change per slot is kept
locally. A change includes:

- A unique command ID for acknowledgment
- The phone identity it belongs to
- A Watch source identity and increasing sequence number
- The original day, slot, and expected priority title
- The desired completion value, rather than a blind toggle instruction

Sending a desired value makes retries safe: receiving "completed = true"
twice does not flip a task back to incomplete.

### 3. Deliver Immediately or Queue

When reachable, the Watch sends a message with a reply handler. Otherwise,
or if immediate delivery fails, it queues `transferUserInfo` on real
devices. Pending changes are retried when the session or app becomes active.
Delivery timing is controlled by the system; offline changes are not
promised to appear on the phone immediately.

The phone validates every command before changing SwiftData:

- It must belong to this phone and the phone's current local day.
- The slot must be 1, 2, or 3, with a positive sequence number.
- It must be newer than the last processed command for that Watch and slot.
- The priority must still exist, be filled, and have the expected title.

The last sequence numbers are persisted so relaunching the phone does not
allow an older queued command to undo a newer one. This is intentionally a
small completion protocol, not a general conflict-resolution service.
A valid Watch command applies to the current matching priority when it
arrives; the iPhone snapshot then becomes authoritative again.

After saving, the phone refreshes its shared widget snapshot and sends the
updated Watch state. Acknowledged commands leave the Watch's pending list.
Rejected commands are removed and the authoritative phone state is shown.

### 4. Handle Day Changes and Failures

The Watch's cached snapshot is shown only for the matching local day. A
periodic TimelineView reevaluates the visible day while the screen is active.
Yesterday's tasks do not become today's editable tasks.

Pending changes cannot edit history: a command arriving on another day is
rejected. A new snapshot also discards pending changes for a different day,
phone, or priority title. A changed-priority rejection asks the user to
review the current phone priorities and try again.

The first launch and a stale-day cache show empty slots with an iPhone
prompt. Waiting changes show a pending status. Failed saves show an error
instead of claiming success.

The phone's existing SwiftData location and schema are unchanged. The
Widget App Group is still used only by the phone and widget; the Watch
does not access that shared file container.

## Running in Xcode

This project currently targets iOS 26.5 and watchOS 26.5.

1. Install the matching watchOS platform/runtime in Xcode Settings under
   Components if Xcode reports it missing.
2. Create an Apple Watch simulator paired with an appropriate iPhone
   simulator using Xcode's Devices and Simulators window.
3. Run the `Daily3` scheme on the paired iPhone and enter today's priorities.
4. Select the shared `Daily3Watch` scheme and the paired Watch destination.
5. Launch both apps and use the Watch refresh action if necessary.
6. Toggle a filled priority and compare the phone's Today screen.

The Watch target uses the same development team as the phone. For physical
devices, automatic signing must provision both bundle identifiers.

**Important:** a Watch SDK can be present even when the simulator runtime
is missing. Xcode may require that runtime for the iPhone scheme's tests
too, because that scheme builds an embedded Watch application.

## Testing and Remaining Verification

Automated tests cover accepted completion updates, persistence of command
ordering across processor recreation, duplicate and out-of-order delivery,
missing or changed priorities, invalid slots, another phone identity,
past/future days, Codable round trips, local pending-state persistence,
optimistic progress, older snapshot revisions, and next-day blank states.

Shared SwiftUI content is rendered at a narrow width with empty, filled,
and large-text cases. These are iOS-hosted layout checks, not screenshots
of the watchOS navigation or proof of Watch interaction behavior.

During implementation, the Watch sources were compiled with both the
watchOS device and simulator SDKs. The complete iPhone application also
built successfully with its widget and embedded Watch application using
the device SDKs, without code signing. Installation and signing are not
verified by that build.

The machine had no watchOS simulator runtime. To exercise
the actual iPhone sources and unit tests without changing the repository's
Watch embedding, a temporary ignored project copy omitted only the Watch
target dependency and embedding phase. This does not verify the full
embedded application, signing, or paired transport.

Verification results: all 40 unit/content-rendering tests passed in that
iOS harness. Three selected iPhone UI regressions also passed: Today shows
three priorities, Statistics updates after completion, and the widget deep
link returns to Today. The Watch-specific command/state tests account for
12 of the unit tests. These results do not replace paired-device checks.

`transferUserInfo` is not supported by Simulator. Simulator live messaging
can help with UI and reachable-session checks, but offline queue delivery
must be tested with real paired devices. The Watch simulator keeps local
pending changes for a later live retry instead of using that API.
See Apple's [transferUserInfo documentation](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)).

Before marking this phase complete:

- [ ] Inspect Watch layout, scrolling, and tap targets on an actual watchOS destination.
- [ ] Check long titles, larger text sizes, empty slots, and all three completed.
- [ ] Edit a title and toggle completion on iPhone; verify the Watch updates.
- [ ] Toggle on Watch; verify iPhone, statistics, and the widget reflect the saved state.
- [ ] Relaunch both apps and confirm state is retained.
- [ ] Disconnect real devices, change completion repeatedly, reconnect, and confirm the latest value wins.
- [ ] Queue a change, edit its title on iPhone, and verify the stale change is rejected.
- [ ] Cross local midnight and verify no old command alters history or today's new priorities.
- [ ] Confirm waiting, pending, and failure states never claim an unsaved change succeeded.

## Topics to Study

- **Swift value types:** structs, enums with associated values, Equatable
- **Serialization:** Codable, JSONEncoder, JSONDecoder, Data
- **Persistence:** UserDefaults for small caches and SwiftData for the canonical model
- **SwiftUI state:** Observation, @Observable, @State, scenePhase, TimelineView
- **Concurrency:** MainActor, nonisolated delegate entry points, Task
- **WatchConnectivity:** activation, reachability, application context, messages, queued transfers
- **Synchronization:** optimistic UI, acknowledgments, idempotency, monotonic sequence numbers
- **Testing:** Swift Testing, in-memory ModelContainer, isolated UserDefaults, XCTest image attachments
