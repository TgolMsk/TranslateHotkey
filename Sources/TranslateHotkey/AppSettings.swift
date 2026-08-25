import Foundation
import Combine
import Carbon.HIToolbox
import Security

/// All user-configurable settings. Everything persists to UserDefaults,
/// except the API key which is stored in the macOS Keychain.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    static let languagePresets = [
        "English", "Chinese (Simplified)", "Chinese (Traditional)",
        "Japanese", "Korean", "French", "German", "Spanish", "Russian",
    ]

    static let defaultSystemPrompt = """
    You are a professional translation engine. Translate the text provided by the user into {target_language}.

    Rules:
    - Output ONLY the translated text. No explanations, no notes, no quotation marks around the result.
    - Preserve the original line breaks and paragraph structure.
    - Keep code snippets, URLs, file paths, variable names, numbers and placeholders (like {name} or %s) unchanged.
    - Match the register of the source text (casual stays casual, formal stays formal).
    - If the text is already entirely in {target_language}, return it unchanged.
    """

    private let defaults = UserDefaults.standard

    // MARK: - API

    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Keys.baseURL) }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }
    @Published var apiKey: String {
        didSet { Keychain.set(apiKey) }
    }
    @Published var temperature: Double {
        didSet { defaults.set(temperature, forKey: Keys.temperature) }
    }
    /// 0 means "not set" (omitted from the request).
    @Published var maxTokens: Int {
        didSet { defaults.set(maxTokens, forKey: Keys.maxTokens) }
    }
    @Published var timeoutSeconds: Double {
        didSet { defaults.set(timeoutSeconds, forKey: Keys.timeout) }
    }

    // MARK: - Translation

    @Published var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }
    @Published var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: Keys.systemPrompt) }
    }

    // MARK: - Interface

    /// "system", "en", "zh-Hans", "ja", or "ko". Resolved by L10n.
    @Published var uiLanguage: String {
        didSet { defaults.set(uiLanguage, forKey: L10n.defaultsKey) }
    }

    // MARK: - Hotkey (Carbon key code + Carbon modifier mask)

    @Published var hotkeyKeyCode: UInt32 {
        didSet { defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode) }
    }
    @Published var hotkeyModifiers: UInt32 {
        didSet { defaults.set(Int(hotkeyModifiers), forKey: Keys.hotkeyModifiers) }
    }

    private enum Keys {
        static let baseURL = "th.baseURL"
        static let model = "th.model"
        static let temperature = "th.temperature"
        static let maxTokens = "th.maxTokens"
        static let timeout = "th.timeoutSeconds"
        static let targetLanguage = "th.targetLanguage"
        static let systemPrompt = "th.systemPrompt"
        static let hotkeyKeyCode = "th.hotkeyKeyCode"
        static let hotkeyModifiers = "th.hotkeyModifiers"
    }

    private init() {
        baseURL = defaults.string(forKey: Keys.baseURL) ?? "https://api.deepseek.com/v1"
        model = defaults.string(forKey: Keys.model) ?? "deepseek-chat"
        apiKey = Keychain.get() ?? ""
        temperature = defaults.object(forKey: Keys.temperature) as? Double ?? 0.3
        maxTokens = defaults.object(forKey: Keys.maxTokens) as? Int ?? 0
        timeoutSeconds = defaults.object(forKey: Keys.timeout) as? Double ?? 30
        targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "English"
        systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? AppSettings.defaultSystemPrompt
        uiLanguage = defaults.string(forKey: L10n.defaultsKey) ?? "system"
        // Default hotkey: Option+Command+T
        hotkeyKeyCode = UInt32(defaults.object(forKey: Keys.hotkeyKeyCode) as? Int ?? kVK_ANSI_T)
        hotkeyModifiers = UInt32(defaults.object(forKey: Keys.hotkeyModifiers) as? Int ?? (cmdKey | optionKey))
    }

    /// The system prompt with placeholders substituted.
    func renderedSystemPrompt() -> String {
        systemPrompt.replacingOccurrences(of: "{target_language}", with: targetLanguage)
    }

    /// Human-readable description of the current hotkey, e.g. "⌥⌘T".
    func hotkeyDescription() -> String {
        KeyNames.describe(keyCode: hotkeyKeyCode, carbonModifiers: hotkeyModifiers)
    }
}

// MARK: - Keychain helper (stores only the API key)

enum Keychain {
    private static let service = "com.sheng.TranslateHotkey"
    private static let account = "api-key"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func set(_ value: String) {
        SecItemDelete(baseQuery as CFDictionary)
        guard !value.isEmpty else { return }
        var query = baseQuery
        query[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Key name helpers

enum KeyNames {
    private static let names: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Escape): "⎋", UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ANSI_Grave): "`", UInt32(kVK_ANSI_Minus): "-", UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Backslash): "\\", UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'", UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".", UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
    ]

    static func name(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }

    static func describe(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + name(for: keyCode)
    }
}
