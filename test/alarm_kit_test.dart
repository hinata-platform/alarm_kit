import 'package:alarm_kit/alarm_kit.dart';
import 'package:alarm_kit/src/messages.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHostApi implements AlarmKitHostApi {
  bool supported = true;
  AuthorizationMessage authorization = AuthorizationMessage.authorized;
  ConfigurationMessage? scheduled;
  PlatformException? scheduleError;
  final List<String> calls = [];
  List<AlarmMessage> list = [];

  @override
  Future<bool> isSupported() async {
    calls.add('isSupported');
    return supported;
  }

  @override
  Future<AuthorizationMessage> authorizationState() async => authorization;

  @override
  Future<AuthorizationMessage> requestAuthorization() async {
    calls.add('request');
    return authorization;
  }

  @override
  Future<AlarmMessage> schedule(ConfigurationMessage configuration) async {
    final error = scheduleError;
    if (error != null) throw error;
    scheduled = configuration;
    return AlarmMessage(
      id: configuration.id,
      state: AlarmStateMessage.countdown,
      preAlert: configuration.preAlert,
    );
  }

  @override
  Future<void> cancel(String id) async => calls.add('cancel $id');

  @override
  Future<void> countdown(String id) async => calls.add('countdown $id');

  @override
  Future<void> pause(String id) async => calls.add('pause $id');

  @override
  Future<void> resume(String id) async => calls.add('resume $id');

  @override
  Future<void> stop(String id) async => calls.add('stop $id');

  @override
  Future<List<AlarmMessage>> alarms() async => list;

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';
}

const id = '0f8e6a2c-1d3b-4c5e-9f70-112233445566';

const presentation = AlarmPresentation(
  alert: AlarmAlert(
    title: 'Interval over',
    stopButton: AlarmButton(text: 'Stop', systemImageName: 'stop.fill'),
    secondaryButton: AlarmButton(
      text: 'Take a break',
      systemImageName: 'cup.and.saucer.fill',
      textColor: Color(0xFFD9A032),
    ),
    secondaryBehavior: AlarmSecondaryBehavior.custom,
  ),
  countdown: AlarmCountdown(title: 'Interval'),
);

