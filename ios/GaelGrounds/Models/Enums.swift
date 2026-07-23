import Foundation

enum Province: String, Codable, CaseIterable {
    case connacht = "Connacht"
    case leinster = "Leinster"
    case munster = "Munster"
    case ulster = "Ulster"
}

enum SportCode: String, Codable, CaseIterable {
    case gaelicFootball = "gaelic_football"
    case hurling = "hurling"

    var label: String {
        switch self {
        case .gaelicFootball: return "Gaelic Football"
        case .hurling: return "Hurling"
        }
    }

    var icon: String {
        switch self {
        case .gaelicFootball: return "🏐"
        case .hurling: return "🏑"
        }
    }
}

enum MatchType: String, Codable {
    case county
    case club
}

enum HonourType: String, Codable {
    case allIreland = "all_ireland"
    case provincial
    case league
    case countyChampionship = "county_championship"
    case clubAllIreland = "club_all_ireland"
}

enum TeamType: String, Codable {
    case county
    case club
}
