import Foundation

enum Formatting {
    static let matchDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM yyyy"
        f.locale = Locale(identifier: "en_IE")
        f.timeZone = TimeZone(identifier: "UTC")
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

    /// Renders a fixture's date + optional throw-in time as one line, e.g.
    /// "Sun 26 Jul 2026, 3:30pm" or "Sun 26 Jul 2026" when the throw-in time
    /// isn't confirmed yet — never fabricates a time that wasn't given.
    static func fixtureDateTime(date: Date?, throwInTime: String?) -> String {
        guard let date else { return "Date to be confirmed" }
        var result = matchDate(date)
        if let time = formattedThrowInTime(throwInTime) {
            result += ", \(time)"
        }
        return result
    }

    /// 'HH:MM:SS' (as Postgres `time` round-trips) → "3:30pm".
    static func formattedThrowInTime(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let parts = raw.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        let period = hour < 12 ? "am" : "pm"
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return minute == 0 ? "\(hour12)\(period)" : String(format: "%d:%02d%@", hour12, minute, period)
    }
}
