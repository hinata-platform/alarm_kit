# alarm_kit

[AlarmKit](https://developer.apple.com/documentation/alarmkit) for Flutter:
alarms and timers on iOS and iPadOS 26 that ring through silent mode and
Focus, also when the app is closed, with the system's countdown on the lock
screen, in the Dynamic Island and on a paired Apple Watch.

```dart
final kit = AlarmKit.instance;
if (await kit.isSupported()) {
  await kit.requestAuthorization();
  await kit.scheduleTimer(
    id: '6b1f4c1e-0a7d-4f43-9a51-5d9f0c8e2a10',
    duration: const Duration(minutes: 25),
    tint: const Color(0xFFD9A032),
    presentation: const AlarmPresentation(
      alert: AlarmAlert(
        title: 'Time is up',
        stopButton: AlarmButton(text: 'Stop', systemImageName: 'stop.fill'),
      ),
      countdown: AlarmCountdown(title: 'Focus'),
    ),
  );
}
```

Below iOS 26, and on every other platform, `isSupported()` is false, the
streams stay empty and every other call throws an `AlarmKitException` with
`AlarmKitErrorCode.unsupported`. AlarmKit is weak-linked, so an app with an
older deployment target still launches there.

## Setup

**There is no AlarmKit entitlement.** `com.apple.developer.alarmkit` does not
exist; a provisioning profile cannot carry it and signing fails with it. Two
things are needed instead:

1. `NSAlarmKitUsageDescription` in `ios/Runner/Info.plist`: one sentence the
   system shows when it asks the person. The system asks on the first
   schedule, or when you call `requestAuthorization()`.
2. A **widget extension** that draws the countdown. The system draws a ringing
   alarm itself, but the countdown and paused states are a Live Activity of
   your app, and without one the system may drop the alarm.

```sh
dart run alarm_kit:setup --extension ios/<YourWidgetExtension>
dart run alarm_kit:setup --doctor
```

The first copies `AlarmKitMetadata.swift` and `AlarmLiveActivity.swift` into
the extension's folder; add both to the extension target in Xcode and put
`AlarmLiveActivity()` in its `WidgetBundle`. The extension cannot link the
plugin, so it carries its own copy of `AlarmKitMetadata`; ActivityKit matches
the two by name, so keep it as it is. The doctor checks the Info.plist, the
entitlements, the extension and that both files are compiled into it.

Also set `NSSupportsLiveActivities` to `true` in the Runner's Info.plist.

## Buttons that act

A ringing alarm has a stop button and, optionally, a secondary one. AlarmKit
runs a `LiveActivityIntent` for each, in your app's process, also when the app
is not running. Swift types cannot cross the channel, so Dart names a key and
your app maps it to its intent before the first alarm, in
`application(_:didFinishLaunchingWithOptions:)`:

```swift
import alarm_kit

if #available(iOS 17.0, *) {
  AlarmKitIntents.register { key in
    switch key {
    case "stop": return StopTimerIntent()
    case "next": return NextPhaseIntent()
    default: return nil
    }
  }
}
```

```dart
await kit.scheduleTimer(
  // ...
  stopIntent: 'stop',
  secondaryIntent: 'next',
  presentation: const AlarmPresentation(
    alert: AlarmAlert(
      title: 'Work interval over',
      stopButton: AlarmButton(text: 'Stop', systemImageName: 'stop.fill'),
      secondaryButton: AlarmButton(
        text: 'Take a break',
        systemImageName: 'cup.and.saucer.fill',
      ),
      secondaryBehavior: AlarmSecondaryBehavior.custom,
    ),
  ),
);
```

Without a registration, or for an unknown key, a button only silences the
alarm. With `AlarmSecondaryBehavior.countdown` the secondary button snoozes
for `postAlert` instead.

## What the system keeps

The system holds every alarm outside your app for as long as it exists: the
titles and button words, the times, the tint and the one `metadataKind` word
your extension reads. Keep them generic. A title that names a client or a
task shows on a locked screen and on a paired watch.

## Limits

- iOS and iPadOS 26 and later only; there is no AlarmKit on macOS or watchOS.
- Apple does not publish how many alarms an app may hold. Past the limit a
  schedule throws `AlarmKitErrorCode.maximumLimitReached`; fall back to a
  notification there.
- A sound is a `.caf`, `.aiff` or `.wav` file in the app's bundle, shorter
  than 30 seconds; the system's alarm sound when none is named.
- After a restart, Live Activities wait for the first unlock.
- An alarm is not a critical alert.

## License

MIT
