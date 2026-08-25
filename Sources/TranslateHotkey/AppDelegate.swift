import AppKit
import SwiftUI
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let settings = AppSettings.shared
    private let hotkeyManager = HotkeyManager()

    private var statusItem: NSStatusItem!
    private var translateMenuItem: NSMenuItem!
    private var restoreMenuItem: NSMenuItem!
    private var languageMenuItem: NSMenuItem!
    private var statusLineItem: NSMenuItem!
    private var settingsMenuItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var quitMenuItem: NSMenuItem!

    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var isTranslating = false

    /// The field text as it was before the last successful translation,
    /// so a bad translation can be undone.
    private var lastOriginalText: String?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        hotkeyManager.onTrigger = { [weak self] in
            self?.startTranslation()
        }
        registerHotkey()

        // Re-register whenever the hotkey settings change.
        settings.$hotkeyKeyCode
            .combineLatest(settings.$hotkeyModifiers)
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.registerHotkey()
            }
            .store(in: &cancellables)

        // Re-localize the menu and window when the UI language changes.
        settings.$uiLanguage
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshUI()
                if !self.isTranslating {
                    self.setStatus(L10n.t(.statusReady))
                }
                self.settingsWindow?.title = L10n.t(.winTitle)
            }
            .store(in: &cancellables)

        // Ask for Accessibility permission up front so the first hotkey press works.
        if !TextCapture.ensureAccessibility(prompt: true) {
            setStatus(L10n.t(.statusGrantAccess))
        }

        // First launch with no API key: open Settings so the user can configure it.
        if settings.apiKey.isEmpty {
            openSettings()
        }
    }

    // MARK: - Status item / menu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(busy: false)

        let menu = NSMenu()

        translateMenuItem = NSMenuItem(title: "", action: #selector(translateNow), keyEquivalent: "")
        translateMenuItem.target = self
        menu.addItem(translateMenuItem)

        restoreMenuItem = NSMenuItem(title: "", action: #selector(restoreOriginal), keyEquivalent: "")
        restoreMenuItem.target = self
        menu.addItem(restoreMenuItem)

        languageMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        languageMenuItem.submenu = NSMenu()
        menu.addItem(languageMenuItem)

        statusLineItem = NSMenuItem(title: L10n.t(.statusReady), action: nil, keyEquivalent: "")
        statusLineItem.isEnabled = false
        menu.addItem(statusLineItem)

        menu.addItem(.separator())

        settingsMenuItem = NSMenuItem(title: "", action: #selector(openSettings), keyEquivalent: ",")
        settingsMenuItem.target = self
        menu.addItem(settingsMenuItem)

        launchAtLoginItem = NSMenuItem(title: "", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        quitMenuItem = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitMenuItem)

        menu.delegate = self
        statusItem.menu = menu
        refreshUI()
    }

    private func setIcon(busy: Bool) {
        let symbol = busy ? "arrow.triangle.2.circlepath" : "character.bubble"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "TranslateHotkey")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    /// Applies all localized titles and current state to the menu.
    private func refreshUI() {
        translateMenuItem.title = L10n.f(
            .menuTranslate,
            settings.hotkeyDescription(),
            L10n.displayName(forTargetLanguage: settings.targetLanguage)
        )
        restoreMenuItem.title = L10n.t(.menuRestore)
        languageMenuItem.title = L10n.t(.menuTargetLanguage)
        settingsMenuItem.title = L10n.t(.menuSettings)
        launchAtLoginItem.title = L10n.t(.menuLaunchAtLogin)
        quitMenuItem.title = L10n.t(.menuQuit)
        rebuildLanguageSubmenu()

        if #available(macOS 13.0, *), Bundle.main.bundleIdentifier != nil {
            launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            launchAtLoginItem.isHidden = false
        } else {
            launchAtLoginItem.isHidden = true
        }
    }

    private func setStatus(_ text: String) {
        statusLineItem.title = text
    }

    private func rebuildLanguageSubmenu() {
        guard let submenu = languageMenuItem.submenu else { return }
        submenu.removeAllItems()

        var languages = AppSettings.languagePresets
        // Keep a custom language (typed in Settings) visible in the list.
        if !languages.contains(settings.targetLanguage), !settings.targetLanguage.isEmpty {
            languages.insert(settings.targetLanguage, at: 0)
        }
        for language in languages {
            let item = NSMenuItem(
                title: L10n.displayName(forTargetLanguage: language),
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language
            item.state = language == settings.targetLanguage ? .on : .off
            submenu.addItem(item)
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? String else { return }
        settings.targetLanguage = language
        refreshUI()
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        let ok = hotkeyManager.register(
            keyCode: settings.hotkeyKeyCode,
            carbonModifiers: settings.hotkeyModifiers
        )
        if !ok {
            setStatus(L10n.f(.statusHotkeyFailed, settings.hotkeyDescription()))
        }
        refreshUI()
    }

    // MARK: - Translation flow

    @objc private func translateNow() {
        // Give the menu time to close and focus to return to the previous app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.startTranslation()
        }
    }

    private func startTranslation() {
        guard !isTranslating else { return }

        guard TextCapture.ensureAccessibility(prompt: true) else {
            notifyError(L10n.t(.errAccessibility))
            return
        }

        isTranslating = true
        setIcon(busy: true)
        setStatus(L10n.t(.statusCapturing))

        let config = Translator.config(from: settings)
        let clipboardSnapshot = TextCapture.snapshotPasteboard()

        // Run capture off the main thread: it sleeps while waiting for
        // modifier release and the pasteboard update.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            TextCapture.waitForModifierRelease()
            let captured = TextCapture.selectAllAndCopy()

            DispatchQueue.main.async {
                guard let self else { return }
                let text = (captured ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    TextCapture.restorePasteboard(clipboardSnapshot)
                    self.finish(error: L10n.t(.errNoText))
                    return
                }
                self.setStatus(L10n.f(.statusTranslating, text.count))
                Task { @MainActor in
                    do {
                        let translated = try await Translator.translate(text: text, config: config)
                        TextCapture.paste(translated)
                        self.lastOriginalText = text
                        // Restore the user's clipboard once the paste has landed.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            TextCapture.restorePasteboard(clipboardSnapshot)
                        }
                        self.finish(error: nil)
                    } catch {
                        TextCapture.restorePasteboard(clipboardSnapshot)
                        self.finish(error: error.localizedDescription)
                    }
                }
            }
        }
    }

    /// Puts the pre-translation text back into the focused field.
    @objc private func restoreOriginal() {
        guard let original = lastOriginalText, !isTranslating else { return }
        guard TextCapture.ensureAccessibility(prompt: true) else {
            notifyError(L10n.t(.errAccessibility))
            return
        }
        isTranslating = true
        setIcon(busy: true)
        setStatus(L10n.t(.statusRestoring))

        let clipboardSnapshot = TextCapture.snapshotPasteboard()
        // Give the menu time to close and focus to return to the previous app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            TextCapture.replaceAll(with: original)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                TextCapture.restorePasteboard(clipboardSnapshot)
            }
            guard let self else { return }
            self.lastOriginalText = nil
            self.isTranslating = false
            self.setIcon(busy: false)
            self.setStatus(L10n.t(.statusRestored))
        }
    }

    /// Enables/disables menu items (NSMenu calls this automatically).
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(restoreOriginal) {
            return lastOriginalText != nil && !isTranslating
        }
        if menuItem.action == #selector(translateNow) {
            return !isTranslating
        }
        return true
    }

    private func finish(error: String?) {
        isTranslating = false
        setIcon(busy: false)
        if let error {
            notifyError(error)
        } else {
            setStatus(L10n.f(.statusDone, Self.timeString()))
        }
    }

    private func notifyError(_ message: String) {
        NSSound.beep()
        setStatus(L10n.f(.statusError, message))
        NSLog("TranslateHotkey error: %@", message)
    }

    private static func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    // MARK: - Settings window

    @objc func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.title = L10n.t(.winTitle)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Launch at login

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *), Bundle.main.bundleIdentifier != nil else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            notifyError(L10n.f(.errLaunchAtLogin, error.localizedDescription))
        }
        refreshUI()
    }
}

extension AppDelegate: NSMenuItemValidation {}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshUI()
    }
}
