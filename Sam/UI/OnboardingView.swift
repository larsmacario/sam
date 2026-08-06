import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var appState = AppState.shared
    @ObservedObject var licenseService = LicenseService.shared
    @Binding var isPresented: Bool
    var launchAtLoginService: LaunchAtLoginService

    @State private var step = 0
    @State private var licenseKeyInput = ""
    @State private var licenseMessage: String?
    @State private var licenseIsError = false
    @State private var isActivatingLicense = false

    private let steps: [(title: String, description: String, icon: String)] = [
        (
            "Lizenz aktivieren",
            "Starte auf der SAM-Website den 7-Tage-Test oder kaufe SAM. Trage den Lizenzschlüssel aus der E-Mail hier ein.",
            "key.fill"
        ),
        (
            "Willkommen bei SAM",
            "SAM startet beim Anmelden und bleibt dauerhaft in der Menüleiste. Halte fn+⌘, sprich, und lasse los. Mit fn+⌥ wechselst du zwischen Diktat und KI.",
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
            "Für den KI-Modus: In den Einstellungen einen Anbieter wählen und API-Key eintragen.",
            "sparkles"
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

            if step == 0 {
                licenseStep
            } else {
                permissionStatus
            }

            HStack {
                if step > 0 {
                    Button("Zurück") { step -= 1 }
                }
                Spacer()
                Button(primaryButtonTitle) {
                    handlePrimaryAction()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(step == 0 && !licenseService.isLicensed && !isActivatingLicense)
            }
        }
        .padding(32)
        .frame(width: 440, height: step == 0 ? 430 : 380)
        .onAppear {
            licenseKeyInput = licenseService.storedLicenseKey ?? ""
        }
    }

    private var primaryButtonTitle: String {
        if step == 0 && !licenseService.isLicensed {
            return isActivatingLicense ? "Aktiviere…" : "Aktivieren"
        }
        return step < steps.count - 1 ? "Weiter" : "Fertig"
    }

    private var licenseStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("SAM1.…", text: $licenseKeyInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack {
                Button("Kaufen / Testen") {
                    NSWorkspace.shared.open(LicenseConfig.purchaseURL)
                }
                .buttonStyle(.bordered)
            }

            if let licenseMessage {
                Text(licenseMessage)
                    .font(.caption)
                    .foregroundStyle(licenseIsError ? .red : .green)
            } else if licenseService.isLicensed {
                Text(licenseService.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: 360)
    }

    @ViewBuilder
    private var permissionStatus: some View {
        switch step {
        case 2:
            statusBadge(granted: appState.microphoneGranted, label: "Mikrofon")
        case 3:
            statusBadge(granted: appState.speechGranted, label: "Spracherkennung")
        case 4:
            statusBadge(granted: appState.accessibilityGranted, label: "Bedienungshilfen")
        case 5:
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

    private func handlePrimaryAction() {
        if step == 0 && !licenseService.isLicensed {
            Task { await activateLicense() }
            return
        }

        if step < steps.count - 1 {
            requestPermissionForStep(step + 1)
            step += 1
        } else {
            finish()
        }
    }

    private func activateLicense() async {
        isActivatingLicense = true
        licenseMessage = nil
        defer { isActivatingLicense = false }

        do {
            try await licenseService.activate(licenseKey: licenseKeyInput)
            licenseIsError = false
            licenseMessage = "Lizenz aktiviert."
        } catch {
            licenseIsError = true
            licenseMessage = error.localizedDescription
        }
    }

    private func requestPermissionForStep(_ nextStep: Int) {
        switch nextStep {
        case 2:
            appState.requestMicrophonePermission()
        case 3:
            appState.requestSpeechPermission()
        case 4:
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
