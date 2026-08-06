import SwiftUI
import AppKit

/// NSVisualEffectView, der keine Maus-Events abfängt (sonst blockiert er Textfelder in SwiftUI).
private final class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Echtes macOS-Vibrancy (Frosted Glass) als SwiftUI-Hintergrund.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassthroughVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.isEmphasized = true
    }
}

/// Design-Tokens — Apple Control Center / HUD Glassmorphism.
enum SamDesign {
    static let accent = Color(hex: 0x0A84FF)
    static let dictateColor = Color(hex: 0x0A84FF)
    static let chatColor = Color(hex: 0xBF5AF2)
    static let dialogColor = Color(hex: 0x64D2FF)
    static let meetingColor = Color(hex: 0xFF453A)
    static let success = Color(hex: 0x30D158)
    static let warning = Color(hex: 0xFF9F0A)

    // Panel
    static let panelWidth: CGFloat = 440
    static let panelHeight: CGFloat = 620
    static let panelCornerRadius: CGFloat = 18
    static let panelGapBelowIcon: CGFloat = 4
    static let panelArrowWidth: CGFloat = 18
    static let panelArrowHeight: CGFloat = 10
    static let panelShadowOpacity: Double = 0.28
    static let panelShadowRadius: CGFloat = 32
    static let panelShadowY: CGFloat = 14

    // Chat-Sidepanel (rechts, 90 % Bildschirmhöhe)
    static let chatPanelWidth: CGFloat = 420
    static let chatPanelHeightRatio: CGFloat = 0.9
    static let chatPanelScreenInset: CGFloat = 12
    static let chatPanelCornerRadius: CGFloat = 18

    static let chatPanelShape = UnevenRoundedRectangle(
        topLeadingRadius: chatPanelCornerRadius,
        bottomLeadingRadius: chatPanelCornerRadius,
        bottomTrailingRadius: 0,
        topTrailingRadius: 0,
        style: .continuous
    )

    // Minimierter Chat-Float-Button
    static let chatFloatButtonSize: CGFloat = 52
    // Cards (Control-Center-Module)
    static let cardCornerRadius: CGFloat = 14
    static let hairlineOpacity: Double = 0.06

    /// Leichte Glas-Füllung je Erscheinungsbild (kein Material-Stacking).
    static func glassFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.62)
    }

    static func glassFillActive(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.78)
    }

    static var totalPanelHeight: CGFloat { panelHeight + panelArrowHeight }
}

/// Popover-Form mit Pfeil oben mittig (zeigt zum Menüleisten-Icon).
struct PopoverBubbleShape: Shape {
    var cornerRadius: CGFloat = SamDesign.panelCornerRadius
    var arrowWidth: CGFloat = SamDesign.panelArrowWidth
    var arrowHeight: CGFloat = SamDesign.panelArrowHeight

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.width / 2, max(0, (rect.height - arrowHeight) / 2))
        let aw = arrowWidth / 2
        let bodyTop = rect.minY + arrowHeight
        let midX = rect.midX

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - r),
            radius: r
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bodyTop + r))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: bodyTop),
            tangent2End: CGPoint(x: rect.maxX - r, y: bodyTop),
            radius: r
        )
        path.addLine(to: CGPoint(x: midX + aw, y: bodyTop))
        path.addLine(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX - aw, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.minX + r, y: bodyTop))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: bodyTop),
            tangent2End: CGPoint(x: rect.minX, y: bodyTop + r),
            radius: r
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX + r, y: rect.maxY),
            radius: r
        )
        path.closeSubpath()
        return path
    }
}

/// Innere Gruppe — ein durchscheinendes Modul, kein verschachteltes Material.
struct GlassPanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    VisualEffectBackground(material: .hudWindow, blending: .behindWindow)
                    Color.black.opacity(colorScheme == .dark ? 0.08 : 0.02)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: SamDesign.panelCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SamDesign.panelCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.04),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(SamDesign.panelShadowOpacity),
                radius: SamDesign.panelShadowRadius,
                y: SamDesign.panelShadowY
            )
    }
}

/// Innere Gruppe — ein durchscheinendes Modul, kein verschachteltes Material.
struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: SamDesign.cardCornerRadius, style: .continuous)
                    .fill(SamDesign.glassFill(for: colorScheme))
            }
            .overlay {
                RoundedRectangle(cornerRadius: SamDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.18 : 0.55),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .allowsHitTesting(false)
            }
    }
}

/// Dezenter Hover für klickbare Plain-Buttons (Footer, Links).
struct GlassButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(isHovered || configuration.isPressed ? 0.08 : 0))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.18), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

/// Eingabefeld-Inset im Control-Center-Stil.
struct GlassInsetField: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SamDesign.glassFillActive(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 0.5)
                    )
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func glassPanel() -> some View {
        modifier(GlassPanel())
    }

    func glassCard() -> some View {
        modifier(GlassCard())
    }

    func glassInsetField() -> some View {
        modifier(GlassInsetField())
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension InputMode {
    var accentColor: Color {
        switch self {
        case .dictation: return SamDesign.dictateColor
        case .ai: return SamDesign.chatColor
        }
    }

    var pillSymbol: String {
        switch self {
        case .dictation: return "mic.fill"
        case .ai: return "sparkles"
        }
    }

    var pillHint: String {
        switch self {
        case .dictation: return "Sprich jetzt…"
        case .ai: return "Sprich oder chatte…"
        }
    }
}
