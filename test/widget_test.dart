import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders onboarding screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ScreenTimeControllerApp());
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('Screen Time').evaluate().isNotEmpty) break;
    }

    expect(find.textContaining('Screen Time'), findsWidgets);
  });
}
