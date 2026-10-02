#if canImport(UIKit)
import UIKit
import GoogleMobileAds

/// SwiftUI apps still need a UIApplicationDelegate for APNs device-token
/// registration -- there's no SwiftUI-native equivalent. Wired in via
/// `@UIApplicationDelegateAdaptor(AppDelegate.self)` in GaelGroundsApp.swift.
/// Everything it does is forward straight to PushNotificationService.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MobileAds.shared.start(completionHandler: nil)
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.didReceiveDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Push notification registration failed: \(error)")
    }
}
#endif
