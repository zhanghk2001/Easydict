//
//  OpenAIStreamTransport.swift
//  Easydict
//
//  Created by tisfeng on 2026/9/8.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import OpenAI

// MARK: - OpenAIStreamTransport

/// Sends OpenAI-compatible chat streams while preserving Easydict's response validation.
/// The transport keeps the configured endpoint and Azure-compatible headers, validates
/// the SSE MIME type before consuming bytes, and decodes chunks with the upstream SDK models.
struct OpenAIStreamTransport: Sendable {
    // MARK: Lifecycle

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Internal

    func stream(
        query: ChatQuery,
        url: URL,
        apiKey: String,
        useDashScopeDefaults: Bool = false,
        onResult: @escaping @Sendable (ChatStreamResult) -> ()
    ) async throws {
        let request = try makeRequest(
            query: query, url: url, apiKey: apiKey, useDashScopeDefaults: useDashScopeDefaults
        )
        _ = try await stream(request: request, onResult: onResult)
    }

    /// Consumes a provider-specific image request and returns its complete text.
    func stream(
        request: URLRequest, onResult: @escaping @Sendable (ChatStreamResult) -> ()
    ) async throws
        -> String {
        let (bytes, response) = try await session.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            var errorBody = Data()
            for try await byte in bytes {
                guard errorBody.count < Self.maximumErrorBodySize else {
                    break
                }
                errorBody.append(byte)
            }
            try validate(response: response, errorBody: errorBody)
        }

        try validate(response: response)

        var text = ""
        var eventBuffer = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            eventBuffer.append(byte)
            if let eventData = completedEvent(from: &eventBuffer) {
                let event = try decodeSSEEvent(eventData)
                if event.done { return text }
                if let result = event.result {
                    text += result.choices.first?.delta.content ?? ""
                    onResult(result)
                }
            }
        }

        if !eventBuffer.isEmpty {
            if let result = try decodeSSEEvent(eventBuffer).result {
                text += result.choices.first?.delta.content ?? ""
                onResult(result)
            }
        }
        return text
    }

    func complete(
        query: ChatQuery,
        url: URL,
        apiKey: String,
        useDashScopeDefaults: Bool
    ) async throws -> String {
        let request = try makeRequest(
            query: query, url: url, apiKey: apiKey, streaming: false,
            useDashScopeDefaults: useDashScopeDefaults
        )
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw apiError
            }
            throw QueryError(
                type: .api,
                message: "HTTP \(http.statusCode)",
                errorDataMessage: String(data: data, encoding: .utf8)
            )
        }

        let chatResult = try JSONDecoder().decode(ChatResult.self, from: data)
        guard let content = chatResult.choices.first?.message.content, !content.isEmpty else {
            throw QueryError(type: .noResult)
        }
        return content
    }

    func makeRequest(
        query: ChatQuery,
        url: URL,
        apiKey: String,
        streaming: Bool = true,
        useDashScopeDefaults: Bool = false
    ) throws -> URLRequest {
        var query = query
        query.stream = streaming
        let useDashScope = useDashScopeDefaults && DashScopeChatCompatibility.isChatEndpoint(url)

        var request = URLRequest(
            url: url, timeoutInterval: AppConstants.llmRequestTimeoutInterval
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            if !useDashScope {
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            }
        }

        if useDashScope, DashScopeChatCompatibility.disablesThinking(for: query.model) {
            request.httpBody = try JSONEncoder().encode(DashScopeChatCompatibility.RequestBody(query: query))
        } else {
            request.httpBody = try JSONEncoder().encode(query)
        }
        return request
    }

    func validate(response: URLResponse, errorBody: Data? = nil) throws {
        guard let response = response as? HTTPURLResponse else {
            throw QueryError(type: .api, message: "Invalid OpenAI stream response")
        }

        guard (200 ... 299).contains(response.statusCode) else {
            if let errorBody,
               let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: errorBody) {
                throw apiError
            }
            throw QueryError(
                type: .api,
                message: "HTTP \(response.statusCode)",
                errorDataMessage: errorBody.flatMap { String(data: $0, encoding: .utf8) }
            )
        }

        let mimeType = response.mimeType?.lowercased() ?? "unknown"
        guard mimeType == "text/event-stream" else {
            throw OpenAIStreamTransportError.incorrectContentType(
                mimeType,
                url: response.url?.absoluteString
            )
        }
    }

    func decodeEvent(dataLines: [String]) throws -> ChatStreamResult? {
        let payload = dataLines.joined(separator: "\n").trim()
        guard !payload.isEmpty, payload != "[DONE]" else {
            return nil
        }

        let data = Data(payload.utf8)
        do {
            return try JSONDecoder().decode(ChatStreamResult.self, from: data)
        } catch {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw apiError
            }
            throw error
        }
    }

    // MARK: Private

    private static let maximumErrorBodySize = 64 * 1024

    private let session: URLSession

    private func completedEvent(from buffer: inout Data) -> Data? {
        let delimiterLength: Int
        if buffer.suffix(4).elementsEqual([13, 10, 13, 10]) {
            delimiterLength = 4
        } else if buffer.suffix(2).elementsEqual([10, 10])
            || buffer.suffix(2).elementsEqual([13, 13]) {
            delimiterLength = 2
        } else {
            return nil
        }

        let event = buffer.dropLast(delimiterLength)
        buffer.removeAll(keepingCapacity: true)
        return Data(event)
    }

    private func eventData(from line: String) -> String? {
        guard line.hasPrefix("data:") else {
            return nil
        }
        return line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
    }

    /// Decodes one SSE event while keeping terminal and content events distinct.
    private func decodeSSEEvent(_ event: Data) throws -> (done: Bool, result: ChatStreamResult?) {
        guard let eventString = String(data: event, encoding: .utf8) else {
            throw QueryError(type: .api, message: "Invalid UTF-8 in OpenAI stream response")
        }
        let dataLines = eventString.components(separatedBy: .newlines).compactMap(eventData)
        let payload = dataLines.joined(separator: "\n").trim()
        if payload == "[DONE]" {
            return (true, nil)
        }
        return (false, try decodeEvent(dataLines: dataLines))
    }
}

