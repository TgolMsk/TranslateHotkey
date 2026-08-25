import Foundation

/// Minimal OpenAI-compatible chat-completions client.
/// Works with OpenAI, DeepSeek, Qwen (DashScope compatible mode), Moonshot,
/// GLM, Ollama, LM Studio, and any other endpoint that speaks the same API.
enum Translator {

    struct TranslationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct Config {
        let baseURL: String
        let apiKey: String
        let model: String
        let temperature: Double
        let maxTokens: Int
        let timeoutSeconds: Double
        let systemPrompt: String
    }

    /// Snapshot the current settings into an immutable config (safe to use
    /// off the main thread). Call this on the main thread.
    static func config(from settings: AppSettings) -> Config {
        Config(
            baseURL: settings.baseURL,
            apiKey: settings.apiKey,
            model: settings.model,
            temperature: settings.temperature,
            maxTokens: settings.maxTokens,
            timeoutSeconds: settings.timeoutSeconds,
            systemPrompt: settings.renderedSystemPrompt()
        )
    }

    static func translate(text: String, config: Config) async throws -> String {
        guard !config.apiKey.isEmpty || config.baseURL.contains("localhost") || config.baseURL.contains("127.0.0.1") else {
            throw TranslationError(message: L10n.t(.errNoAPIKey))
        }

        var base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/chat/completions") else {
            throw TranslationError(message: L10n.f(.errBadURL, config.baseURL))
        }

        var body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": config.systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": config.temperature,
            "stream": false,
        ]
        if config.maxTokens > 0 {
            body["max_tokens"] = config.maxTokens
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslationError(message: L10n.f(.errRequestFailed, error.localizedDescription))
        }

        let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let apiMessage = decoded?.error?.message
                ?? String(data: data.prefix(300), encoding: .utf8)
                ?? "unknown error"
            throw TranslationError(message: L10n.f(.errAPI, http.statusCode, apiMessage))
        }

        guard let content = decoded?.choices?.first?.message.content, !content.isEmpty else {
            throw TranslationError(message: L10n.t(.errEmpty))
        }
        return cleanOutput(content)
    }

    /// Strips wrapping the model sometimes adds despite instructions:
    /// leading/trailing whitespace and full-output code fences.
    static func cleanOutput(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") && text.hasSuffix("```") && text.count > 6 {
            var lines = text.components(separatedBy: "\n")
            if lines.count >= 2 {
                lines.removeFirst() // ``` or ```lang
                if let last = lines.last, last.trimmingCharacters(in: .whitespaces) == "```" {
                    lines.removeLast()
                }
                text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }

    // MARK: - Response models

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        struct APIError: Decodable {
            let message: String?
        }
        let choices: [Choice]?
        let error: APIError?
    }
}
