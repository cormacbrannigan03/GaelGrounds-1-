import SwiftUI

/// A small two-stripe banner representing a county's traditional GAA colours.
/// Pass any height; width scales proportionally (flag ~2:3 ratio).
struct CountyBanner: View {
    let countyName: String
    var height: CGFloat = 18

    private var width: CGFloat { height * 0.67 }

    var body: some View {
        let (primary, secondary) = CountyColours.colours(for: countyName)
        HStack(spacing: 0) {
            Rectangle().fill(primary)
            Rectangle().fill(secondary)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(.primary.opacity(0.2), lineWidth: 0.5))
    }
}

enum CountyColours {
    static func colours(for name: String) -> (Color, Color) {
        lookup[name] ?? (Color.gray.opacity(0.4), Color.gray.opacity(0.2))
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    private static let gold    = rgb(240, 195,   0)
    private static let green   = rgb(  0, 107,  63)
    private static let red     = rgb(204,  16,  46)
    private static let blue    = rgb(  0,  61, 165)
    private static let skyBlue = rgb(  0, 138, 204)
    private static let navy    = rgb(  0,  33,  96)
    private static let black   = rgb( 20,  20,  20)
    private static let amber   = rgb(255, 191,   0)
    private static let maroon  = rgb(128,   0,   0)
    private static let orange  = rgb(255, 106,   0)
    private static let saffron = rgb(255, 178,   0)
    private static let purple  = rgb( 90,  30, 137)
    private static let primrose = rgb(255, 240,   0)

    // Traditional GAA county colours — primary stripe | secondary stripe
    private static let lookup: [String: (Color, Color)] = [
        // Ulster
        "Antrim":       (saffron,  .white),
        "Armagh":       (orange,   .white),
        "Cavan":        (blue,     .white),
        "Derry":        (red,      .white),
        "Londonderry":  (red,      .white),
        "Donegal":      (gold,     green),
        "Down":         (red,      black),
        "Fermanagh":    (green,    .white),
        "Monaghan":     (blue,     .white),
        "Tyrone":       (red,      .white),

        // Munster
        "Clare":        (gold,     blue),
        "Cork":         (red,      .white),
        "Kerry":        (green,    gold),
        "Limerick":     (green,    .white),
        "Tipperary":    (blue,     gold),
        "Waterford":    (.white,   blue),

        // Leinster
        "Carlow":       (red,      green),
        "Dublin":       (skyBlue,  navy),
        "Kildare":      (.white,   red),
        "Kilkenny":     (black,    amber),
        "Laois":        (blue,     .white),
        "Longford":     (blue,     gold),
        "Louth":        (red,      .white),
        "Meath":        (green,    gold),
        "Offaly":       (green,    gold),
        "Westmeath":    (maroon,   .white),
        "Wexford":      (purple,   gold),
        "Wicklow":      (blue,     gold),

        // Connacht
        "Galway":       (maroon,   .white),
        "Leitrim":      (green,    gold),
        "Mayo":         (green,    red),
        "Roscommon":    (primrose, blue),
        "Sligo":        (black,    .white),
    ]
}
