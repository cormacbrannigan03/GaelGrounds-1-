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
    case camogie = "camogie"
    case ladiesFootball = "ladies_football"

    var label: String {
        switch self {
        case .gaelicFootball: return "Gaelic Football"
        case .hurling: return "Hurling"
        case .camogie: return "Camogie"
        case .ladiesFootball: return "Ladies' Football"
        }
    }

    var icon: String {
        switch self {
        case .gaelicFootball: return "🏐"
        case .hurling: return "🏑"
        case .camogie: return "🏑"
        case .ladiesFootball: return "🏐"
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
