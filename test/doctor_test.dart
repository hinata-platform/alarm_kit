import 'dart:io';

import 'package:alarm_kit/src/doctor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory ios;

  setUp(() => ios = Directory.systemTemp.createTempSync('alarm_kit_doctor'));
  tearDown(() => ios.deleteSync(recursive: true));

  void write(String path, String content) => (File(
    '${ios.path}/$path',
  )..createSync(recursive: true)).writeAsStringSync(content);

  List<DoctorFinding> failures() => [
    for (final f in runDoctor(ios))
      if (!f.ok) f,
  ];

  test('finds the missing usage description and extension', () {
    write('Runner/Info.plist', '<plist><dict></dict></plist>');
    final failed = failures().map((f) => f.message).join('\n');
    expect(failed, contains('NSAlarmKitUsageDescription'));
    expect(failed, contains('No widget extension'));
  });

  test('warns about the entitlement that does not exist', () {
    write(
      'Runner/Info.plist',
      '<key>NSAlarmKitUsageDescription</key><string>Rings.</string>',
    );
    write(
      'Runner/Runner.entitlements',
      '<key>com.apple.developer.alarmkit</key><true/>',
    );
    expect(
      failures().map((f) => f.message).join('\n'),
      contains('com.apple.developer.alarmkit'),
    );
  });

  test('is content with an extension that compiles both files', () {
    write(
      'Runner/Info.plist',
      '<key>NSAlarmKitUsageDescription</key><string>Rings.</string>',
    );
    write('Widgets/Info.plist', 'com.apple.widgetkit-extension');
    write(
      'Widgets/AlarmKitMetadata.swift',
      'struct AlarmKitMetadata: AlarmMetadata {}',
    );
    write(
      'Widgets/Alarm.swift',
      'ActivityConfiguration(for: AlarmAttributes<AlarmKitMetadata>.self)',
    );
    write('Runner.xcodeproj/project.pbxproj', '''
		AAAAAAAAAAAAAAAAAAAAAAA1 /* AlarmKitMetadata.swift in Sources */ = {isa = PBXBuildFile; };
		AAAAAAAAAAAAAAAAAAAAAAA2 /* Alarm.swift in Sources */ = {isa = PBXBuildFile; };
		BBBBBBBBBBBBBBBBBBBBBBB1 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			files = (
				AAAAAAAAAAAAAAAAAAAAAAA1 /* AlarmKitMetadata.swift in Sources */,
				AAAAAAAAAAAAAAAAAAAAAAA2 /* Alarm.swift in Sources */,
			);
		};
		CCCCCCCCCCCCCCCCCCCCCCC1 /* Widgets */ = {
			isa = PBXNativeTarget;
			buildPhases = (
				BBBBBBBBBBBBBBBBBBBBBBB1 /* Sources */,
			);
		};
''');
    expect(failures(), isEmpty);
  });

  test('a file outside the extension target is named', () {
    write(
      'Runner/Info.plist',
      '<key>NSAlarmKitUsageDescription</key><string>Rings.</string>',
    );
    write('Widgets/Info.plist', 'com.apple.widgetkit-extension');
    write(
      'Widgets/AlarmKitMetadata.swift',
      'struct AlarmKitMetadata: AlarmMetadata {}',
    );
    write(
      'Widgets/Alarm.swift',
      'ActivityConfiguration(for: AlarmAttributes<AlarmKitMetadata>.self)',
    );
    write('Runner.xcodeproj/project.pbxproj', '');
    expect(
      failures().map((f) => f.message).join('\n'),
      contains('Target Membership'),
    );
  });
}
