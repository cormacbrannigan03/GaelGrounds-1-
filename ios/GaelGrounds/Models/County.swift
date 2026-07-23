import Foundation

struct County: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let province: Province
    let crestUrl: String?
    let primaryColour: String?
    let secondaryColour: String?
    let createdAt: Date?

    private enum CodingKeys: CodingKey {
        case id, name, province, crestUrl, primaryColour, secondaryColour, createdAt
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        province = try c.decode(Province.self, forKey: .province)
        crestUrl = try c.decodeIfPresent(String.self, forKey: .crestUrl)
        primaryColour = try c.decodeIfPresent(String.self, forKey: .primaryColour)
        secondaryColour = try c.decodeIfPresent(String.self, forKey: .secondaryColour)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct CountyTeam: Codable, Identifiable, Hashable {
    let id: UUID
    let countyId: UUID
    let sportCode: SportCode
    let foundedYear: Int?
    let history: String?
    let currentManager: String?
    let createdAt: Date?

    private enum CodingKeys: CodingKey {
        case id, countyId, sportCode, foundedYear, history, currentManager, createdAt
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        countyId = try c.decode(UUID.self, forKey: .countyId)
        sportCode = try c.decode(SportCode.self, forKey: .sportCode)
        foundedYear = try c.decodeIfPresent(Int.self, forKey: .foundedYear)
        history = try c.decodeIfPresent(String.self, forKey: .history)
        currentManager = try c.decodeIfPresent(String.self, forKey: .currentManager)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}
