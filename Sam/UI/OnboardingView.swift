import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var appState = AppState.shared
    @Binding var isPresented: Bool
    var launchAtLoginService: LaunchAtLoginService

    @State private var step = 0

    private let steps: [(title: String, description: String, icon: String)] = [
        (
            "Willkommen bei SAM",
            "SAM startet beim Anmelden und bleibt dauerhaft in der Menüleiste. Halte fn+⌘, sprich, und lasse los. Mit fn+⌥ wechselst du zwischen Diktat und KI. Die Transkription läuft lokal auf deinem Mac.",
            "waveform.circle"
        ),
        (
            "Mikrofon",
            "SAM benötigt Mikrofonzugriff für die Sprachaufnahme.",
            "mic.fill"
        ),
        (
            "Spracherkennung",
            "Deine Sprache wird auf dem Mac in Text umgewandelt. Im Diktat-Modus bleibt alles lokal.",
            "text.bubble"
        ),
        (
            "Bedienungshilfen",
            "Damit SAM den Hotkey überall erkennt und Text in andere Apps einfügen kann, braucht es Zugriff auf Bedienungshilfen.",
            "hand.raised.fill"
        ),
        (
            "API-Key (optional)",
            "Für den KI-Modus: In den Einstellungen einen Anbieter wählen und API-Key eintragen. Diktat funktioniert ohne Key.",
            "key.fill"
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: steps[step].icon)
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text(steps[step].title)
                .font(.title2.bold())

            Text(steps[step].description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            permissionStatus

            HStack {
                if step > 0 {
                    Button("Zurück") { step -= 1 }
                }
                Spacer()
                Button(step < steps.count - 1 ? "Weiter" : "Fertig") {
                    if step < steps.count - 1 {
                        requestPermissionForStep(step + 1)
                        step += 1
                    } else {
                        finish()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 440, height: 380)
    }

    @ViewBuilder
    private var permissionStatus: some View {
        switch step {
        case 1:
            statusBadge(granted: appState.microphoneGranted, label: "Mikrofon")
        case 2:
            statusBadge(granted: appState.speechGranted, label: "Spracherkennung")
        case 3:
            statusBadge(granted: appState.accessibilityGranted, label: "Bedienungshilfen")
        case 4:
            statusBadge(granted: settings.isActiveProviderConfigured, label: "API-Key")
        default:
            EmptyView()
        }
    }

    private func statusBadge(granted: Bool, label: String) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            Text("\(label): \(granted ? "OK" : "Noch nicht erteilt")")
                .font(.caption)
        }
    }

    private func requestPermissionForStep(_ nextStep: Int) {
        switch nextStep {
        case 1:
            appState.requestMicrophonePermission()
        case 2:
            appState.requestSpeechPermission()
        case 3:
            appState.requestAccessibilityPermission()
        default:
            break
        }
    }

    private func finish() {
        appState.completeOnboarding()
        isPresented = false
    }
}
