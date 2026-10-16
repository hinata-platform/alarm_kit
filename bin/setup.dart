import 'dart:io';
import 'dart:isolate';

import 'package:alarm_kit/src/doctor.dart';

const _usage = '''
Sets an iOS app up for alarm_kit.

  dart run alarm_kit:setup --doctor
      Checks the Info.plist, the entitlements and the widget extension.

  dart run alarm_kit:setup --extension ios/<WidgetExtension>
      Copies AlarmKitMetadata.swift and AlarmLiveActivity.swift into the
      extension's folder (nothing is overwritten). Add both to the extension
      target in Xcode afterwards.

Options:
  --ios <dir>   The iOS project (default: ios).
''';

Future<void> main(List<String> args) async {
  String? option(String name) {
    final index = args.indexOf(name);
    return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
  }

  final ios = Directory(option('--ios') ?? 'ios');
  final extension = option('--extension');
  if (args.contains('--doctor')) {
    final findings = runDoctor(ios);
    findings.forEach(stdout.writeln);
    exitCode = findings.every((f) => f.ok) ? 0 : 1;
    return;
  }
  if (extension != null) {
    exitCode = await _copyTemplates(Directory(extension));
    return;
  }
  stdout.write(_usage);
  exitCode = args.isEmpty || args.contains('--help') ? 0 : 64;
}

Future<int> _copyTemplates(Directory target) async {
  if (!target.existsSync()) {
    stderr.writeln('No folder ${target.path}.');
    return 1;
  }
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:alarm_kit/alarm_kit.dart'),
  );
  if (library == null) {
    stderr.writeln('alarm_kit is not a dependency of this app.');
    return 1;
  }
  final templates = Directory.fromUri(library.resolve('../ios/Templates/'));
  for (final name in ['AlarmKitMetadata.swift', 'AlarmLiveActivity.swift']) {
    final destination = File('${target.path}/$name');
    if (destination.existsSync()) {
      stdout.writeln('Kept ${destination.path}.');
      continue;
    }
    File('${templates.path}$name').copySync(destination.path);
    stdout.writeln('Wrote ${destination.path}.');
  }
  stdout.writeln(
    'Add the files to the extension target in Xcode, then run '
    '`dart run alarm_kit:setup --doctor`.',
  );
  return 0;
}
