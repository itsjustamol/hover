import Foundation

/// Minimal streaming client for the Claude Messages API (raw HTTP + SSE —
/// there is no official Swift SDK).
enum ClaudeClient {
    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-opus-5"

    private static let systemPrompt = """
    You are Feather, an inline look-up popover on macOS — like the built-in \
    Dictionary popup, but powered by AI. The user selected some text on screen \
    and asked what it is.

    Explain the selection concisely:
    - A word or phrase: define it briefly, like a dictionary entry.
    - A name, product, or acronym: say what it is and why it matters.
    - Code, a command, or an error message: explain what it does or means.
    - A sentence or passage: explain or summarize the key idea.

    Keep it to 2–5 short sentences of plain text. No markdown headings, no \
    bullet lists unless genuinely clearer, no preamble like "This is" repeated \
    back — get straight to the explanation.

    The user may ask follow-up questions about the selection; answer those \
    just as concisely.
    """

    /// API key: environment variable first, then the login keychain.
    static func resolveAPIKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
           !key.isEmpty {
            return key
        }
        return Keychain.read()
    }

    /// Streams the assistant's answer for a conversation, one delta at a time.
    /// `messages` is the full history in API shape: [{role, content}].
    static func stream(messages: [[String: String]], apiKey: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(messages: messages, apiKey: apiKey, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Short AI-generated title for long selections (non-streaming).
    static func title(for text: String, apiKey: String) async throws -> String {
        var request = makeRequest(apiKey: apiKey)
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 32,
            "output_config": ["effort": "low"],
            "system": "Write a 2-5 word title describing the user's text. Reply with only the title — no quotes, no trailing punctuation.",
            "messages": [
                ["role": "user", "content": String(text.prefix(2000))]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = object["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String
        else {
            throw APIError(message: "Could not generate a title.")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeRequest(apiKey: String) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60
        return request
    }

    private static func run(
        messages: [[String: String]],
        apiKey: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        var request = makeRequest(apiKey: apiKey)
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "stream": true,
            // Quick inline lookups are latency-sensitive; low effort keeps the
            // popover snappy while adaptive thinking stays available for
            // genuinely hard selections.
            "output_config": ["effort": "low"],
            "system": systemPrompt,
            "messages": messages,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "Unexpected response from the Claude API.")
        }

        guard http.statusCode == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            let message = Self.errorMessage(from: data) ?? "Claude API error (HTTP \(http.statusCode))."
            throw APIError(message: message)
        }

        var sawRefusal = false
        for try await line in bytes.lines {
            guard line.hasPrefix("data: "),
                  let data = line.dropFirst(6).data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String
            else { continue }

            switch type {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    continuation.yield(text)
                }
            case "message_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["stop_reason"] as? String == "refusal" {
                    sawRefusal = true
                }
            case "message_stop":
                if sawRefusal {
                    continuation.yield("\n\nClaude declined to answer this request.")
                }
                return
            case "error":
                let message = (event["error"] as? [String: Any])?["message"] as? String
                throw APIError(message: message ?? "The Claude API returned an error.")
            default:
                break
            }
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any],
              let message = error["message"] as? String
        else { return nil }
        return message
    }
}
