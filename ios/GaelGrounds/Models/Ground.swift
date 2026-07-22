import Foundation

struct Ground: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let countyId: UUID
    let latitude: Double
    let longitude: Double
    let capacity: Int?
    let photoUrl: String?
    let createdAt: Date?
}
