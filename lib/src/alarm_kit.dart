import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'messages.g.dart';
import 'models.dart';

/// AlarmKit on iOS and iPadOS 26: alarms and timers that ring through silent
/// mode and Focus and show the system's countdown Live Activity.
///
/// Everywhere else (older iOS, Android, desktop, web) [isSupported] is false,
/// the streams are empty and every other call throws an [AlarmKitException]
/// with [AlarmKitErrorCode.unsupported].
///
/// No entitlement is needed. AlarmKit has none, and adding a
/// `com.apple.developer.alarmkit` key breaks code signing. The app needs
/// `NSAlarmKitUsageDescription` in its Info.plist, and a widget extension for
/// the countdown presentation (`dart run alarm_kit:setup --doctor`).
class AlarmKit {
  AlarmKit({
    @visibleForTesting AlarmKitHostApi? api,
    @visibleForTesting bool? isIOS,
    @visibleForTesting Stream<List<Alarm>> Function()? alarmUpdates,
    @visibleForTesting
    Stream<AlarmAuthorization> Function()? authorizationUpdates,
  }) : _api = api ?? AlarmKitHostApi(),
       _isIOS =
           isIOS ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
       _alarmUpdates = alarmUpdates,
       _authorizationUpdates = authorizationUpdates;

  /// The one instance an app needs.
  static final AlarmKit instance = AlarmKit();

  final AlarmKitHostApi _api;
  final bool _isIOS;
  final Stream<List<Alarm>> Function()? _alarmUpdates;
  final Stream<AlarmAuthorization> Function()? _authorizationUpdates;

  bool? _supported;

  /// Whether this system has AlarmKit. Asked once and remembered.
  Future<bool> isSupported() async {
    if (!_isIOS) return false;
    final known = _supported;
    if (known != null) return known;
    try {
      return _supported = await _api.isSupported();
    } on MissingPluginException {
      return _supported = false;
    }
  }

  Future<AlarmAuthorization> authorizationState() =>
      _call(() async => _authorization(await _api.authorizationState()));

  /// Asks the person, once; later calls answer what they chose. Call it from a
  /// tap, where the question makes sense.
  Future<AlarmAuthorization> requestAuthorization() =>
      _call(() async => _authorization(await _api.requestAuthorization()));

  /// A timer that rings after [duration], with the system's countdown on the
  /// lock screen and in the Dynamic Island.
  ///
  /// [id] is a UUID of the app's choosing; scheduling the same id again
  /// replaces the alarm. [stopIntent] and [secondaryIntent] are keys the app
  /// maps to its own `LiveActivityIntent`s in Swift (`AlarmKitIntents`).
  /// [metadataKind] is the one word the widget extension reads. [sound] names
  /// a `.caf`, `.aiff` or `.wav` file of under 30 seconds in the app's bundle.
  Future<Alarm> scheduleTimer({
    required String id,
    required Duration duration,
    required AlarmPresentation presentation,
    required Color tint,
    String? metadataKind,
    String? stopIntent,
    String? secondaryIntent,
    String? sound,
    Duration? postAlert,
  }) => _schedule(
    ConfigurationMessage(
      id: id,
      presentation: _presentation(presentation),
      tintColor: tint.toARGB32(),
      metadataKind: metadataKind,
      preAlert: duration.inMilliseconds / 1000,
      postAlert: postAlert == null ? null : postAlert.inMilliseconds / 1000,
      stopIntent: stopIntent,
      secondaryIntent: secondaryIntent,
      sound: sound,
    ),
  );

  /// An alarm that rings on [schedule]: once at a fixed moment, or at a time
  /// of day, repeating on weekdays.
  Future<Alarm> scheduleAlarm({
    required String id,
    required AlarmSchedule schedule,
    required AlarmPresentation presentation,
    required Color tint,
    String? metadataKind,
    String? stopIntent,
    String? secondaryIntent,
    String? sound,
    Duration? postAlert,
  }) => _schedule(
    ConfigurationMessage(
      id: id,
      presentation: _presentation(presentation),
      tintColor: tint.toARGB32(),
      metadataKind: metadataKind,
      postAlert: postAlert == null ? null : postAlert.inMilliseconds / 1000,
      schedule: _scheduleMessage(schedule),
      stopIntent: stopIntent,
      secondaryIntent: secondaryIntent,
      sound: sound,
    ),
  );

  /// Starts the countdown of an alarm again (a snooze).
  Future<void> countdown(String id) => _call(() => _api.countdown(id));

  /// Removes an alarm, ringing or not.
  Future<void> cancel(String id) => _call(() => _api.cancel(id));

  /// Silences a ringing alarm; a repeating one stays for its next time.
  Future<void> stop(String id) => _call(() => _api.stop(id));

  Future<void> pause(String id) => _call(() => _api.pause(id));

  Future<void> resume(String id) => _call(() => _api.resume(id));

  /// The alarms of this app the system holds now.
  Future<List<Alarm>> alarms() => _call(
    () async => [for (final alarm in await _api.alarms()) _alarm(alarm)],
  );

  /// Every change to this app's alarms, as the full list. Empty where
  /// AlarmKit is missing.
  Stream<List<Alarm>> get alarmUpdates {
    final injected = _alarmUpdates;
    if (injected != null) return injected();
    if (!_isIOS) return const Stream.empty();
    return _whenSupported(
      () => _platformAlarmUpdates().map(
        (update) => [for (final alarm in update.alarms) _alarm(alarm)],
      ),
    );
  }

