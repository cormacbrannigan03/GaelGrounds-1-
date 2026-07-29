import SwiftUI

/// Matches the web app's green & gold palette (src/index.css).
extension Color {
    static let brandGreen = Color(red: 0x0B / 255, green: 0x3D / 255, blue: 0x2E / 255)
    static let brandGreenLight = Color(red: 0x14 / 255, green: 0x60 / 255, blue: 0x3F / 255)
    static let brandGold = Color(red: 0xD9 / 255, green: 0xA4 / 255, blue: 0x41 / 255)
    static let brandLive = Color(red: 0xD6 / 255, green: 0x45 / 255, blue: 0x45 / 255)

    /// Parses a "#RRGGBB" hex string (leading # optional) such as the ones
    /// stored in `counties.primary_colour`/`secondary_colour`. Returns nil
    /// for anything malformed rather than silently falling back to black.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
