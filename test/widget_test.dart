import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:Etqan/main.dart'; // Import your main file where MyApp is defined
import 'package:Etqan/notification_service.dart'; // Import your notification service
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import the notifications plugin

void main() {
  setUpAll(() async {
    // Initialize Firebase for testing
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
  });

  testWidgets('HomePage displays correctly', (WidgetTester tester) async {
    // Initialize FlutterLocalNotificationsPlugin
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize NotificationService with the required plugin
    final notificationService = NotificationService(flutterLocalNotificationsPlugin);

    // Build the app with a properly initialized MyApp
    await tester.pumpWidget(
      MyApp(
        notificationService: notificationService, // Pass the notification service
        homePage: MyHomePage(
          notificationService: notificationService, // Pass the notification service
        ),
      ),
    );

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
