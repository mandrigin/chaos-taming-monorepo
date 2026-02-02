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

/// Animated scan-line sweep for loading/processing states.
struct AnimatedScanLineOverlay: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 60)
                .offset(y: offset)
                .onAppear {
                    withAnimation(
                        .linear(duration: 2.0)
                        .repeatForever(autoreverses: false)
                    ) {
                        offset = geo.size.height
                    }
                }
        }
        .allowsHitTesting(false)
        .clipped()
    }
}

// MARK: - Forge Button Style

/// Chunky, tactile button style matching the cyberdeck aesthetic.
/// Thick borders, monospaced text, visible press state.
struct ForgeButtonStyle: ButtonStyle {
    @Environment(\.forgeTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var variant: Variant = .primary
    var compact: Bool = false

    enum Variant {
        case primary
        case secondary
        case destructive
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let accentColor: Color = switch variant {
        case .primary: theme.accent
        case .secondary: ForgeColors.textSecondary
        case .destructive: ForgeColors.error
        }
        let dimColor: Color = switch variant {
        case .primary: theme.accentDim
        case .secondary: ForgeColors.surface
        case .destructive: ForgeColors.errorDim
        }

        configuration.label
            .font(.system(compact ? .caption : .body, design: .monospaced, weight: .bold))
            .tracking(compact ? 1 : 2)
            .foregroundStyle(isEnabled ? accentColor : ForgeColors.textTertiary)
            .padding(.horizontal, compact ? 10 : 16)
            .padding(.vertical, compact ? 6 : 10)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(pressed ? dimColor.opacity(0.5) : dimColor.opacity(0.2))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        isEnabled ? accentColor.opacity(pressed ? 1.0 : 0.6) : ForgeColors.border,
                        lineWidth: pressed ? 3 : 2
                    )
            }
            .offset(y: pressed ? 1 : 0)
            .animation(.easeInOut(duration: 0.08), value: pressed)
    }
}

// MARK: - Forge Section Header

/// Styled section header matching the cyberdeck aesthetic.
struct ForgeSectionHeader: View {
    let title: String
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(theme.accent)
    }
}

// MARK: - Error Banner

/// A slide-down error banner matching the cyberdeck aesthetic.
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        if isVisible {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(ForgeColors.error)

                Text(message)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(ForgeColors.error)
                    .lineLimit(2)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(ForgeColors.error.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(ForgeColors.errorDim.opacity(0.6))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(ForgeColors.error.opacity(0.4), lineWidth: 2)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .padding(.horizontal)
        }
    }

    init(message: String, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onDismiss = onDismiss
        self._isVisible = State(initialValue: true)
    }
}

// MARK: - Forge Badge

/// Small label badge in the cyberdeck style.
struct ForgeBadge: View {
    let text: String
    var style: Style = .accent

    @Environment(\.forgeTheme) private var theme

    enum Style {
        case accent
        case muted
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: style == .accent ? .bold : .medium, design: .monospaced))
            .tracking(1)
            .foregroundStyle(style == .accent ? theme.accent : ForgeColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(style == .accent ? theme.accentDim.opacity(0.3) : ForgeColors.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        style == .accent ? theme.accent.opacity(0.5) : ForgeColors.border,
                        lineWidth: 1
                    )
            }
    }
}

// MARK: - Glitch Transition Modifier

/// Applies a brief glitch/static effect during view transitions.
struct GlitchModifier: ViewModifier {
    let isActive: Bool

    @State private var glitchOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: isActive ? glitchOffset : 0)
            .overlay {
                if isActive {
                    ScanLineOverlay(spacing: 2)
                        .opacity(0.15)
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    // Quick random offsets to simulate glitch
                    withAnimation(.easeInOut(duration: 0.05)) {
                        glitchOffset = CGFloat.random(in: -3...3)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.05)) {
                            glitchOffset = CGFloat.random(in: -2...2)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.05)) {
                            glitchOffset = 0
                        }
                    }
                }
            }
    }
}

extension View {
    func forgeGlitch(_ isActive: Bool) -> some View {
        modifier(GlitchModifier(isActive: isActive))
    }
}
