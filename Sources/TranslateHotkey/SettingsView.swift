import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SettingsView: View {

    @ObservedObject var settings: AppSettings

    @State private var testInput = "你好，很高兴认识你。"
    @State private var testResult = ""
    @State private var testRunning = false

    var body: some View {
        TabView {
            apiTab
                .tabItem { Label(L10n.t(.tabAPI), systemImage: "network") }
            translationTab
                .tabItem { Label(L10n.t(.tabTranslation), systemImage: "character.bubble") }
            generalTab
                .tabItem { Label(L10n.t(.tabGeneral), systemImage: "gearshape") }
        }
        .frame(width: 580, height: 500)
    }

    // MARK: - API tab

    private var apiTab: some View {
        Form {
            Section {
                TextField(L10n.t(.lblBaseURL), text: $settings.baseURL, prompt: Text("https://api.deepseek.com/v1"))
                SecureField(L10n.t(.lblAPIKey), text: $settings.apiKey, prompt: Text("sk-…"))
                TextField(L10n.t(.lblModel), text: $settings.model, prompt: Text("deepseek-chat"))
            } footer: {
                Text(L10n.t(.hintProviders))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                LabeledContent(L10n.t(.lblTemperature)) {
                    HStack {
                        Slider(value: $settings.temperature, in: 0...2, step: 0.1)
                        Text(String(format: "%.1f", settings.temperature))
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                Stepper(
                    "\(L10n.t(.lblMaxTokens)): \(settings.maxTokens == 0 ? L10n.t(.valAuto) : String(settings.maxTokens))",
                    value: $settings.maxTokens,
                    in: 0...16384,
                    step: 256
                )
                Stepper(
                    "\(L10n.t(.lblTimeout)): \(Int(settings.timeoutSeconds))s",
                    value: $settings.timeoutSeconds,
                    in: 5...180,
                    step: 5
                )
            }

            Section(L10n.t(.secTest)) {
                TextField(L10n.t(.lblSample), text: $testInput)
                HStack {
                    Button(testRunning ? L10n.t(.btnTesting) : L10n.t(.btnTest)) {
                        runTest()
                    }
                    .disabled(testRunning)
                    Spacer()
                }
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(.caption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Translation tab

    private var translationTab: some View {
        Form {
            Section {
                LabeledContent(L10n.t(.lblTargetLanguage)) {
                    HStack {
                        TextField("", text: $settings.targetLanguage)
                            .labelsHidden()
                            .frame(minWidth: 160)
                        Menu(L10n.t(.btnPresets)) {
                            ForEach(AppSettings.languagePresets, id: \.self) { lang in
                                Button(L10n.displayName(forTargetLanguage: lang)) {
                                    settings.targetLanguage = lang
                                }
                            }
                        }
                        .fixedSize()
                    }
                }
            }

            Section {
                TextEditor(text: $settings.systemPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 180)
                HStack {
                    Spacer()
                    Button(L10n.t(.btnResetPrompt)) {
                        settings.systemPrompt = AppSettings.defaultSystemPrompt
                    }
                }
            } header: {
                Text(L10n.t(.lblPrompt))
            } footer: {
                Text(L10n.t(.hintPrompt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - General tab

    private var generalTab: some View {
        Form {
            Section {
                LabeledContent(L10n.t(.lblHotkey)) {
                    ShortcutRecorderButton(settings: settings)
                }
            } header: {
                Text(L10n.t(.secHotkey))
            } footer: {
                Text(L10n.t(.hintHotkey))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(L10n.t(.secInterface)) {
                Picker(L10n.t(.lblUILanguage), selection: $settings.uiLanguage) {
                    Text(L10n.t(.langSystem)).tag("system")
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-Hans")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Connection test

    private func runTest() {
        testRunning = true
        testResult = ""
        let config = Translator.config(from: settings)
        let sample = testInput
        Task { @MainActor in
            do {
                let result = try await Translator.translate(text: sample, config: config)
                testResult = "✓ \(result)"
            } catch {
                testResult = "✗ \(error.localizedDescription)"
            }
            testRunning = false
        }
    }
}

/// A button that records the next key combination pressed while active.
struct ShortcutRecorderButton: View {

    @ObservedObject var settings: AppSettings
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(recording ? L10n.t(.btnPressKeys) : settings.hotkeyDescription()) {
            if recording {
                stopRecording()
            } else {
                startRecording()
            }
        }
        .frame(minWidth: 180)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stopRecording() }

            if event.keyCode == UInt16(kVK_Escape) {
                return nil // cancelled
            }

            let carbonMods = ShortcutRecorderButton.carbonModifiers(from: event.modifierFlags)
            // Require at least one of ⌘ ⌥ ⌃ so ordinary typing can't become a hotkey.
            let hasRealModifier = carbonMods & UInt32(cmdKey | optionKey | controlKey) != 0
            guard hasRealModifier else {
                NSSound.beep()
                return nil
            }

            settings.hotkeyKeyCode = UInt32(event.keyCode)
            settings.hotkeyModifiers = carbonMods
            return nil // swallow the event
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        return mods
    }
}
