# Roadmap

Daily 3 will be developed incrementally, starting with the core daily
experience and expanding only when each feature supports the main idea.

## 0. Foundation ✅

- Xcode project
- Git repository
- GitHub repository
- Initial product documentation

## 1. Today / MVP ✅

Build the core Daily 3 experience.

Status: Completed as the first in-memory MVP. The app now has a Today
screen with three editable priorities, completion toggles, progress
feedback, and basic unit/UI test coverage.

- Today screen
- Three task slots
- Add and edit tasks
- Complete and uncomplete tasks
- 0/3 → 3/3 daily progress
- Empty and completed states

## 2. Persistence with SwiftData ✅

Store daily tasks locally using SwiftData.

Status: Completed. Daily entries and their three priority tasks are now
stored with SwiftData, and task titles plus completion states remain
available after the app is closed and reopened.

- Save and load tasks
- Store completion state
- Separate data by day
- Start each new day fresh
- Preserve previous days as history

## 3. Calendar ✅

Make previous days and progress visible.

Status: Completed. The Calendar tab now shows a monthly activity view,
supports navigation between months and returning to today, and displays
the selected day's priorities. Future days are visually disabled and
cannot be selected.

- Monthly calendar
- 0/3 → 3/3 activity intensity
- GitHub-inspired progress visualization
- Select previous days
- View tasks from a selected day

## 4. Statistics ✅

Provide simple insights into progress.

Status: Completed. The Statistics tab calculates all-time totals and
shows daily completion charts for rolling 7-day and 30-day periods,
including today.

Completion rate is completed priorities divided by planned priorities.
Empty task slots and future entries are excluded. With no planned
priorities, the rate is unavailable rather than 0%. A 3/3 day requires
three filled and completed priorities.

- Total completed tasks
- Number of 3/3 days
- Completion rate
- Weekly and monthly trends

## 5. Notifications ✅

Add optional daily reminders.

Status: Completed for this phase. Settings includes independent morning and evening
reminders with adjustable local times. Preferences use UserDefaults;
UserNotifications schedules recurring notifications on the device.
Permission is requested only when enabling a reminder. See the
[daily reminders chapter](notifications.md) for the implementation and
manual checks.

Automated tests cover permission, scheduling and persistence. Manual
background notification delivery has not yet been verified.

- Morning reminder to choose today's priorities
- Optional evening reminder
- Notification settings

## 6. Widget

Keep today's priorities visible from the Home Screen.

Status: Implemented; awaiting Home Screen placement and refresh verification.
A read-only small and medium widget shares today's
priorities through an App Group snapshot without moving the SwiftData
store. Its timeline includes an empty next-day state, and tapping it opens
Today. See the [widget chapter](widget.md) for setup and manual checks.

Automated tests cover shared snapshots, day rollover, the original database
location and the Today deep link. Layout rendering checks include both
sizes, empty and completed states, Dark Mode and large text.

- Show today's three tasks
- Show daily progress
- Open Daily 3 from the widget

## 7. Apple Watch

Bring the core Daily 3 experience to Apple Watch.

- View today's priorities
- Complete tasks from the watch
- Keep progress synchronized with iPhone

## 8. UX & Polish

Refine the overall experience.

- Animations and haptics
- Dark Mode
- Accessibility
- Empty states
- Edge cases
- Visual polish

## 9. Release

Prepare Daily 3 for real users.

- App icon
- TestFlight
- App Store metadata
- Privacy information
- App Store submission
