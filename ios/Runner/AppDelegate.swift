import Flutter
import UIKit
import Firebase
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("App is launching")

    FirebaseApp.configure()  // Initialize Firebase
    print("Firebase configured")

    // Request permission for notifications
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { granted, error in
        if let error = error {
          print("Error requesting notification authorization: \(error)")
        } else {
          print("Notification authorization granted: \(granted)")
        }
      })

    application.registerForRemoteNotifications()
    print("Registered for remote notifications")

    GeneratedPluginRegistrant.register(with: self)
    print("Plugins registered")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
