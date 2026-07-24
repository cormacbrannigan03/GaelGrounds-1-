import Foundation

struct County: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let province: Province
    let crestUrl: String?
    let primaryColour: String?
    let secondaryColour: String?
    let createdAt: Date?
}

struct CountyTeam: Codable, Identifiable, Hashable {
    let id: UUID
    let countyId: UUID
    let sportCode: SportCode
    let foundedYear: Int?
    let history: String?
    let currentManager: String?
    let createdAt: Date?
}
