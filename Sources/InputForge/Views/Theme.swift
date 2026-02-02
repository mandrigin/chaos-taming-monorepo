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

// MARK: - Shared Color Palette

/// Centralized color constants for the cyberdeck aesthetic.
enum ForgeColors {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let surfaceHover = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let border = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let borderSubtle = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let separator = Color(red: 0.3, green: 0.3, blue: 0.3)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.7)
    static let textTertiary = Color(red: 0.45, green: 0.45, blue: 0.45)
    static let textMuted = Color(red: 0.35, green: 0.35, blue: 0.35)
    static let textDim = Color(red: 0.3, green: 0.3, blue: 0.3)
    static let error = Color(red: 1.0, green: 0.3, blue: 0.25)
    static let errorDim = Color(red: 0.4, green: 0.12, blue: 0.1)
    static let success = Color(red: 0.2, green: 0.85, blue: 0.4)
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
