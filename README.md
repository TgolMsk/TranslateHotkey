# TranslateHotkey

一个 macOS 菜单栏小工具：把光标放进任意输入框，按下全局快捷键，
文本会被自动全选、经由大模型（任何兼容 OpenAI 接口的服务）翻译，
并就地替换。

典型场景：在 Slack、邮件或浏览器里用中文写好一段话，按 `⌥⌘T`，
草稿立刻变成英文——全程不用离开输入框。

## 工作原理

1. 全局快捷键触发（默认 `⌥⌘T`，可在设置中修改）。
2. 应用等待你松开修饰键，然后向最前面的 App 模拟
   `⌘A` + `⌘C`，抓取输入框内的文本。
3. 文本连同你的翻译提示词一起发送到配置好的 `/chat/completions` 接口。
4. 结果通过 `⌘V` 粘贴回去，替换掉选中的内容。
5. 大约一秒后，你原本的剪贴板内容会被恢复。

翻译过程中，菜单栏图标会切换为忙碌状态；出错时会响一声提示音，
并在菜单里以状态行的形式显示错误信息。

菜单栏菜单还提供：

- **恢复原文** —— 撤销上一次翻译：把翻译前的文本放回当前输入框
  （每次翻译成功后启用）。
- **目标语言** 子菜单 —— 无需打开设置即可随时切换目标语言，
  当前语言带勾选标记。

## 界面语言

应用界面（菜单、设置、状态与错误信息）支持
English、简体中文、日本語、한국어。默认跟随 macOS 系统语言；
也可以在 设置 → 通用 → 界面语言 中指定。
切换后立即生效——无需重启。

## 系统要求

- macOS 13 (Ventura) 或更高版本
- Xcode 命令行工具：`xcode-select --install`
- 任意兼容 OpenAI 接口的服务的 API Key（或本地模型服务）

## 构建与安装

```bash
git clone https://github.com/TgolMsk/TranslateHotkey.git
cd TranslateHotkey
./build_app.sh
mv build/TranslateHotkey.app /Applications/
open /Applications/TranslateHotkey.app
```

首次启动时：

1. macOS 会请求 **辅助功能** 权限（模拟按键所必需）。请在
   系统设置 → 隐私与安全性 → 辅助功能 中启用 *TranslateHotkey*。
   如果是在应用运行期间才打开该开关，请退出并重新启动应用。
2. 由于尚未设置 API Key，设置窗口会自动打开。
   填入 Base URL、API Key 和模型，然后点击 **测试翻译**。

## 配置说明

所有配置都在 菜单栏图标 → **设置…** 中，分为三个标签页：
**API**（接口地址、密钥、模型参数、连接测试）、**翻译**
（目标语言、提示词）、**通用**（快捷键、界面语言）。

| 设置项 | 说明 |
|---|---|
| Base URL | 接口根地址，例如 `https://api.deepseek.com/v1`，`/chat/completions` 会自动追加。 |
| API Key | 保存在 macOS 钥匙串中，而非 plist 文件。本地（localhost）接口允许留空。 |
| 模型 | 例如 `deepseek-chat`、`qwen-plus`、`moonshot-v1-8k`、`gpt-4o-mini` |
| 温度 | 0–2。越低越直译，翻译场景建议 0.3。 |
| 最大 Token 数 | 0 表示交由接口自行决定。 |
| 超时 | 请求超时时间，单位为秒。 |
| 目标语言 | 自由填写，也提供预设。会以 `{target_language}` 注入提示词。 |
| 翻译提示词 | 即系统提示词。其中 `{target_language}` 会被替换；抓取到的文本作为用户消息发送。 |
| 全局快捷键 | 点击按钮后按下新的组合键（必须包含 ⌘、⌥ 或 ⌃）。按 Esc 取消。 |

### 常见的 OpenAI 兼容接口

| 服务商 | Base URL | 示例模型 |
|---|---|---|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| 通义千问（DashScope） | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| 月之暗面 Moonshot | `https://api.moonshot.cn/v1` | `moonshot-v1-8k` |
| 智谱 GLM | `https://open.bigmodel.cn/api/paas/v4` | `glm-4-air` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |
| Ollama（本地） | `http://localhost:11434/v1` | `qwen2.5:7b` |
| LM Studio（本地） | `http://localhost:1234/v1` | （已加载的模型） |

## 行为细节与限制

- **全选**：快捷键翻译的是*整个*输入框的内容（`⌘A`），这与
  "翻译我刚写的东西"这一使用习惯一致。在 `⌘A` 并非"全选文本"的
  场景下（例如访达文件列表）会出现异常——请只在光标位于文本输入框时触发。
- **剪贴板**：原有的剪贴板内容（包括富文本）会被保存，
  并在粘贴约 1 秒后自动恢复。
- **密码框 / 安全键盘输入**：macOS 出于设计会屏蔽此处的模拟输入，
  因此不会有任何反应。
- **重入**：翻译进行中再次按下快捷键会被忽略。
- **开机自启动**：在菜单中提供（需从 `.app` 包运行，
  建议放在 `/Applications` 目录下）。

## 疑难排查

- **快捷键无反应** → 检查辅助功能权限；重新构建之后，请把应用从
  辅助功能列表中移除再重新添加（每次构建的 ad-hoc 签名都会变化），
  然后重启应用。
- **菜单里出现"无法注册快捷键"** → 该组合键已被其他应用或
  macOS 占用，请换一个。
- **API 报错** → 使用设置中的*测试翻译*，会显示接口返回的原始信息。
  检查 Base URL（很多服务商需要 `/v1` 后缀），以及模型名称
  对该服务商是否有效。
- **粘贴后格式错乱** → 应用粘贴的是纯文本，不保留原文的富文本格式
  （这是有意为之——输入框通常都是纯文本）。

## 项目结构

```
Package.swift                 Swift Package Manager 清单
build_app.sh                  构建 .app 包（ad-hoc 签名）
Resources/Info.plist          包元数据（LSUIElement = 仅菜单栏）
Sources/TranslateHotkey/
  main.swift                  程序入口
  AppDelegate.swift           菜单栏 UI + 翻译流程编排
  HotkeyManager.swift         基于 Carbon 的全局快捷键注册
  TextCapture.swift           ⌘A/⌘C/⌘V 模拟、剪贴板快照与恢复
  Translator.swift            OpenAI 兼容的 chat-completions 客户端
  AppSettings.swift           设置存储（UserDefaults + 钥匙串）
  SettingsView.swift          SwiftUI 设置窗口（分页）+ 快捷键录制
  Localization.swift          界面字符串表（EN / 简体中文 / 日本語 / 한국어）
```
