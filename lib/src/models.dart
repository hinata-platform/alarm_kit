import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Whether the person lets this app schedule alarms.
enum AlarmAuthorization {
  /// Not asked yet. AlarmKit asks by itself on the first schedule, or through
  /// [AlarmKit.requestAuthorization].
  notDetermined,
  denied,
  authorized,
}

/// Where an alarm stands in the system.
enum AlarmState {
  /// Waiting for its moment (an alarm with a schedule).
  scheduled,

  /// Counting down (a timer, or an alarm snoozed through its countdown).
  countdown,
  paused,

  /// Ringing now.
  alerting,
}

/// What the secondary button of a ringing alarm does.
enum AlarmSecondaryBehavior {
  /// Counts down again for the post-alert duration (a snooze).
  countdown,

  /// Runs the secondary intent of the alarm.
  custom,
}

/// One button the system draws for an alarm.
@immutable
class AlarmButton {
  const AlarmButton({
    required this.text,
    required this.systemImageName,
    this.textColor = const Color(0xFFFFFFFF),
  });

  /// In the reader's language; the system shows it as it is.
  final String text;

  /// An SF Symbol, like `stop.fill`.
  final String systemImageName;
  final Color textColor;

  @override
  bool operator ==(Object other) =>
      other is AlarmButton &&
      other.text == text &&
      other.systemImageName == systemImageName &&
      other.textColor == textColor;

  @override
  int get hashCode => Object.hash(text, systemImageName, textColor);
}

/// How a ringing alarm looks.
@immutable
class AlarmAlert {
  const AlarmAlert({
    required this.title,
    required this.stopButton,
    this.secondaryButton,
    this.secondaryBehavior,
  });

  final String title;

  final AlarmButton stopButton;
  final AlarmButton? secondaryButton;
  final AlarmSecondaryBehavior? secondaryBehavior;
}

/// How the countdown of a timer looks.
@immutable
class AlarmCountdown {
  const AlarmCountdown({required this.title, this.pauseButton});

  final String title;
  final AlarmButton? pauseButton;
}

/// How a paused countdown looks.
@immutable
class AlarmPaused {
  const AlarmPaused({required this.title, required this.resumeButton});

  final String title;
  final AlarmButton resumeButton;
}

/// Everything the system draws for one alarm. The countdown and paused parts
/// are drawn by the app's widget extension; without one the system may drop
/// an alarm that has them.
@immutable
class AlarmPresentation {
  const AlarmPresentation({required this.alert, this.countdown, this.paused});

  final AlarmAlert alert;
  final AlarmCountdown? countdown;
  final AlarmPaused? paused;
}

/// When an alarm rings: at a fixed moment, or at a time of day that repeats on
/// [weekdays].
@immutable
sealed class AlarmSchedule {
  const AlarmSchedule();

  const factory AlarmSchedule.fixed(DateTime at) = FixedAlarmSchedule;

  const factory AlarmSchedule.relative({
    required int hour,
    required int minute,
    Set<int> weekdays,
  }) = RelativeAlarmSchedule;
}

class FixedAlarmSchedule extends AlarmSchedule {
  const FixedAlarmSchedule(this.at);

  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is FixedAlarmSchedule &&
      other.at.millisecondsSinceEpoch == at.millisecondsSinceEpoch;

  @override
  int get hashCode => at.millisecondsSinceEpoch.hashCode;
}

class RelativeAlarmSchedule extends AlarmSchedule {
  const RelativeAlarmSchedule({
    required this.hour,
    required this.minute,
    this.weekdays = const {},
  });

  final int hour;
  final int minute;

  /// [DateTime.monday] to [DateTime.sunday]; empty rings once.
  final Set<int> weekdays;

  @override
  bool operator ==(Object other) =>
      other is RelativeAlarmSchedule &&
      other.hour == hour &&
      other.minute == minute &&
      setEquals(other.weekdays, weekdays);

  @override
  int get hashCode =>
      Object.hash(hour, minute, Object.hashAllUnordered(weekdays));
}

/// One alarm of this app as the system holds it.
@immutable
class Alarm {
  const Alarm({
    required this.id,
    required this.state,
    this.preAlert,
    this.postAlert,
    this.schedule,
  });

  /// Lower-case UUID.
  final String id;
  final AlarmState state;

  /// The countdown before it rings (a timer).
  final Duration? preAlert;

  /// The countdown after a snooze.
  final Duration? postAlert;
  final AlarmSchedule? schedule;

  @override
  bool operator ==(Object other) =>
      other is Alarm &&
      other.id == id &&
      other.state == state &&
      other.preAlert == preAlert &&
      other.postAlert == postAlert &&
      other.schedule == schedule;

  @override
  int get hashCode => Object.hash(id, state, preAlert, postAlert, schedule);

  @override
  String toString() => 'Alarm($id, ${state.name})';
}

/// Why a call into AlarmKit failed.
enum AlarmKitErrorCode {
  /// Below iOS and iPadOS 26.
  unsupported,

  /// The system holds no more alarms for this app. Apple does not publish the
  /// limit.
  maximumLimitReached,

  /// The id is not a UUID.
  invalidId,

  /// The person did not allow alarms.
  notAuthorized,

  /// Anything else; [AlarmKitException.message] says what.
  failed,
}

class AlarmKitException implements Exception {
  const AlarmKitException(this.code, [this.message]);

  final AlarmKitErrorCode code;
  final String? message;

  @override
  String toString() => 'AlarmKitException(${code.name}: $message)';
}
