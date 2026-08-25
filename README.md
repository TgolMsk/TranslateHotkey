# TranslateHotkey

A macOS menu bar utility: put your cursor in any text field, press a global
hotkey, and the text is selected, translated by an LLM (any OpenAI-compatible
API), and replaced in place.

Typical use: draft a message in Chinese in Slack / mail / a browser, press
`⌥⌘T`, and the draft becomes English — without leaving the input box.

## How it works

1. The global hotkey fires (default `⌥⌘T`, changeable in Settings).
2. The app waits for you to release the modifier keys, then synthesizes
   `⌘A` + `⌘C` in the frontmost app to capture the field's text.
3. The text is sent to the configured `/chat/completions` endpoint with your
   translation prompt.
4. The result is pasted back with `⌘V`, replacing the selection.
5. Your original clipboard contents are restored about a second later.

While translating, the menu bar icon switches to a busy state; errors beep
and appear as a status line inside the menu.

The menu bar menu also offers:

- **Restore Original Text** — undo the last translation: puts the
  pre-translation text back into the focused field (enabled after each
  successful translation).
- **Target Language** submenu — switch the target language on the fly
  without opening Settings; the current language is checkmarked.

## Interface languages

The app UI (menu, settings, status and error messages) is available in
English, 简体中文, 日本語, and 한국어. By default it follows the macOS system
language; pick a specific one in Settings → General → Interface language.
The switch applies immediately — no relaunch needed.

## Requirements

- macOS 13 (Ventura) or newer
- Xcode Command Line Tools: `xcode-select --install`
- An API key for any OpenAI-compatible provider (or a local model server)

## Build & install

```bash
cd ~/Project/TranslatePlugin
chmod +x build_app.sh
./build_app.sh
mv build/TranslateHotkey.app /Applications/
open /Applications/TranslateHotkey.app
```

On first launch:

1. macOS asks for **Accessibility** permission (needed to synthesize
   keystrokes). Enable *TranslateHotkey* in
   System Settings → Privacy & Security → Accessibility.
   If the toggle was set while the app was running, quit and relaunch it.
2. The Settings window opens automatically because no API key is set yet.
   Fill in the base URL, API key, and model, then click **Test translation**.

## Configuration

Everything is in the menu bar icon → **Settings…**, organized in three tabs:
**API** (endpoint, key, model parameters, connection test), **Translation**
(target language, prompt), and **General** (hotkey, interface language).

| Setting | Notes |
|---|---|
| Base URL | Endpoint root, e.g. `https://api.deepseek.com/v1`. `/chat/completions` is appended automatically. |
| API Key | Stored in the macOS Keychain, not in a plist. Empty key is allowed for localhost endpoints. |
| Model | e.g. `deepseek-chat`, `qwen-plus`, `moonshot-v1-8k`, `gpt-4o-mini` |
| Temperature | 0–2. Lower = more literal. 0.3 is a good default for translation. |
| Max tokens | 0 = let the API decide. |
| Timeout | Request timeout in seconds. |
| Target language | Free text; presets provided. Injected into the prompt as `{target_language}`. |
| Translation prompt | The system prompt. `{target_language}` is substituted; the captured text is sent as the user message. |
| Global hotkey | Click the button, press a new combination (must include ⌘, ⌥, or ⌃). Esc cancels. |

### Common OpenAI-compatible endpoints

| Provider | Base URL | Example model |
|---|---|---|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| Qwen (DashScope) | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| Moonshot | `https://api.moonshot.cn/v1` | `moonshot-v1-8k` |
| Zhipu GLM | `https://open.bigmodel.cn/api/paas/v4` | `glm-4-air` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |
| Ollama (local) | `http://localhost:11434/v1` | `qwen2.5:7b` |
| LM Studio (local) | `http://localhost:1234/v1` | (loaded model) |

## Behavior details & limitations

- **Select all**: the hotkey translates the *entire* input field (`⌘A`), which
  matches the "translate what I typed" workflow. Fields where `⌘A` does not
  mean "select all text" (e.g. a file browser) will misbehave — only trigger
  it with the cursor in a text field.
- **Clipboard**: the previous clipboard contents (including rich content) are
  saved and restored automatically ~1 s after the paste.
- **Password fields / Secure Keyboard Entry**: macOS blocks synthetic input
  there by design; nothing will happen.
- **Re-entrancy**: pressing the hotkey while a translation is running is
  ignored.
- **Launch at Login**: available in the menu (works when running from the
  `.app` bundle, ideally from `/Applications`).

## Troubleshooting

- **Hotkey does nothing** → Check Accessibility permission; after a rebuild,
  remove the app from the Accessibility list and re-add it (the ad-hoc code
  signature changes on every build), then relaunch.
- **"Could not register hotkey"** in the menu → the combination is taken by
  another app or by macOS; record a different one.
- **API errors** → use *Test translation* in Settings; the raw API message is
  shown. Check the base URL (many providers need the `/v1` suffix) and that
  the model name is valid for that provider.
- **Text pasted but garbled formatting** → the app pastes plain text; rich
  formatting of the original is not preserved (by design — input boxes are
  usually plain text).

## Project layout

```
Package.swift                 Swift Package Manager manifest
build_app.sh                  builds .app bundle (ad-hoc signed)
Resources/Info.plist          bundle metadata (LSUIElement = menu bar only)
Sources/TranslateHotkey/
  main.swift                  entry point
  AppDelegate.swift           menu bar UI + translation flow orchestration
  HotkeyManager.swift         Carbon global hotkey registration
  TextCapture.swift           ⌘A/⌘C/⌘V synthesis, clipboard snapshot/restore
  Translator.swift            OpenAI-compatible chat-completions client
  AppSettings.swift           settings store (UserDefaults + Keychain)
  SettingsView.swift          SwiftUI settings window (tabbed) + hotkey recorder
  Localization.swift          UI string tables (EN / 简体中文 / 日本語 / 한국어)
```
