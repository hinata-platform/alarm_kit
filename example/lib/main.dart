import 'dart:async';

import 'package:alarm_kit/alarm_kit.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'alarm_kit',
    theme: ThemeData(colorSchemeSeed: const Color(0xFFD9A032)),
    home: const TimerPage(),
  );
}

/// Plans, pauses, resumes and ends a one-minute timer, and lists what the
/// system holds.
class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  static const _id = '6b1f4c1e-0a7d-4f43-9a51-5d9f0c8e2a10';
  final _kit = AlarmKit.instance;
  StreamSubscription<List<Alarm>>? _updates;
  List<Alarm> _alarms = const [];
  bool? _supported;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final supported = await _kit.isSupported();
    setState(() => _supported = supported);
    if (!supported) return;
    _updates = _kit.alarmUpdates.listen((alarms) {
      setState(() => _alarms = alarms);
    });
    final alarms = await _kit.alarms();
    setState(() => _alarms = alarms);
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      setState(() => _message = null);
    } on AlarmKitException catch (error) {
      setState(() => _message = error.toString());
    }
  }

  Future<void> _schedule() => _run(() async {
    await _kit.requestAuthorization();
    await _kit.scheduleTimer(
      id: _id,
      duration: const Duration(minutes: 1),
      tint: const Color(0xFFD9A032),
      metadataKind: 'countdown',
      presentation: const AlarmPresentation(
        alert: AlarmAlert(
          title: 'Time is up',
          stopButton: AlarmButton(text: 'Stop', systemImageName: 'stop.fill'),
        ),
        countdown: AlarmCountdown(
          title: 'One minute',
          pauseButton: AlarmButton(
            text: 'Pause',
            systemImageName: 'pause.fill',
          ),
        ),
        paused: AlarmPaused(
          title: 'Paused',
          resumeButton: AlarmButton(
            text: 'Resume',
            systemImageName: 'play.fill',
          ),
        ),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final supported = _supported;
    return Scaffold(
      appBar: AppBar(title: const Text('alarm_kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (supported == false)
            const Text('AlarmKit needs iOS or iPadOS 26.')
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _schedule,
                  child: const Text('Start a one-minute timer'),
                ),
                OutlinedButton(
                  onPressed: () => _run(() => _kit.pause(_id)),
                  child: const Text('Pause'),
                ),
                OutlinedButton(
                  onPressed: () => _run(() => _kit.resume(_id)),
                  child: const Text('Resume'),
                ),
                OutlinedButton(
                  onPressed: () => _run(() => _kit.cancel(_id)),
                  child: const Text('End'),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Text('Alarms', style: Theme.of(context).textTheme.titleMedium),
            if (_alarms.isEmpty) const Text('None.'),
            for (final alarm in _alarms)
              ListTile(title: Text(alarm.state.name), subtitle: Text(alarm.id)),
          ],
        ],
      ),
    );
  }
}
