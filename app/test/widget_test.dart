import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:app/main.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/banking_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BankingApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => BankingProvider()),
        ],
        child: const BankingApp(),
      ),
    );

    expect(find.byType(BankingApp), findsOneWidget);
  });
}
