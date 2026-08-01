import Foundation

struct County: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let province: Province
    let crestUrl: String?
    let primaryColour: String?
    let secondaryColour: String?
    let createdAt: Date?

    var colours: CountyColours? {
        guard let primaryColour, let secondaryColour else { return nil }
        return CountyColours(primary: primaryColour, secondary: secondaryColour)
    }
}

/// A county's two jersey colours, hex strings straight from the database
/// (e.g. "#00703C"). Used to wash match banners with each side's colours.
struct CountyColours: Hashable {
    let primary: String
    let secondary: String
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
