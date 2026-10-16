import 'package:alarm_kit/alarm_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('answers whether AlarmKit exists', (tester) async {
    final supported = await AlarmKit.instance.isSupported();
    if (!supported) return;
    expect(await AlarmKit.instance.alarms(), isA<List<Alarm>>());
  });
}
