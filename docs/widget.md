# Home Screen Widget

Daily 3 includes a read-only Home Screen widget in small and medium sizes.
Both show today's three priority slots, completion state and progress.
Tapping the widget opens the Today screen in Daily 3.

## Why a Separate Target?

A widget is an app extension, built separately from the main application.
The `Daily3Widget` target contains its WidgetKit entry point and timeline
provider. It is embedded inside the Daily 3 app, so installing the app also
installs the extension.

SwiftUI builds the widget's view. WidgetKit asks the timeline provider for
data, renders that view and manages its updates. A widget is not a smaller
copy of the running app and should not depend on an always-running timer.

## Sharing Data Without Moving SwiftData

SwiftData remains the source of truth for daily entries and tasks. Its
existing store stays in place, preserving saved history.

`Daily3Storage` explicitly uses `ModelConfiguration(groupContainer: .none)`.
SwiftData's default is `.automatic`, which can select an App Group once that
capability is added. Choosing `.none` keeps the original application-local
database instead of accidentally opening a different store.

After a change, the app saves a small Codable snapshot containing only
today's date and three priorities. The app and widget share this JSON file
through the App Group `group.com.anayaydin.Daily3`. Both targets have the
same App Groups entitlement.

This avoids moving the existing database or opening it from two processes
for a feature that only needs today's summary. The widget reads the
snapshot; it never edits tasks or creates daily entries.

Files in `Shared` are compiled into both targets. They define the snapshot,
the atomic file store and the SwiftUI content view. Keeping the content view
shared also lets app-hosted tests render the exact widget layout at fixed
small and medium sizes.

## Updates and Day Changes

`ContentView` observes task changes and publishes a snapshot after a short
400 ms pause. A newer edit cancels the pending publish, avoiding a reload
request for every keystroke. Going into the background publishes immediately.

`WidgetSync` saves SwiftData before writing the shared file and requests
`WidgetCenter.reloadTimelines(ofKind:)` only when the snapshot changed.
Atomic writes prevent the extension from reading a partially written file.

The timeline contains the current snapshot and an empty snapshot for the
next local day. It also requests a fresh timeline after that boundary.
Every file read checks the saved date, so yesterday's priorities are not
presented as today's, even if the app has not been opened again.

Calendar arithmetic accounts for days that are not exactly 24 hours long.
WidgetKit controls when updates are displayed; a reload request is not a
promise of an immediate refresh or an exact midnight redraw.

## Opening Today

The widget uses `widgetURL` with `daily3://today`. The app registers the
`daily3` URL scheme and handles that URL with SwiftUI's `onOpenURL`.
Its TabView has a selected tab, allowing the link to switch back to Today
even if the user last left the app on Settings or Statistics.

## Xcode and Device Setup

Run the `Daily3` scheme to build the application together with its embedded
widget. The extension's Info.plist declares `com.apple.widgetkit-extension`.
The app's Info.plist adds the custom URL scheme. The `Configuration` folder
contains those property lists and both entitlement files.

For a physical device, the signing team and provisioning profiles must
support App Groups. Register or select `group.com.anayaydin.Daily3` for both
the app and extension under Signing & Capabilities. The repository's
entitlement files do not register the group in an Apple Developer account.
Use a team that supports this capability when signing for a device.

## Manual Check

1. Run Daily 3, enter today's priorities and complete one.
2. On the Home Screen, open the widget gallery and find Daily 3.
3. Add the small or medium widget. Check its priorities and progress.
4. Edit a priority or completion state in Daily 3, return to Home and allow
   WidgetKit to refresh the widget.
5. Leave the app on another tab, then tap the widget. Today should open.
6. Check empty slots, long titles, Dark Mode and both sizes.
7. On a later day, confirm yesterday's priorities are no longer displayed.

This phase does not include task completion inside the widget, Lock Screen
widgets or Apple Watch complications.

## Topics to Explore

App extension targets and embedding; App Groups and entitlements; Codable;
atomic file writes; WidgetKit TimelineProvider and TimelineEntry; timeline
reload policies; SwiftUI widget layouts; task cancellation and debouncing;
URL schemes and onOpenURL; fixed-size rendering tests.

## Apple Documentation

- [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- [Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
