## 0.1.1

- Swift Package Manager: the package resolves (tools version 6.0, which
  builds in the Swift 6 language mode by itself).

## 0.1.0

- Timers and alarms through AlarmKit on iOS and iPadOS 26: `scheduleTimer`,
  `scheduleAlarm`, `pause`, `resume`, `countdown`, `stop`, `cancel`,
  `alarms` and `alarmUpdates`.
- Authorization: `requestAuthorization`, `authorizationState` and
  `authorizationUpdates`.
- The stop and secondary buttons run the app's own `LiveActivityIntent`s,
  mapped by key in Swift (`AlarmKitIntents.register`).
- The system's alarm limit comes back as `maximumLimitReached`.
- Below iOS 26 and on other platforms every call answers `unsupported`;
  AlarmKit is weak-linked, so the app still runs on iOS 15.
- `dart run alarm_kit:setup --doctor` checks the Info.plist, the
  entitlements and the widget extension; `--extension` copies the Swift
  templates.
