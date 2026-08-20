import Foundation

struct UserProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String?
    var avatarUrl: String?
    var supportedCountyId: UUID?
    var isPremium: Bool = false
    var premiumExpiresAt: Date?
    var bestMatchId: UUID?
    // Explicit, opt-in consent to appear on the public Leaderboard (name +
    // stats visible to every other signed-in user) -- defaults to false on
    // every row, including existing premium users, per App Store guideline
    // 5.1.2: premium status alone must never be treated as consent to
    // publish someone's data. See LeaderboardView.swift's entries filter,
    // which requires both isPremium and this before including someone.
    var leaderboardOptIn: Bool = false
    let createdAt: Date?
}

struct UserProfilePremiumUpdate: Encodable {
    let isPremium: Bool
    let premiumExpiresAt: Date?
}

struct UserProfileUpdate: Encodable {
    let displayName: String
}

struct UserProfileAvatarUpdate: Encodable {
    let avatarUrl: String
}

struct UserProfileBestMatchUpdate: Encodable {
    let bestMatchId: UUID?
}

struct UserProfileLeaderboardOptInUpdate: Encodable {
    let leaderboardOptIn: Bool
}

struct SupportedCountyUpdate: Encodable {
    let supportedCountyId: UUID
}

struct UserVisit: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let groundId: UUID
    let visitedAt: Date
    let notes: String?
    let photoUrls: [String]
    let createdAt: Date?
}

struct UserVisitInsert: Encodable {
    let groundId: UUID
    let userId: UUID
    let notes: String?
    let photoUrls: [String]?

    init(groundId: UUID, userId: UUID, notes: String?, photoUrls: [String]? = nil) {
        self.groundId = groundId
        self.userId = userId
        self.notes = notes
        self.photoUrls = photoUrls
    }
}

struct UserVisitPhotoUpdate: Encodable {
    let photoUrls: [String]
}

struct UserMatchAttendance: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let matchId: UUID
    let notes: String?
    let photoUrls: [String]
    let createdAt: Date?
}

struct UserMatchAttendanceInsert: Encodable {
    let matchId: UUID
    let userId: UUID
}

struct AchievementDefinition: Codable, Identifiable, Hashable {
    struct RuleParams: Codable, Hashable {
        let count: Int?
        let countyId: UUID?
        let sportCode: SportCode?
        let province: Province?
    }

    let id: UUID
    let code: String
    let title: String
    let description: String
    let icon: String?
    let ruleType: String
    let ruleParams: RuleParams
    let createdAt: Date?
}

struct HomeAchievementKey: Hashable {
    let countyId: UUID
    let sportCode: SportCode
}

struct AchievementUnlock: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let icon: String?
    let tier: AchievementTier?
}

enum AchievementTier: String, Hashable, CaseIterable {
    case standard
    case bronze
    case silver
    case gold

    static func forHomeMatchCount(_ count: Int) -> AchievementTier {
        if count >= 50 { return .gold }
        if count >= 25 { return .silver }
        if count >= 10 { return .bronze }
        return .standard
    }

    var label: String {
        switch self {
        case .standard: return ""
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        }
    }
}

struct AchievementProgress: Hashable {
    let title: String
    let message: String
    let icon: String?
    let tier: AchievementTier
    let homeGameCount: Int
}

struct AchievementEvaluation: Hashable {
    let unlocks: [AchievementUnlock]
    let progress: AchievementProgress?
}

struct UserAchievement: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let achievementId: UUID
    let unlockedAt: Date
    var pinned: Bool = false
}

struct UserAchievementInsert: Encodable {
    let achievementId: UUID
    let userId: UUID
}

struct UserAchievementPinnedUpdate: Encodable {
    let pinned: Bool
}

struct Friendship: Codable, Identifiable {
    let id: UUID
    let requesterId: UUID
    let addresseeId: UUID
    let status: String
    let createdAt: Date?
}

struct FriendshipInsert: Encodable {
    let requesterId: UUID
    let addresseeId: UUID
}

struct FriendshipStatusUpdate: Encodable {
    let status: String
}

struct DevicePushTokenUpsert: Encodable {
    let userId: UUID
    let token: String
    let updatedAt: Date
}

struct MatchReport: Codable, Identifiable {
    let id: UUID
    let matchId: UUID
    let userId: UUID
    let issueTypes: [String]
    let details: String?
    let status: String
    let createdAt: Date?
}

struct MatchReportInsert: Encodable {
    let matchId: UUID
    let userId: UUID
    let issueTypes: [String]
    let details: String?
}