  /// Every change of the person's answer, also one made in Settings.
  Stream<AlarmAuthorization> get authorizationUpdates {
    final injected = _authorizationUpdates;
    if (injected != null) return injected();
    if (!_isIOS) return const Stream.empty();
    return _whenSupported(
      () => _platformAuthorizationUpdates().map(
        (update) => _authorization(update.state),
      ),
    );
  }

  Stream<T> _whenSupported<T>(Stream<T> Function() open) async* {
    if (await isSupported()) yield* open();
  }

  Future<Alarm> _schedule(ConfigurationMessage configuration) =>
      _call(() async {
        try {
          return _alarm(await _api.schedule(configuration));
        } on PlatformException catch (error) {
          // AlarmKit says no more than "failed" when the person said no.
          if (error.code == 'failed' &&
              await _api.authorizationState() == AuthorizationMessage.denied) {
            throw AlarmKitException(
              AlarmKitErrorCode.notAuthorized,
              error.message,
            );
          }
          rethrow;
        }
      });

  Future<T> _call<T>(Future<T> Function() body) async {
    if (!await isSupported()) {
      throw const AlarmKitException(AlarmKitErrorCode.unsupported);
    }
    try {
      return await body();
    } on PlatformException catch (error) {
      throw AlarmKitException(_code(error.code), error.message);
    }
  }
}

Stream<AlarmListMessage> _platformAlarmUpdates() => alarmUpdates();

Stream<AuthorizationUpdateMessage> _platformAuthorizationUpdates() =>
    authorizationUpdates();

AlarmKitErrorCode _code(String code) => switch (code) {
  'unsupported' => AlarmKitErrorCode.unsupported,
  'maximumLimitReached' => AlarmKitErrorCode.maximumLimitReached,
  'invalidId' => AlarmKitErrorCode.invalidId,
  _ => AlarmKitErrorCode.failed,
};

AlarmAuthorization _authorization(AuthorizationMessage message) =>
    switch (message) {
      AuthorizationMessage.notDetermined => AlarmAuthorization.notDetermined,
      AuthorizationMessage.denied => AlarmAuthorization.denied,
      AuthorizationMessage.authorized => AlarmAuthorization.authorized,
    };

Alarm _alarm(AlarmMessage message) => Alarm(
  id: message.id,
  state: switch (message.state) {
    AlarmStateMessage.scheduled => AlarmState.scheduled,
    AlarmStateMessage.countdown => AlarmState.countdown,
    AlarmStateMessage.paused => AlarmState.paused,
    AlarmStateMessage.alerting => AlarmState.alerting,
  },
  preAlert: _duration(message.preAlert),
  postAlert: _duration(message.postAlert),
  schedule: _scheduleOf(message.schedule),
);

Duration? _duration(double? seconds) =>
    seconds == null ? null : Duration(milliseconds: (seconds * 1000).round());

/// Dart counts Monday as 1 and Sunday as 7; `Calendar` counts Sunday as 1.
int _toCalendarDay(int weekday) => weekday % 7 + 1;

int _fromCalendarDay(int day) => day == 1 ? DateTime.sunday : day - 1;

AlarmSchedule? _scheduleOf(ScheduleMessage? message) {
  if (message == null) return null;
  final fixed = message.fixedMillis;
  if (fixed != null) {
    return AlarmSchedule.fixed(DateTime.fromMillisecondsSinceEpoch(fixed));
  }
  final hour = message.hour;
  final minute = message.minute;
  if (hour == null || minute == null) return null;
  return AlarmSchedule.relative(
    hour: hour,
    minute: minute,
    weekdays: {
      for (final day in message.weekdays ?? const <int>[])
        if (day >= 1 && day <= 7) _fromCalendarDay(day),
    },
  );
}

ScheduleMessage _scheduleMessage(AlarmSchedule schedule) => switch (schedule) {
  FixedAlarmSchedule(:final at) => ScheduleMessage(
    fixedMillis: at.millisecondsSinceEpoch,
  ),
  RelativeAlarmSchedule(:final hour, :final minute, :final weekdays) =>
    ScheduleMessage(
      hour: hour,
      minute: minute,
      weekdays: [for (final day in weekdays) _toCalendarDay(day)]..sort(),
    ),
};

ButtonMessage _button(AlarmButton button) => ButtonMessage(
  text: button.text,
  textColor: button.textColor.toARGB32(),
  systemImageName: button.systemImageName,
);

PresentationMessage _presentation(AlarmPresentation presentation) {
  final alert = presentation.alert;
  final countdown = presentation.countdown;
  final paused = presentation.paused;
  return PresentationMessage(
    alert: AlertMessage(
      title: alert.title,
      stopButton: _button(alert.stopButton),
      secondaryButton: alert.secondaryButton == null
          ? null
          : _button(alert.secondaryButton!),
      secondaryBehavior: switch (alert.secondaryBehavior) {
        AlarmSecondaryBehavior.countdown => SecondaryBehaviorMessage.countdown,
        AlarmSecondaryBehavior.custom => SecondaryBehaviorMessage.custom,
        null => null,
      },
    ),
    countdown: countdown == null
        ? null
        : CountdownMessage(
            title: countdown.title,
            pauseButton: countdown.pauseButton == null
                ? null
                : _button(countdown.pauseButton!),
          ),
    paused: paused == null
        ? null
        : PausedMessage(
            title: paused.title,
            resumeButton: _button(paused.resumeButton),
          ),
  );
}
