import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  NotificationService(this.flutterLocalNotificationsPlugin);

  void listenForNewRegistrations() {
    FirebaseFirestore.instance.collection('courses').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var courseData = change.doc.data();
          if (courseData != null) {
            var newUser = detectNewUser(courseData);
            if (newUser != null) {
              sendNotification(change.doc.id);
            }
          }
        }
      }
    });
  }

  dynamic detectNewUser(Map<String, dynamic> courseData) {
    // Example logic to detect a new user
    // Assume that courseData has a 'users' field which is a list of user IDs
    // You can compare this with previous state to find new users
    List<dynamic>? users = courseData['users'];
    if (users != null && users.isNotEmpty) {
      // Placeholder logic; replace with actual detection logic
      return users.last; // Assuming the last user in the list is new
    }
    return null;
  }

  Future<void> sendNotification(String courseId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'new_user_channel',
      'New User Channel',
      channelDescription: 'Notification channel for new user registrations',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique notification ID
        'New User Registered',
        'A new user has registered for course ID: $courseId',
        platformChannelSpecifics,
        payload: courseId,
      );
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
