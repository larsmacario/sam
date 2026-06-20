import SwiftUI

/// Dialog zum Starten eines Meetings: Zustimmungshinweis + optionaler Name.
struct MeetingStartSheetView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var title = ""
    @State private var acknowledged: Bool
    @FocusState private var nameFieldFocused: Bool

    let onStart: (String?) -> Void
    let onCancel: () -> Void

    init(
        onStart: @escaping (String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onCancel = onCancel
        _acknowledged = State(initialValue: SettingsStore.shared.hasAcknowledgedMeetingRecordingNotice)
    }

    private var requiresAcknowledgment: Bool {
        !settings.hasAcknowledgedMeetingRecordingNotice
    }

    private var canStart: Bool {
        !requiresAcknowledgment || acknowledged
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SamDesign.meetingColor)
                Text("Meeting starten")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)

            VStack(alignment: .leading, spacing: 14) {
                Text("Gesprächsaufnahmen können zustimmungspflichtig sein. Informiere alle Teilnehmer, bevor du aufnimmst.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if requiresAcknowledgment {
                    Toggle("Verstanden", isOn: $acknowledged)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Meeting-Name (optional)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("z. B. Team-Weekly", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .focused($nameFieldFocused)
                }
            }
            .padding(16)

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)

            HStack {
                Button("Abbrechen", action: onCancel)
                    .buttonStyle(GlassButtonStyle())
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Starten") {
                    if requiresAcknowledgment {
                        settings.hasAcknowledgedMeetingRecordingNotice = true
                    }
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    onStart(trimmed.isEmpty ? nil : trimmed)
                }
                .buttonStyle(GlassButtonStyle())
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(SamDesign.meetingColor)
                .disabled(!canStart)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 400)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            DispatchQueue.main.async {
                nameFieldFocused = true
            }
        }
    }
}
