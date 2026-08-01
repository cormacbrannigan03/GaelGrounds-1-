import SwiftUI
import UIKit

/// Matches the web app's green & gold palette (src/index.css).
extension Color {
    static let brandGreen = Color(red: 0x0B / 255, green: 0x3D / 255, blue: 0x2E / 255)
    static let brandGreenLight = Color(red: 0x14 / 255, green: 0x60 / 255, blue: 0x3F / 255)
    static let brandGold = Color(red: 0xD9 / 255, green: 0xA4 / 255, blue: 0x41 / 255)
    static let brandLive = Color(red: 0xD6 / 255, green: 0x45 / 255, blue: 0x45 / 255)
    static let brandCanvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.035, green: 0.075, blue: 0.060, alpha: 1)
            : UIColor(red: 0.965, green: 0.972, blue: 0.952, alpha: 1)
    })
    static let brandSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.125, blue: 0.105, alpha: 1)
            : UIColor(red: 0.985, green: 0.990, blue: 0.975, alpha: 1)
    })
    static let brandSurfaceRaised = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.095, green: 0.155, blue: 0.130, alpha: 1)
            : UIColor(red: 1.000, green: 1.000, blue: 0.995, alpha: 1)
    })
    static let brandBorder = Color.brandGreenLight.opacity(0.16)
}

extension ShapeStyle where Self == Color {
    static var brandGreen: Color { .init(red: 0x0B / 255, green: 0x3D / 255, blue: 0x2E / 255) }
    static var brandGreenLight: Color { .init(red: 0x14 / 255, green: 0x60 / 255, blue: 0x3F / 255) }
    static var brandGold: Color { .init(red: 0xD9 / 255, green: 0xA4 / 255, blue: 0x41 / 255) }
    static var brandLive: Color { .init(red: 0xD6 / 255, green: 0x45 / 255, blue: 0x45 / 255) }
}

extension AchievementTier {
    var tint: Color {
        switch self {
        case .standard: return .secondary
        case .bronze: return Color(red: 0.72, green: 0.45, blue: 0.20)
        case .silver: return Color(red: 0.55, green: 0.60, blue: 0.66)
        case .gold: return .brandGold
        }
    }
}

extension View {
    func gaelGroundsBackground() -> some View {
        self.background(
            ZStack {
                Color.brandCanvas
                LinearGradient(
                    stops: [
                        .init(color: .brandGreen.opacity(0.24), location: 0),
                        .init(color: .clear, location: 0.34),
                        .init(color: .clear, location: 0.72),
                        .init(color: .brandGold.opacity(0.13), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        )
    }

    @MainActor
    func countyBackground(_ countyName: String?) -> some View {
        let colours = countyName.map(CountyPalette.colours(for:))
        let primary = colours?.0 ?? Color.brandGreen
        let secondary = colours?.1 ?? Color.brandGold
        return background(
            ZStack {
                Color.brandCanvas
                LinearGradient(
                    stops: [
                        .init(color: primary.opacity(0.94), location: 0),
                        .init(color: primary.opacity(0.78), location: 0.28),
                        .init(color: secondary.opacity(0.72), location: 0.72),
                        .init(color: secondary.opacity(0.92), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear, Color.black.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        )
    }

    func gaelCard(cornerRadius: CGFloat = 14) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.brandSurfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.brandBorder, lineWidth: 1)
                }
                .shadow(color: Color.brandGreen.opacity(0.07), radius: 8, y: 3)
        }
    }

    func gaelInsetCard(cornerRadius: CGFloat = 12) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.brandGreenLight.opacity(0.065))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.brandBorder.opacity(0.8), lineWidth: 1)
                }
        }
    }
}
