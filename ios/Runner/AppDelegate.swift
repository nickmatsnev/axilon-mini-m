import UIKit
import Flutter
import Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1) Configure Firebase
    FirebaseApp.configure()

    // 2) Set UNUserNotificationCenter delegate for foreground notifications
    UNUserNotificationCenter.current().delegate = self

    // 3) Register for remote notifications
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 4) This is called when APNs has generated a device token for you
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Pass it to Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken

    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
