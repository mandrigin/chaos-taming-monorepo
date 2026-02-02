import SwiftUI

// MARK: - Theme

/// Context-aware theme for the Cyberdeck / Teenage Engineering aesthetic.
/// Work context uses orange/amber; Personal uses teal/cyan.
struct ForgeTheme: Sendable {
    let accent: Color
    let accentDim: Color

    static let work = ForgeTheme(
        accent: Color(hue: 0.08, saturation: 1.0, brightness: 1.0),
        accentDim: Color(hue: 0.08, saturation: 0.6, brightness: 0.35)
    )

    static let personal = ForgeTheme(
        accent: Color(hue: 0.5, saturation: 0.85, brightness: 0.85),
        accentDim: Color(hue: 0.5, saturation: 0.5, brightness: 0.3)
    )

    /// Neutral gray theme shown before context selection.
    static let neutral = ForgeTheme(
        accent: Color(red: 0.5, green: 0.5, blue: 0.5),
        accentDim: Color(red: 0.18, green: 0.18, blue: 0.18)
    )

    static func forContext(_ context: ProjectContext) -> ForgeTheme {
        switch context {
        case .work: return .work
        case .personal: return .personal
        }
    }
}

// MARK: - Environment

private struct ForgeThemeKey: EnvironmentKey {
    static let defaultValue = ForgeTheme.neutral
}

extension EnvironmentValues {
    var forgeTheme: ForgeTheme {
        get { self[ForgeThemeKey.self] }
        set { self[ForgeThemeKey.self] = newValue }
    }
}

// MARK: - Cyberdeck Overlays

/// Subtle horizontal scan-line overlay.
struct ScanLineOverlay: View {
    var spacing: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black)
                )
                y += spacing
            }
        }
        .opacity(0.035)
        .allowsHitTesting(false)
    }
}

/// Static film-grain noise texture.
struct GrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 3
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let hash = abs(Int(x) &* 2654435761 &+ Int(y) &* 2246822519)
                    let brightness = Double(hash % 256) / 255.0
                    context.fill(
                        Path(CGRect(x: x, y: y, width: step, height: step)),
                        with: .color(.white.opacity(brightness))
                    )
                    y += step
                }
                x += step
            }
        }
        .opacity(0.02)
        .allowsHitTesting(false)
    }
}
