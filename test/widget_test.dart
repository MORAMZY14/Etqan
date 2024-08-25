import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:Etqan/main.dart';

void main() {
  setUpAll(() async {
    // Initialize Firebase for testing
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
  });

  testWidgets('HomePage displays correctly', (WidgetTester tester) async {
    // Build the app with a properly initialized MyApp
    await tester.pumpWidget(const MyApp(homePage: MyHomePage()));

    // Ensure any async operations (like Firebase initialization) are completed.
    await tester.pumpAndSettle();

    // Verify that the text "Hello, Guest" and the login icon are displayed.
    expect(find.text('Hello, Guest'), findsOneWidget);
    expect(find.byIcon(Icons.login), findsOneWidget);

    // Simulate a tap on the login icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.login));
    await tester.pump(); // Rebuild the widget after the tap.

    // Add additional verifications here based on what should happen after the tap.
  });
}
