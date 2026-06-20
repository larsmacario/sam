import AppKit
import Combine
import SwiftUI

/// App-Delegate: Menüleisten-Icon, zentriertes Glas-Settings-Panel, Onboarding.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var onboardingWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var settingsPopover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    let launchAtLoginService = LaunchAtLoginService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        observeMenuBarIcon()
        observeOnboardingDismissal()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOnboardingCompleted),
            name: .samOnboardingCompleted,
            object: nil
        )

        Task { @MainActor in
            AppState.shared.bootstrap()

            if !SettingsStore.shared.hasCompletedOnboarding {
                showOnboardingWindow()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationDidBecomeActive() {
        Task { @MainActor in
            AppState.shared.refreshPermissions()
            if AccessibilityPermissionService.currentStatus() {
                AppState.shared.restartHotkey()
            }
        }
    }

    // MARK: - Menüleiste

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true
        if #available(macOS 14.0, *) {
            item.behavior = .removalAllowed
        }
        item.button?.target = self
        item.button?.action = #selector(statusBarButtonClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        updateMenuBarIcon(AppState.shared.status)
    }

    private func observeMenuBarIcon() {
        AppState.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateMenuBarIcon(status)
            }
            .store(in: &cancellables)
    }

    private func observeOnboardingDismissal() {
        AppState.shared.$showOnboarding
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                guard !show else { return }
                self?.closeOnboardingWindow()
            }
            .store(in: &cancellables)
    }

    @objc private func handleOnboardingCompleted() {
        launchAtLoginService.enableByDefaultIfNeeded()
    }

    private func updateMenuBarIcon(_ status: AppStatus) {
        guard let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        if let image = NSImage(systemSymbolName: status.menuBarSymbol, accessibilityDescription: "SAM")?
            .withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu(relativeTo: sender)
        } else {
            toggleSettingsPanel()
        }
    }

    private func showStatusMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()
        if MeetingSessionController.shared.isActive {
            let stopItem = NSMenuItem(
                title: "Meeting beenden",
                action: #selector(stopMeetingFromMenu),
                keyEquivalent: ""
            )
            stopItem.target = self
            menu.addItem(stopItem)
            menu.addItem(.separator())
        }
        let settingsItem = NSMenuItem(title: "Einstellungen…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Beenden", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openSettingsFromMenu() {
        showSettingsPanel()
    }

    @objc private func stopMeetingFromMenu() {
        Task { @MainActor in
            await AppState.shared.stopMeeting()
        }
    }

    @objc private func quitFromMenu() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func toggleSettingsPanel() {
        if let popover = settingsPopover, popover.isShown {
            popover.performClose(nil)
        } else {
            showSettingsPanel()
        }
    }

    @MainActor
    private func showSettingsPanel() {
        guard let button = statusItem?.button else { return }

        if settingsPopover == nil {
            settingsPopover = makeSettingsPopover()
        }
        guard let popover = settingsPopover else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeSettingsPopover() -> NSPopover {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: SamDesign.panelWidth, height: SamDesign.panelHeight)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: SettingsView(
                launchAtLoginService: launchAtLoginService,
                onShowOnboarding: { [weak self] in
                    self?.settingsPopover?.performClose(nil)
                    self?.showOnboardingWindow()
                }
            )
        )
        return popover
    }

    // MARK: - Onboarding

    @MainActor
    func showOnboardingWindow() {
        if onboardingWindow != nil {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingView(
            rootView: OnboardingView(
                isPresented: .init(
                    get: { AppState.shared.showOnboarding },
                    set: { [weak self] newValue in
                        AppState.shared.showOnboarding = newValue
                        if !newValue {
                            self?.onboardingWindow?.close()
                            self?.onboardingWindow = nil
                        }
                    }
                ),
                launchAtLoginService: launchAtLoginService
            )
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Willkommen bei SAM"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
        AppState.shared.showOnboarding = true
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.delegate = nil
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === onboardingWindow else { return }
        onboardingWindow = nil
        if AppState.shared.allRequiredPermissionsGranted {
            AppState.shared.completeOnboarding()
        } else {
            AppState.shared.showOnboarding = false
        }
    }
}