void main() {
  late FakeHostApi api;
  late AlarmKit kit;

  setUp(() {
    api = FakeHostApi();
    kit = AlarmKit(api: api, isIOS: true);
  });

  test('is unsupported off iOS without asking the platform', () async {
    final other = AlarmKit(api: api, isIOS: false);
    expect(await other.isSupported(), isFalse);
    expect(api.calls, isEmpty);
    await expectLater(
      other.cancel(id),
      throwsA(
        isA<AlarmKitException>().having(
          (e) => e.code,
          'code',
          AlarmKitErrorCode.unsupported,
        ),
      ),
    );
    expect(await other.alarmUpdates.toList(), isEmpty);
  });

  test('asks the platform once whether AlarmKit exists', () async {
    api.supported = false;
    expect(await kit.isSupported(), isFalse);
    expect(await kit.isSupported(), isFalse);
    expect(api.calls.where((c) => c == 'isSupported'), hasLength(1));
    await expectLater(
      kit.requestAuthorization(),
      throwsA(isA<AlarmKitException>()),
    );
    expect(api.calls, isNot(contains('request')));
  });

  test('schedules a timer with its presentation, tint and intents', () async {
    final alarm = await kit.scheduleTimer(
      id: id,
      duration: const Duration(minutes: 25),
      presentation: presentation,
      tint: const Color(0xFFD9A032),
      metadataKind: 'work',
      stopIntent: 'stop',
      secondaryIntent: 'advancePhase',
    );
    final sent = api.scheduled!;
    expect(sent.id, id);
    expect(sent.preAlert, 1500);
    expect(sent.postAlert, isNull);
    expect(sent.schedule, isNull);
    expect(sent.tintColor, 0xFFD9A032);
    expect(sent.metadataKind, 'work');
    expect(sent.stopIntent, 'stop');
    expect(sent.secondaryIntent, 'advancePhase');
    expect(sent.presentation.alert.title, 'Interval over');
    expect(sent.presentation.alert.stopButton.systemImageName, 'stop.fill');
    expect(sent.presentation.alert.secondaryButton!.textColor, 0xFFD9A032);
    expect(
      sent.presentation.alert.secondaryBehavior,
      SecondaryBehaviorMessage.custom,
    );
    expect(sent.presentation.countdown!.title, 'Interval');
    expect(sent.presentation.paused, isNull);
    expect(alarm.state, AlarmState.countdown);
    expect(alarm.preAlert, const Duration(minutes: 25));
  });

  test('sends weekdays the way Calendar counts them', () async {
    await kit.scheduleAlarm(
      id: id,
      schedule: const AlarmSchedule.relative(
        hour: 7,
        minute: 30,
        weekdays: {DateTime.sunday, DateTime.monday, DateTime.saturday},
      ),
      presentation: presentation,
      tint: const Color(0xFF2D2B55),
    );
    final schedule = api.scheduled!.schedule!;
    expect(schedule.hour, 7);
    expect(schedule.minute, 30);
    expect(schedule.weekdays, [1, 2, 7]);
  });

  test('reads alarms back, weekdays and all', () async {
    api.list = [
      AlarmMessage(
        id: id,
        state: AlarmStateMessage.alerting,
        schedule: ScheduleMessage(hour: 6, minute: 0, weekdays: [1, 2]),
      ),
      AlarmMessage(
        id: 'b',
        state: AlarmStateMessage.scheduled,
        schedule: ScheduleMessage(fixedMillis: 1700000000000),
      ),
    ];
    final alarms = await kit.alarms();
    expect(alarms.first.state, AlarmState.alerting);
    expect(
      alarms.first.schedule,
      const AlarmSchedule.relative(
        hour: 6,
        minute: 0,
        weekdays: {DateTime.sunday, DateTime.monday},
      ),
    );
    expect(
      alarms.last.schedule,
      AlarmSchedule.fixed(DateTime.fromMillisecondsSinceEpoch(1700000000000)),
    );
  });

  test('names the alarm limit', () async {
    api.scheduleError = PlatformException(code: 'maximumLimitReached');
    await expectLater(
      kit.scheduleTimer(
        id: id,
        duration: const Duration(minutes: 5),
        presentation: presentation,
        tint: const Color(0xFFD9A032),
      ),
      throwsA(
        isA<AlarmKitException>().having(
          (e) => e.code,
          'code',
          AlarmKitErrorCode.maximumLimitReached,
        ),
      ),
    );
  });

  test('says a refusal is one when the person said no', () async {
    api
      ..scheduleError = PlatformException(code: 'failed')
      ..authorization = AuthorizationMessage.denied;
    await expectLater(
      kit.scheduleTimer(
        id: id,
        duration: const Duration(minutes: 5),
        presentation: presentation,
        tint: const Color(0xFFD9A032),
      ),
      throwsA(
        isA<AlarmKitException>().having(
          (e) => e.code,
          'code',
          AlarmKitErrorCode.notAuthorized,
        ),
      ),
    );
  });

  test('hands the controls through by id', () async {
    await kit.pause(id);
    await kit.resume(id);
    await kit.countdown(id);
    await kit.stop(id);
    await kit.cancel(id);
    expect(api.calls.where((c) => c != 'isSupported'), [
      'pause $id',
      'resume $id',
      'countdown $id',
      'stop $id',
      'cancel $id',
    ]);
  });

  test('maps the authorization', () async {
    api.authorization = AuthorizationMessage.notDetermined;
    expect(await kit.authorizationState(), AlarmAuthorization.notDetermined);
    api.authorization = AuthorizationMessage.authorized;
    expect(await kit.requestAuthorization(), AlarmAuthorization.authorized);
  });
}
