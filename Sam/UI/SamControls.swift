import SwiftUI

/// Großbuchstaben-Sektionslabel mit optionalem Icon.
struct SecLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }
}

/// Gruppiertes Control-Center-Modul.
struct SamGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .glassCard()
            .padding(.bottom, 16)
    }
}

/// Eine Zeile innerhalb einer Gruppe, mit Haarlinien-Trenner unten.
struct SamRow<Content: View>: View {
    var last = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) { content }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            if !last {
                Rectangle()
                    .fill(Color.white.opacity(SamDesign.hairlineOpacity))
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }
}

/// Titel (+ optionaler Untertitel) einer Zeile.
struct RowLabel: View {
    let title: String
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            if let sub {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }
}

/// Monospace-Tastenkappe (fn, Cmd, …).
struct Keycap: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(SamDesign.glassFill(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.35), lineWidth: 0.5)
            )
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case hauptseite, einstellungen
    var id: String { rawValue }
}
