import Foundation

enum Formatting {
    static let matchDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM, HH:mm"
        f.locale = Locale(identifier: "en_IE")
        return f
    }()

    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_IE")
        return f
    }()

    static func matchDate(_ date: Date) -> String {
        matchDateFormatter.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }
}
