import Foundation

/// In-app localization for the UI: English, Simplified Chinese, Japanese, Korean.
/// Strings are resolved at call time, so switching the language in Settings
/// takes effect immediately — no relaunch needed.
///
/// The language preference is read straight from UserDefaults (thread-safe),
/// so localized error messages can be built off the main thread too.
enum L10n {

    static let defaultsKey = "th.uiLanguage" // "system" | "en" | "zh-Hans" | "ja" | "ko"

    /// The effective UI language code.
    static var code: String {
        let stored = UserDefaults.standard.string(forKey: defaultsKey) ?? "system"
        if stored != "system" { return stored }
        for lang in Locale.preferredLanguages {
            if lang.hasPrefix("zh") { return "zh-Hans" }
            if lang.hasPrefix("ja") { return "ja" }
            if lang.hasPrefix("ko") { return "ko" }
            if lang.hasPrefix("en") { return "en" }
        }
        return "en"
    }

    static func t(_ key: Key) -> String {
        tables[code]?[key] ?? english[key] ?? key.rawValue
    }

    static func f(_ key: Key, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    /// Localized display name for a target-language preset. The internal
    /// value stays in English (it is injected into the prompt); only the
    /// label shown in menus and pickers is localized.
    static func displayName(forTargetLanguage name: String) -> String {
        targetLanguageNames[code]?[name] ?? name
    }

    // MARK: - Keys

    enum Key: String {
        // Menu bar menu
        case menuTranslate, menuRestore, menuTargetLanguage, menuSettings
        case menuLaunchAtLogin, menuQuit
        // Status line
        case statusReady, statusCapturing, statusTranslating, statusDone
        case statusError, statusRestoring, statusRestored
        case statusGrantAccess, statusHotkeyFailed
        // Errors
        case errAccessibility, errNoText, errNoAPIKey, errBadURL
        case errRequestFailed, errAPI, errEmpty, errLaunchAtLogin
        // Settings window
        case winTitle, tabAPI, tabTranslation, tabGeneral
        case lblBaseURL, lblAPIKey, lblModel, lblTemperature
        case lblMaxTokens, valAuto, lblTimeout, hintProviders
        case lblTargetLanguage, btnPresets, lblPrompt, btnResetPrompt, hintPrompt
        case secHotkey, lblHotkey, hintHotkey, btnPressKeys
        case secTest, lblSample, btnTest, btnTesting
        case secInterface, lblUILanguage, langSystem
    }

    // MARK: - String tables

    private static let tables: [String: [Key: String]] = [
        "en": english, "zh-Hans": chinese, "ja": japanese, "ko": korean,
    ]

    private static let english: [Key: String] = [
        .menuTranslate: "Translate Current Input  (%@ → %@)",
        .menuRestore: "Restore Original Text",
        .menuTargetLanguage: "Target Language",
        .menuSettings: "Settings…",
        .menuLaunchAtLogin: "Launch at Login",
        .menuQuit: "Quit TranslateHotkey",

        .statusReady: "Ready",
        .statusCapturing: "Capturing text…",
        .statusTranslating: "Translating %d characters…",
        .statusDone: "Done ✓ %@",
        .statusError: "Error: %@",
        .statusRestoring: "Restoring original text…",
        .statusRestored: "Original restored ✓",
        .statusGrantAccess: "Grant Accessibility permission, then relaunch",
        .statusHotkeyFailed: "Could not register hotkey %@ — is it taken?",

        .errAccessibility: "Accessibility permission is required. Enable it in System Settings → Privacy & Security → Accessibility, then try again.",
        .errNoText: "No text found in the focused input field.",
        .errNoAPIKey: "API key is not set. Open Settings and add your key.",
        .errBadURL: "Invalid base URL: %@",
        .errRequestFailed: "Request failed: %@",
        .errAPI: "API error (HTTP %d): %@",
        .errEmpty: "The API returned no translation.",
        .errLaunchAtLogin: "Launch at Login failed: %@",

        .winTitle: "TranslateHotkey Settings",
        .tabAPI: "API",
        .tabTranslation: "Translation",
        .tabGeneral: "General",
        .lblBaseURL: "Base URL",
        .lblAPIKey: "API Key",
        .lblModel: "Model",
        .lblTemperature: "Temperature",
        .lblMaxTokens: "Max tokens",
        .valAuto: "auto",
        .lblTimeout: "Timeout",
        .hintProviders: "DeepSeek https://api.deepseek.com/v1 · Qwen https://dashscope.aliyuncs.com/compatible-mode/v1 · Moonshot https://api.moonshot.cn/v1 · OpenAI https://api.openai.com/v1 · Ollama http://localhost:11434/v1",
        .lblTargetLanguage: "Target language",
        .btnPresets: "Presets",
        .lblPrompt: "Translation prompt",
        .btnResetPrompt: "Reset to default",
        .hintPrompt: "{target_language} is replaced with the language above. The captured text is sent as the user message.",
        .secHotkey: "Hotkey",
        .lblHotkey: "Global hotkey",
        .hintHotkey: "Press the hotkey while the cursor is in any text field: the app selects all, translates, and replaces the text.",
        .btnPressKeys: "Press keys… (Esc to cancel)",
        .secTest: "Connection test",
        .lblSample: "Sample text",
        .btnTest: "Test translation",
        .btnTesting: "Testing…",
        .secInterface: "Interface",
        .lblUILanguage: "Interface language",
        .langSystem: "System",
    ]

    private static let chinese: [Key: String] = [
        .menuTranslate: "翻译当前输入（%@ → %@）",
        .menuRestore: "恢复原文",
        .menuTargetLanguage: "目标语言",
        .menuSettings: "设置…",
        .menuLaunchAtLogin: "开机自启动",
        .menuQuit: "退出 TranslateHotkey",

        .statusReady: "就绪",
        .statusCapturing: "正在获取文本…",
        .statusTranslating: "正在翻译 %d 个字符…",
        .statusDone: "完成 ✓ %@",
        .statusError: "错误：%@",
        .statusRestoring: "正在恢复原文…",
        .statusRestored: "已恢复原文 ✓",
        .statusGrantAccess: "请授予“辅助功能”权限后重新启动",
        .statusHotkeyFailed: "无法注册快捷键 %@——可能已被其他应用占用",

        .errAccessibility: "需要“辅助功能”权限。请在 系统设置 → 隐私与安全性 → 辅助功能 中启用后重试。",
        .errNoText: "当前输入框中没有找到文本。",
        .errNoAPIKey: "尚未设置 API Key。请打开设置并填写。",
        .errBadURL: "无效的 Base URL：%@",
        .errRequestFailed: "请求失败：%@",
        .errAPI: "API 错误（HTTP %d）：%@",
        .errEmpty: "API 未返回翻译结果。",
        .errLaunchAtLogin: "设置开机自启动失败：%@",

        .winTitle: "TranslateHotkey 设置",
        .tabAPI: "API",
        .tabTranslation: "翻译",
        .tabGeneral: "通用",
        .lblBaseURL: "Base URL",
        .lblAPIKey: "API Key",
        .lblModel: "模型",
        .lblTemperature: "温度",
        .lblMaxTokens: "最大 Token 数",
        .valAuto: "自动",
        .lblTimeout: "超时",
        .lblTargetLanguage: "目标语言",
        .btnPresets: "预设",
        .lblPrompt: "翻译提示词",
        .btnResetPrompt: "恢复默认",
        .hintPrompt: "{target_language} 将被替换为上面选择的语言；捕获的文本作为用户消息发送。",
        .secHotkey: "快捷键",
        .lblHotkey: "全局快捷键",
        .hintHotkey: "将光标置于任意输入框中并按下快捷键：应用会全选、翻译并替换文本。",
        .btnPressKeys: "请按下按键…（Esc 取消）",
        .secTest: "连接测试",
        .lblSample: "示例文本",
        .btnTest: "测试翻译",
        .btnTesting: "测试中…",
        .secInterface: "界面",
        .lblUILanguage: "界面语言",
        .langSystem: "跟随系统",
    ]

    private static let japanese: [Key: String] = [
        .menuTranslate: "現在の入力を翻訳（%@ → %@）",
        .menuRestore: "元のテキストに戻す",
        .menuTargetLanguage: "翻訳先の言語",
        .menuSettings: "設定…",
        .menuLaunchAtLogin: "ログイン時に起動",
        .menuQuit: "TranslateHotkey を終了",

        .statusReady: "準備完了",
        .statusCapturing: "テキストを取得中…",
        .statusTranslating: "%d 文字を翻訳中…",
        .statusDone: "完了 ✓ %@",
        .statusError: "エラー: %@",
        .statusRestoring: "元のテキストを復元中…",
        .statusRestored: "元のテキストに戻しました ✓",
        .statusGrantAccess: "アクセシビリティ権限を許可してから再起動してください",
        .statusHotkeyFailed: "ホットキー %@ を登録できません — 他のアプリが使用中かもしれません",

        .errAccessibility: "アクセシビリティ権限が必要です。システム設定 → プライバシーとセキュリティ → アクセシビリティで有効にして、もう一度お試しください。",
        .errNoText: "フォーカス中の入力欄にテキストが見つかりません。",
        .errNoAPIKey: "API キーが設定されていません。設定を開いて入力してください。",
        .errBadURL: "無効なベース URL: %@",
        .errRequestFailed: "リクエストに失敗しました: %@",
        .errAPI: "API エラー (HTTP %d): %@",
        .errEmpty: "API から翻訳結果が返されませんでした。",
        .errLaunchAtLogin: "ログイン時に起動の設定に失敗しました: %@",

        .winTitle: "TranslateHotkey 設定",
        .tabAPI: "API",
        .tabTranslation: "翻訳",
        .tabGeneral: "一般",
        .lblBaseURL: "ベース URL",
        .lblAPIKey: "API キー",
        .lblModel: "モデル",
        .lblTemperature: "温度",
        .lblMaxTokens: "最大トークン数",
        .valAuto: "自動",
        .lblTimeout: "タイムアウト",
        .lblTargetLanguage: "翻訳先の言語",
        .btnPresets: "プリセット",
        .lblPrompt: "翻訳プロンプト",
        .btnResetPrompt: "デフォルトに戻す",
        .hintPrompt: "{target_language} は上で選んだ言語に置き換えられます。取得したテキストはユーザーメッセージとして送信されます。",
        .secHotkey: "ホットキー",
        .lblHotkey: "グローバルホットキー",
        .hintHotkey: "カーソルをテキスト欄に置いてホットキーを押すと、全選択 → 翻訳 → 置き換えを行います。",
        .btnPressKeys: "キーを押してください…（Esc でキャンセル）",
        .secTest: "接続テスト",
        .lblSample: "サンプルテキスト",
        .btnTest: "翻訳をテスト",
        .btnTesting: "テスト中…",
        .secInterface: "表示",
        .lblUILanguage: "表示言語",
        .langSystem: "システムに合わせる",
    ]

    private static let korean: [Key: String] = [
        .menuTranslate: "현재 입력 번역 (%@ → %@)",
        .menuRestore: "원본 텍스트 복원",
        .menuTargetLanguage: "대상 언어",
        .menuSettings: "설정…",
        .menuLaunchAtLogin: "로그인 시 시작",
        .menuQuit: "TranslateHotkey 종료",

        .statusReady: "준비됨",
        .statusCapturing: "텍스트 캡처 중…",
        .statusTranslating: "%d자 번역 중…",
        .statusDone: "완료 ✓ %@",
        .statusError: "오류: %@",
        .statusRestoring: "원본 텍스트 복원 중…",
        .statusRestored: "원본 복원됨 ✓",
        .statusGrantAccess: "손쉬운 사용 권한을 허용한 후 다시 실행하세요",
        .statusHotkeyFailed: "단축키 %@를 등록할 수 없습니다 — 이미 사용 중일 수 있습니다",

        .errAccessibility: "손쉬운 사용 권한이 필요합니다. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 활성화한 후 다시 시도하세요.",
        .errNoText: "포커스된 입력란에서 텍스트를 찾을 수 없습니다.",
        .errNoAPIKey: "API 키가 설정되지 않았습니다. 설정에서 키를 입력하세요.",
        .errBadURL: "잘못된 기본 URL: %@",
        .errRequestFailed: "요청 실패: %@",
        .errAPI: "API 오류 (HTTP %d): %@",
        .errEmpty: "API가 번역 결과를 반환하지 않았습니다.",
        .errLaunchAtLogin: "로그인 시 시작 설정에 실패했습니다: %@",

        .winTitle: "TranslateHotkey 설정",
        .tabAPI: "API",
        .tabTranslation: "번역",
        .tabGeneral: "일반",
        .lblBaseURL: "기본 URL",
        .lblAPIKey: "API 키",
        .lblModel: "모델",
        .lblTemperature: "온도",
        .lblMaxTokens: "최대 토큰 수",
        .valAuto: "자동",
        .lblTimeout: "시간 제한",
        .lblTargetLanguage: "대상 언어",
        .btnPresets: "프리셋",
        .lblPrompt: "번역 프롬프트",
        .btnResetPrompt: "기본값으로 재설정",
        .hintPrompt: "{target_language}는 위에서 선택한 언어로 대체됩니다. 캡처된 텍스트는 사용자 메시지로 전송됩니다.",
        .secHotkey: "단축키",
        .lblHotkey: "전역 단축키",
        .hintHotkey: "커서를 입력란에 두고 단축키를 누르면 전체 선택 → 번역 → 교체가 실행됩니다.",
        .btnPressKeys: "키를 누르세요… (Esc 취소)",
        .secTest: "연결 테스트",
        .lblSample: "샘플 텍스트",
        .btnTest: "번역 테스트",
        .btnTesting: "테스트 중…",
        .secInterface: "인터페이스",
        .lblUILanguage: "인터페이스 언어",
        .langSystem: "시스템 따르기",
    ]

    // MARK: - Localized names for target-language presets

    private static let targetLanguageNames: [String: [String: String]] = [
        "zh-Hans": [
            "English": "英语", "Chinese (Simplified)": "简体中文",
            "Chinese (Traditional)": "繁体中文", "Japanese": "日语",
            "Korean": "韩语", "French": "法语", "German": "德语",
            "Spanish": "西班牙语", "Russian": "俄语",
        ],
        "ja": [
            "English": "英語", "Chinese (Simplified)": "簡体字中国語",
            "Chinese (Traditional)": "繁体字中国語", "Japanese": "日本語",
            "Korean": "韓国語", "French": "フランス語", "German": "ドイツ語",
            "Spanish": "スペイン語", "Russian": "ロシア語",
        ],
        "ko": [
            "English": "영어", "Chinese (Simplified)": "중국어 간체",
            "Chinese (Traditional)": "중국어 번체", "Japanese": "일본어",
            "Korean": "한국어", "French": "프랑스어", "German": "독일어",
            "Spanish": "스페인어", "Russian": "러시아어",
        ],
    ]
}
