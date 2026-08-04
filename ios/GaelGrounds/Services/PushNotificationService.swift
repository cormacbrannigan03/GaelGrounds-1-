import Foundation
import Supabase
import UIKit
import UserNotifications

/// Bridges UIKit's APNs registration (which needs a UIApplicationDelegate,
/// see AppDelegate.swift) into the app's SwiftUI/ObservableObject world.
/// Exposed as a singleton deliberately: `@UIApplicationDelegateAdaptor`
/// constructs AppDelegate independently of the app's @StateObjects, so
/// there's no reliable injection point to hand it a reference otherwise.
///
/// Sends exactly two kinds of push, both decided server-side (see the
/// trigger functions in supabase/migrations/..._notify_on_friend_request.sql
/// and ..._notify_on_live_checkin.sql) -- this service only ever registers
/// the device and uploads its token; it has no say in what gets sent.
@MainActor
final class PushNotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    /// Kept current by the app root whenever the signed-in user changes,
    /// same pattern as `PremiumStore.userId`. Uploads the pending device
    /// token (if any) the moment both it and a signed-in user are known.
    var userId: UUID? {
        didSet {
            guard userId != oldValue else { return }
            uploadTokenIfReady()
        }
    }

    private var pendingToken: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Call once someone's actually signed in -- no point prompting for
    /// permission, or registering a token, before there's a user to
    /// associate it with.
    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didReceiveDeviceToken(_ data: Data) {
        pendingToken = data.map { String(format: "%02x", $0) }.joined()
        uploadTokenIfReady()
    }

    private func uploadTokenIfReady() {
        guard let token = pendingToken, let userId else { return }
        Task {
            do {
                try await Supa.client
                    .from("device_push_tokens")
                    .upsert(
                        DevicePushTokenUpsert(userId: userId, token: token, updatedAt: Date()),
                        onConflict: "token"
                    )
                    .execute()
            } catch {
                print("Failed to upload push token: \(error)")
            }
        }
    }

    /// Show alerts even while the app is already open -- without this,
    /// notifications only appear when the app is backgrounded.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}