// MARK: - OpenAIStreamTransportError

/// Reports a non-SSE response using the error wording consumed by Easydict's classifier.
enum OpenAIStreamTransportError: LocalizedError, Equatable {
    case incorrectContentType(String, url: String?)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .incorrectContentType(mimeType, url):
            var message =
                "Incorrect Content-Type: \(mimeType), acceptable type is text/event-stream."
            if let url {
                message += " This may be caused by a wrong endpoint: \(url)"
            }
            return message
        }
    }
}


// MARK: - DashScopeChatCompatibility

/// Applies the Alibaba Cloud request defaults for Custom OpenAI text translation.
enum DashScopeChatCompatibility {
    private static let basePath = "/compatible-mode/v1"
    private static let chatPath = basePath + "/chat/completions"

    static func completionsURL(_ url: URL) -> URL {
        guard isOfficialHTTPSHost(url),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }

        let path = components.percentEncodedPath
        guard path == basePath || path == basePath + "/" else { return url }
        components.percentEncodedPath = chatPath
        return components.url ?? url
    }

    static func isChatEndpoint(_ url: URL) -> Bool {
        guard isOfficialHTTPSHost(url),
              let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath
        else { return false }
        return path == chatPath
    }

    static func disablesThinking(for model: String) -> Bool {
        let id = model.lowercased()
        guard !id.contains("thinking") else { return false }
        return ["qwen3", "qwen4-max", "qwen-plus", "qwen-flash"].contains { prefix in
            id == prefix || id.hasPrefix(prefix + "-") || (prefix == "qwen3" && id.hasPrefix("qwen3."))
        }
    }

    private static func isOfficialHTTPSHost(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return false
        }
        return host == "dashscope.aliyuncs.com" || host == "dashscope-intl.aliyuncs.com"
            || host.hasSuffix(".cn-beijing.maas.aliyuncs.com")
            || host.hasSuffix(".ap-southeast-1.maas.aliyuncs.com")
    }

    struct RequestBody: Encodable {
        let query: ChatQuery

        private enum CodingKeys: String, CodingKey {
            case enableThinking = "enable_thinking"
        }

        func encode(to encoder: Encoder) throws {
            try query.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(false, forKey: .enableThinking)
        }
    }
}
