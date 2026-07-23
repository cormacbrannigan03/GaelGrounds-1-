import SwiftUI

/// Matches the web app's green & gold palette (src/index.css).
extension Color {
    static let brandGreen = Color(red: 0x0B / 255, green: 0x3D / 255, blue: 0x2E / 255)
    static let brandGreenLight = Color(red: 0x14 / 255, green: 0x60 / 255, blue: 0x3F / 255)
    static let brandGold = Color(red: 0xD9 / 255, green: 0xA4 / 255, blue: 0x41 / 255)
    static let brandLive = Color(red: 0xD6 / 255, green: 0x45 / 255, blue: 0x45 / 255)
}

extension ShapeStyle where Self == Color {
    static var brandGreen: Color { .init(red: 0x0B / 255, green: 0x3D / 255, blue: 0x2E / 255) }
    static var brandGreenLight: Color { .init(red: 0x14 / 255, green: 0x60 / 255, blue: 0x3F / 255) }
    static var brandGold: Color { .init(red: 0xD9 / 255, green: 0xA4 / 255, blue: 0x41 / 255) }
    static var brandLive: Color { .init(red: 0xD6 / 255, green: 0x45 / 255, blue: 0x45 / 255) }
}

extension View {
    func gaelGroundsBackground() -> some View {
        self.background(
            LinearGradient(
                stops: [
                    .init(color: .brandGreen, location: 0),
                    .init(color: Color(.systemBackground), location: 0.28),
                    .init(color: Color(.systemBackground), location: 0.72),
                    .init(color: .brandGreen, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
