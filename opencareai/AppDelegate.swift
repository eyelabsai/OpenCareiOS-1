// AppDelegate.swift
import Firebase
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
              if granted {
                  print("Notification permission granted.")
              } else if let error = error {
                  print("Notification permission error: \(error.localizedDescription)")
              }
          }
    return true
  }
}
