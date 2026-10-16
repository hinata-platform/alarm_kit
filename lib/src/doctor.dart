import 'dart:io';

/// One finding of `dart run alarm_kit:setup --doctor`.
class DoctorFinding {
  const DoctorFinding(this.ok, this.message);

  final bool ok;
  final String message;

  @override
  String toString() => '${ok ? '✓' : '✗'} $message';
}

/// The checks of an iOS app that schedules alarms with alarm_kit. Plain
/// `dart:io`, so it runs without Flutter.
///
/// - `NSAlarmKitUsageDescription` in the Runner's Info.plist.
/// - No `com.apple.developer.alarmkit` entitlement: there is no such thing, and
///   a provisioning profile cannot carry it, so signing fails.
/// - A widget extension, which the system needs for the countdown
///   presentation; without it the system may drop an alarm.
/// - `AlarmKitMetadata` and an `ActivityConfiguration` for
///   `AlarmAttributes<AlarmKitMetadata>` in that extension, compiled into its
///   target.
List<DoctorFinding> runDoctor(Directory ios) {
  final findings = <DoctorFinding>[];
  if (!ios.existsSync()) {
    return [DoctorFinding(false, 'No iOS project at ${ios.path}.')];
  }

  final plist = File('${ios.path}/Runner/Info.plist');
  final usage = plist.existsSync()
      ? _plistString(plist.readAsStringSync(), 'NSAlarmKitUsageDescription')
      : null;
  findings.add(
    usage != null && usage.trim().isNotEmpty
        ? const DoctorFinding(
            true,
            'Runner/Info.plist explains why the app sets alarms '
            '(NSAlarmKitUsageDescription).',
          )
        : const DoctorFinding(
            false,
            'Runner/Info.plist needs NSAlarmKitUsageDescription: one sentence '
            'the system shows when it asks the person.',
          ),
  );

  final swiftFiles = <File>[];
  final entitlements = <File>[];
  final extensionPlists = <File>[];
  for (final entity in ios.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.path;
    if (path.contains('/Pods/') ||
        path.contains('/.symlinks/') ||
        path.contains('/build/')) {
      continue;
    }
    if (path.endsWith('.swift')) swiftFiles.add(entity);
    if (path.endsWith('.entitlements')) entitlements.add(entity);
    if (path.endsWith('/Info.plist') &&
        entity.readAsStringSync().contains('com.apple.widgetkit-extension')) {
      extensionPlists.add(entity);
    }
  }

  final wrong = [
    for (final file in entitlements)
      if (file.readAsStringSync().contains('com.apple.developer.alarmkit'))
        _relative(ios, file),
  ];
  findings.add(
    wrong.isEmpty
        ? const DoctorFinding(
            true,
            'No AlarmKit entitlement (AlarmKit needs none).',
          )
        : DoctorFinding(
            false,
            'Remove com.apple.developer.alarmkit from ${wrong.join(', ')}: '
            'the entitlement does not exist and breaks code signing.',
          ),
  );

  if (extensionPlists.isEmpty) {
    findings.add(
      const DoctorFinding(
        false,
        'No widget extension. Add one (File > New > Target > Widget '
        'Extension); the system needs it to draw the countdown and may drop '
        'alarms without it.',
      ),
    );
    return findings;
  }
  final extensionDirs = {for (final p in extensionPlists) p.parent.path};
  findings.add(
    DoctorFinding(
      true,
      'Widget extension: ${[for (final d in extensionDirs) _relative(ios, Directory(d))].join(', ')}.',
    ),
  );

  // A file shared by app and extension may live anywhere but in the Runner;
  // whether the extension compiles it is checked in the project below.
  bool inExtension(File file) => !file.path.startsWith('${ios.path}/Runner/');
  final metadata = swiftFiles.where(
    (f) =>
        inExtension(f) &&
        RegExp(
          r'struct\s+AlarmKitMetadata\s*:\s*AlarmMetadata',
        ).hasMatch(f.readAsStringSync()),
  );
  final activity = swiftFiles.where(
    (f) =>
        inExtension(f) &&
        f.readAsStringSync().contains('AlarmAttributes<AlarmKitMetadata>'),
  );
  findings
    ..add(
      metadata.isNotEmpty
          ? DoctorFinding(
              true,
              'AlarmKitMetadata: ${_relative(ios, metadata.first)}.',
            )
          : const DoctorFinding(
              false,
              'The extension has no AlarmKitMetadata. Copy it with '
              '`dart run alarm_kit:setup --extension ios/<Extension>`.',
            ),
    )
    ..add(
      activity.isNotEmpty
          ? DoctorFinding(
              true,
              'Countdown views: ${_relative(ios, activity.first)}.',
            )
          : const DoctorFinding(
              false,
              'The extension draws no AlarmAttributes<AlarmKitMetadata>. Add '
              'an ActivityConfiguration for it (template: AlarmLiveActivity.swift).',
            ),
    );

  final project = File('${ios.path}/Runner.xcodeproj/project.pbxproj');
  if (project.existsSync()) {
    final pbx = project.readAsStringSync();
    for (final file in [...metadata.take(1), ...activity.take(1)]) {
      final name = file.uri.pathSegments.last;
      final targets = targetsCompiling(pbx, name);
      final extensionTarget = targets.any((t) => t != 'Runner');
      findings.add(
        extensionTarget
            ? DoctorFinding(
                true,
                '$name is compiled into ${targets.join(', ')}.',
              )
            : DoctorFinding(
                false,
                '$name is not in the widget extension target. Tick the '
                'extension under Target Membership in Xcode.',
              ),
      );
    }
  }
  return findings;
}

/// The names of the targets whose Sources phase compiles [fileName].
List<String> targetsCompiling(String pbx, String fileName) {
  final buildFiles = RegExp(
    r'(\w{24}) /\* ' +
        RegExp.escape(fileName) +
        r' in Sources \*/ = \{isa = PBXBuildFile',
  ).allMatches(pbx).map((m) => m.group(1)!).toSet();
  if (buildFiles.isEmpty) return const [];
  final phases = <String>{};
  for (final match in RegExp(
    r'(\w{24}) /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase;[^}]*?files = \(([^)]*)\)',
  ).allMatches(pbx)) {
    if (buildFiles.any((id) => match.group(2)!.contains(id))) {
      phases.add(match.group(1)!);
    }
  }
  return [
    for (final match in RegExp(
      r'\w{24} /\* ([^*]+?) \*/ = \{\s*isa = PBXNativeTarget;[^}]*?buildPhases = \(([^)]*)\)',
    ).allMatches(pbx))
      if (phases.any((id) => match.group(2)!.contains(id))) match.group(1)!,
  ];
}

String? _plistString(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
  ).firstMatch(plist);
  return match?.group(1);
}

String _relative(Directory root, FileSystemEntity entity) {
  final prefix = '${root.path}/';
  return entity.path.startsWith(prefix)
      ? entity.path.substring(prefix.length)
      : entity.path;
}
