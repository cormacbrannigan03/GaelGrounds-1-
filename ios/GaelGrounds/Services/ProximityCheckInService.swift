import Combine
import CoreLocation
import Foundation

struct NearbyMatchPrompt: Identifiable {
    let id: UUID
    let matchId: UUID
    let groundName: String
}

/// Watches for a simple case: the app comes to the foreground, the user is
/// signed in, and they happen to be within 2km of a ground hosting a match
/// today. When that happens, surfaces a one-tap "want to check in?" prompt
/// instead of making them find the match manually.
///
/// Never requests location permission on its own initiative beyond the
/// standard one-time system prompt (triggered the first time someone opens
/// the app signed in) -- if they decline, this simply stays silent from
/// then on. Exposed as a singleton for the same reason as
/// PushNotificationService: the app root wires `userId` into it once
/// someone's signed in.
@MainActor
final class ProximityCheckInService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = ProximityCheckInService()

    static let proximityThresholdMeters: CLLocationDistance = 2000

    var userId: UUID?

    @Published var nearbyPrompt: NearbyMatchPrompt?
    @Published var isCheckingIn = false

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    /// Matches already prompted for (accepted or dismissed) this app
    /// session, so a "Not Now" doesn't nag again every time the app is
    /// reopened while still in range.
    private var handledMatchIds: Set<UUID> = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func checkForNearbyMatchToday(userId: UUID, isPremium: Bool) async {
        guard nearbyPrompt == nil else { return }

        await requestAuthorizationIfNeeded()
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }

        guard let location = await requestOneShotLocation() else { return }

        do {
            let matches = try await MatchService.fetchTodaysMatches()
            guard !matches.isEmpty else { return }

            let groundIds = Array(Set(matches.compactMap(\.groundId)))
            async let groundsTask = MatchService.fetchGrounds(ids: groundIds)
            async let attendedTask = MatchService.attendedMatchIds(userId: userId, matchIds: matches.map(\.id))
            let (grounds, attendedMatchIds) = try await (groundsTask, attendedTask)
            let groundById = Dictionary(uniqueKeysWithValues: grounds.map { ($0.id, $0) })

            let nearest = matches
                .compactMap { match -> (match: Match, ground: Ground, distance: CLLocationDistance)? in
                    guard let groundId = match.groundId,
                          let ground = groundById[groundId],
                          !attendedMatchIds.contains(match.id),
                          !handledMatchIds.contains(match.id)
                    else { return nil }
                    let distance = location.distance(from: CLLocation(latitude: ground.latitude, longitude: ground.longitude))
                    guard distance <= Self.proximityThresholdMeters else { return nil }
                    return (match, ground, distance)
                }
                .min { $0.distance < $1.distance }

            guard let nearest else { return }
            guard await MatchService.canLogAnotherMatch(userId: userId, isPremium: isPremium) else { return }

            nearbyPrompt = NearbyMatchPrompt(id: nearest.match.id, matchId: nearest.match.id, groundName: nearest.ground.name)
        } catch {
            print("checkForNearbyMatchToday failed: \(error)")
        }
    }

    func confirmCheckIn() async {
        guard let prompt = nearbyPrompt, let userId else { return }
        nearbyPrompt = nil
        handledMatchIds.insert(prompt.matchId)

        isCheckingIn = true
        defer { isCheckingIn = false }
        do {
            _ = try await MatchService.checkIn(matchId: prompt.matchId, userId: userId)
        } catch {
            print("Proximity check-in failed: \(error)")
        }
    }

    func dismissPrompt() {
        if let prompt = nearbyPrompt {
            handledMatchIds.insert(prompt.matchId)
        }
        nearbyPrompt = nil
    }

    private func requestAuthorizationIfNeeded() async {
        guard manager.authorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestOneShotLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authContinuation?.resume()
            authContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.last)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}
