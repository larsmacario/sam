import AppKit
import SwiftUI

/// Schwebendes NSPanel für Aufnahme-Pille und Antwort-Fenster.
@MainActor
final class OverlayWindowController: ObservableObject {
    static let shared = OverlayWindowController()

    enum PillState {
        case recording  // Aufnahme läuft
        case modeFlash  // kurzer Hinweis nach Moduswechsel
    }

    private var recordingPanel: NSPanel?
    private var answerPanel: NSPanel?
    private var flashTask: Task<Void, Never>?

    @Published var recordingTranscript = ""
    @Published var isRecordingVisible = false
    @Published var currentMode: InputMode = .ai
    @Published var pillState: PillState = .recording
    @Published var recordingStart = Date()
    @Published var answerText = ""
    @Published var isAnswerVisible = false

    private init() {}

    // MARK: - Aufnahme-Pille

    func showRecording(mode: InputMode) {
        flashTask?.cancel()
        currentMode = mode
        pillState = .recording
        recordingTranscript = ""
        recordingStart = Date()
        presentRecordingPanel()
    }

    func updateRecordingTranscript(_ transcript: String) {
        recordingTranscript = transcript
        refreshRecordingContent()
    }

    /// Klar sichtbares Feedback nach Moduswechsel (fn+Option); blendet selbsttätig aus.
    func flashMode(_ mode: InputMode) {
        flashTask?.cancel()
        currentMode = mode
        pillState = .modeFlash
        recordingTranscript = ""
        presentRecordingPanel()

        flashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard !Task.isCancelled else { return }
            self?.hideRecording()
        }
    }

    func hideRecording() {
        flashTask?.cancel()
        isRecordingVisible = false
        recordingPanel?.orderOut(nil)
    }

    private func presentRecordingPanel() {
        isRecordingVisible = true
        if recordingPanel == nil {
            recordingPanel = createPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 72),
                view: RecordingPillView(controller: self),
                hasShadow: false // Pille hat ihren eigenen runden SwiftUI-Schatten
            )
        } else {
            refreshRecordingContent()
        }
        positionRecordingPanel()
        recordingPanel?.orderFrontRegardless()
    }

    // MARK: - Antwort-Fenster

    func showAnswer(_ text: String) {
        answerText = text
        isAnswerVisible = true

        if answerPanel == nil {
            answerPanel = createPanel(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
                view: AnswerPanelView(controller: self)
            )
            installEscapeMonitor()
        } else {
            refreshAnswerContent()
        }

        positionAnswerPanel()
        answerPanel?.orderFrontRegardless()
    }

    func hideAnswer() {
        isAnswerVisible = false
        answerPanel?.orderOut(nil)
    }

    private var escapeMonitor: Any?

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self?.hideAnswer()
                }
                return nil
            }
            return event
        }
    }

    // MARK: - Panel-Infrastruktur

    private func createPanel<V: View>(contentRect: NSRect, view: V, hasShadow: Bool = true) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = hasShadow
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let hosting = NSHostingView(rootView: view)
        hosting.frame = contentRect
        panel.contentView = hosting

        return panel
    }

    private func refreshRecordingContent() {
        guard let panel = recordingPanel else { return }
        let hosting = NSHostingView(rootView: RecordingPillView(controller: self))
        hosting.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 420, height: 72)
        panel.contentView = hosting
    }

    private func refreshAnswerContent() {
        guard let panel = answerPanel else { return }
        let hosting = NSHostingView(rootView: AnswerPanelView(controller: self))
        hosting.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 460, height: 340)
        panel.contentView = hosting
    }

    private func positionRecordingPanel() {
        guard let panel = recordingPanel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 48
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionAnswerPanel() {
        guard let panel = answerPanel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - SwiftUI Views

/// Dynamic-Island-Pille (dunkles Vibrancy-Glas) mit Live-Waveform + Modus-Indikator.
struct RecordingPillView: View {
    @ObservedObject var controller: OverlayWindowController

    private var mode: InputMode { controller.currentMode }
    private var color: Color { mode.accentColor }

    var body: some View {
        ZStack {
            HStack(spacing: 13) {
                iconBadge
                if controller.pillState == .recording {
                    recordingContent
                } else {
                    modeFlashContent
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 18)
            .frame(height: 52)
            .background(pillBackground)
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.40), radius: 20, x: 0, y: 12)
            .fixedSize()
        }
        .frame(width: 420, height: 72)
    }

    private var iconBadge: some View {
        ZStack {
            Circle().fill(color)
            Image(systemName: mode.pillSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
        .shadow(color: color.opacity(0.5), radius: 6, x: 0, y: 2)
    }

    private var recordingContent: some View {
        HStack(spacing: 12) {
            WaveformView(color: color)
                .frame(width: 132)

            VStack(alignment: .leading, spacing: 1) {
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if controller.recordingTranscript.isEmpty {
                    PillTimerText(start: controller.recordingStart)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                } else {
                    Text(controller.recordingTranscript)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(width: 82, alignment: .leading)
        }
    }

    private var modeFlashContent: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Modus")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.55))
            Text(mode.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.trailing, 4)
    }

    private var pillBackground: some View {
        ZStack {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(Color(red: 0.086, green: 0.086, blue: 0.094).opacity(0.55))
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Animierte „Listening"-Waveform – seismografisch wandernde Hülle plus Jitter.
struct WaveformView: View {
    let color: Color
    var barCount: Int = 26
    var maxHeight: CGFloat = 24

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let level = barLevel(t: t, i: Double(i))
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: 3, height: max(3, maxHeight * level))
                        .opacity(0.55 + level * 0.45)
                }
            }
            .frame(height: maxHeight)
        }
    }

    private func barLevel(t: Double, i: Double) -> CGFloat {
        let env = 0.45 + 0.4 * sin(t * 1.8 + i * 0.5)
        let jitter = 0.5 + 0.5 * abs(sin(t * 5.0 + i * 1.3))
        return CGFloat(max(0.14, min(1.0, env * jitter)))
    }
}

/// Laufender Aufnahme-Timer (mm:ss).
struct PillTimerText: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(start)))
            Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
        }
    }
}

/// Antwort-Fenster im Glas-Design (Vibrancy), konsistent mit Pille & Settings-Popover.
struct AnswerPanelView: View {
    @ObservedObject var controller: OverlayWindowController
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SamDesign.chatColor)
                Text("SAM")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button { controller.hideAnswer() } label: {
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

            // Antworttext
            ScrollView {
                Text(controller.answerText)
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)

            // Footer
            HStack {
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(controller.answerText, forType: .string)
                    copied = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Kopiert" : "Kopieren")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SamDesign.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .frame(width: 460, height: 340)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onChange(of: controller.answerText) { _, _ in copied = false }
    }
}
