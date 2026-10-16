// The channel between Dart and AlarmKit. Generate with:
//
//   tool/generate.sh
//
// Plain messages only; the public types in `lib/src/` wrap them.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    swiftOut: 'ios/alarm_kit/Sources/alarm_kit/Messages.g.swift',
    dartPackageName: 'alarm_kit',
  ),
)
enum AuthorizationMessage { notDetermined, denied, authorized }

enum AlarmStateMessage { scheduled, countdown, paused, alerting }

enum SecondaryBehaviorMessage { countdown, custom }

class ButtonMessage {
  ButtonMessage({
    required this.text,
    required this.textColor,
    required this.systemImageName,
  });

  String text;

  /// ARGB, as `Color.toARGB32()` gives it.
  int textColor;
  String systemImageName;
}

class AlertMessage {
  AlertMessage({required this.title, required this.stopButton});

  String title;
  ButtonMessage stopButton;
  ButtonMessage? secondaryButton;
  SecondaryBehaviorMessage? secondaryBehavior;
}

class CountdownMessage {
  CountdownMessage({required this.title});

  String title;
  ButtonMessage? pauseButton;
}

class PausedMessage {
  PausedMessage({required this.title, required this.resumeButton});

  String title;
  ButtonMessage resumeButton;
}

class PresentationMessage {
  PresentationMessage({required this.alert});

  AlertMessage alert;
  CountdownMessage? countdown;
  PausedMessage? paused;
}

/// A fixed moment, or a time of day that may repeat on weekdays.
class ScheduleMessage {
  /// Milliseconds since the epoch, for a fixed moment.
  int? fixedMillis;
  int? hour;
  int? minute;

  /// 1 is Sunday, 7 is Saturday, as `Calendar` counts.
  List<int>? weekdays;
}

class ConfigurationMessage {
  ConfigurationMessage({
    required this.id,
    required this.presentation,
    required this.tintColor,
  });

  /// A UUID string.
  String id;
  PresentationMessage presentation;

  /// ARGB.
  int tintColor;

  /// What the widget extension reads from `AlarmKitMetadata.kind`.
  String? metadataKind;

  /// Seconds before and after the alert; a timer has `preAlert` only.
  double? preAlert;
  double? postAlert;
  ScheduleMessage? schedule;

  /// Keys the app maps to a `LiveActivityIntent` through `AlarmKitIntents`.
  String? stopIntent;
  String? secondaryIntent;

  /// A sound file in the app's bundle; the system sound when null.
  String? sound;
}

class AlarmMessage {
  AlarmMessage({required this.id, required this.state});

  String id;
  AlarmStateMessage state;
  double? preAlert;
  double? postAlert;
  ScheduleMessage? schedule;
}

class AlarmListMessage {
  AlarmListMessage({required this.alarms});

  List<AlarmMessage> alarms;
}

class AuthorizationUpdateMessage {
  AuthorizationUpdateMessage({required this.state});

  AuthorizationMessage state;
}

@HostApi()
abstract class AlarmKitHostApi {
  /// Whether this system has AlarmKit (iOS and iPadOS 26 and later).
  bool isSupported();

  AuthorizationMessage authorizationState();

  @async
  AuthorizationMessage requestAuthorization();

  @async
  AlarmMessage schedule(ConfigurationMessage configuration);

  void countdown(String id);

  void cancel(String id);

  void stop(String id);

  void pause(String id);

  void resume(String id);

  List<AlarmMessage> alarms();
}

@EventChannelApi()
abstract class AlarmKitEventApi {
  AlarmListMessage alarmUpdates();

  AuthorizationUpdateMessage authorizationUpdates();
}
