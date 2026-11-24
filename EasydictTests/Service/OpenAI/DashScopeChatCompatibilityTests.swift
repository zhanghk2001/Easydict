//
//  DashScopeChatCompatibilityTests.swift
//  EasydictTests
//

import Foundation
import OpenAI
import Testing

@testable import Easydict

@Suite("DashScope Chat Compatibility", .tags(.unit))
struct DashScopeChatCompatibilityTests {
    @Test("An official base URL resolves to a single chat path and preserves the query", arguments: [
        "dashscope.aliyuncs.com",
        "dashscope-intl.aliyuncs.com",
        "workspace.cn-beijing.maas.aliyuncs.com",
        "workspace.ap-southeast-1.maas.aliyuncs.com",
    ])
    func normalizesOfficialBaseURL(host: String) throws {
        let baseURL = try #require(URL(string: "https://\(host)/compatible-mode/v1/?token=%2B"))
        let expected = "https://\(host)/compatible-mode/v1/chat/completions?token=%2B"
        let completionsURL = DashScopeChatCompatibility.completionsURL(baseURL)
        #expect(completionsURL.absoluteString == expected)
        #expect(DashScopeChatCompatibility.completionsURL(completionsURL) == completionsURL)
    }

    @Test("Unrelated endpoints keep their configured path", arguments: [
        "https://proxy.example/compatible-mode/v1",
        "https://dashscope.aliyuncs.com.example/compatible-mode/v1",
        "https://dashscope.aliyuncs.com/api/v1/services",
        "http://dashscope.aliyuncs.com/compatible-mode/v1",
    ])
    func keepsOtherEndpoints(url: String) throws {
        let endpoint = try #require(URL(string: url))
        #expect(DashScopeChatCompatibility.completionsURL(endpoint) == endpoint)
        #expect(!DashScopeChatCompatibility.isChatEndpoint(endpoint))
    }

    @Test("Qwen defaults are encoded at the top level in both transports", arguments: [false, true])
    func sendsDashScopeDefaults(streaming: Bool) throws {
        let request = try makeRequest(streaming: streaming)
        let body = try requestBody(request)
        let messages = try #require(body["messages"] as? [[String: String]])

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer mock-key")
        #expect(request.value(forHTTPHeaderField: "api-key") == nil)
        #expect(body["model"] as? String == "qwen3.8-flash")
        #expect(body["stream"] as? Bool == streaming)
        #expect(body["enable_thinking"] as? Bool == false)
        #expect(body["stream_options"] == nil)
        #expect(messages.first?["content"] == "Translate hello.")
    }

    @Test("Thinking models and other providers keep their request parameters")
    func keepsOtherRequestParameters() throws {
        let thinkingRequest = try makeRequest(model: "qwen3-235b-a22b-thinking-2507")
        #expect(try requestBody(thinkingRequest)["enable_thinking"] == nil)

        let proxy = try #require(URL(string: "https://proxy.example/compatible-mode/v1/chat/completions"))
        let request = try OpenAIStreamTransport().makeRequest(
            query: makeQuery(), url: proxy, apiKey: "mock-key", useDashScopeDefaults: true
        )
        #expect(try requestBody(request)["enable_thinking"] == nil)
        #expect(request.value(forHTTPHeaderField: "api-key") == "mock-key")

        let genericRequest = try OpenAIStreamTransport().makeRequest(
            query: makeQuery(), url: endpoint(), apiKey: "mock-key"
        )
        #expect(try requestBody(genericRequest)["enable_thinking"] == nil)
    }

    @Test("Non-streaming JSON returns the answer and ignores reasoning")
    func jsonReturnsOnlyAnswer() async throws {
        let transport = mockTransport()
        let result = try await transport.complete(
            query: makeQuery(), url: endpoint("json"), apiKey: "mock-key",
            useDashScopeDefaults: true
        )
        #expect(result == "你好")
    }

    @Test("Reasoning without a final answer remains a no-result error")
    func reasoningOnlyIsNotTranslation() async throws {
        do {
            _ = try await mockTransport().complete(
                query: makeQuery(), url: endpoint("reasoning"), apiKey: "mock-key",
                useDashScopeDefaults: true
            )
            Issue.record("Expected no result")
        } catch let error as QueryError {
            #expect(error.type == .noResult)
        }
    }

    @Test("SSE reasoning, empty usage choices and DONE do not hide the translation")
    func sseReturnsOnlyAnswer() async throws {
        let transport = mockTransport()
        let request = try makeRequest(url: endpoint("sse"))
        let text = try await transport.stream(request: request) { _ in }
        #expect(text == "你好")
    }

    @Test("An HTTP error with a provider message keeps its diagnostics")
    func preservesProviderError() async throws {
        do {
            _ = try await mockTransport().complete(
                query: makeQuery(), url: endpoint("error"), apiKey: "mock-key",
                useDashScopeDefaults: true
            )
            Issue.record("Expected an API error")
        } catch let error as QueryError {
            #expect(error.type == .api)
            #expect(error.message == "HTTP 400")
            #expect(error.errorDataMessage?.contains("model unavailable") == true)
        }
    }

    @Test("Validation prompt uses the supplied sample and languages")
    func rendersPromptFromRequest() {
        let query = ChatQueryParam(
            text: "曾经沧海难为水",
            sourceLanguage: .simplifiedChinese,
            targetLanguage: .english,
            queryType: .translation,
            enableSystemPrompt: true
        )
        let rendered = query.renderPrompt(
            "${{queryFromLanguage}} → ${{queryTargetLanguage}}: ${{queryText}} (${{firstLanguage}})",
            firstLanguage: .english
        )
        #expect(rendered == "\(Language.simplifiedChinese.rawValue) → \(Language.english.rawValue): 曾经沧海难为水 (\(Language.english.rawValue))")
    }

    private func endpoint(_ fixture: String = "json") throws -> URL {
        try #require(URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions?fixture=\(fixture)"))
    }

    private func makeQuery(model: String = "qwen3.8-flash") throws -> ChatQuery {
        let message = try #require(ChatQuery.ChatCompletionMessageParam(role: .user, content: "Translate hello."))
        return ChatQuery(messages: [message], model: model)
    }

    private func makeRequest(
        model: String = "qwen3.8-flash", streaming: Bool = true, url: URL? = nil
    ) throws -> URLRequest {
        try OpenAIStreamTransport().makeRequest(
            query: makeQuery(model: model), url: url ?? endpoint(), apiKey: "mock-key",
            streaming: streaming, useDashScopeDefaults: true
        )
    }

    private func requestBody(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func mockTransport() -> OpenAIStreamTransport {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DashScopeMockURLProtocol.self]
        return OpenAIStreamTransport(session: URLSession(configuration: config))
    }
}

// MARK: - DashScopeMockURLProtocol

private final class DashScopeMockURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let fixture = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
        let contentType = fixture == "sse" ? "text/event-stream" : "application/json"
        let statusCode = fixture == "error" ? 400 : 200
        let body: String
        switch fixture {
        case "sse":
            body = """
            data: {"id":"mock","object":"chat.completion.chunk","created":1,"model":"qwen3.8-flash","choices":[{"index":0,"delta":{"reasoning_content":"think","content":null},"finish_reason":null}]}

            data: {"id":"mock","object":"chat.completion.chunk","created":1,"model":"qwen3.8-flash","choices":[{"index":0,"delta":{"content":"你好"},"finish_reason":"stop"}]}

            data: {"id":"mock","object":"chat.completion.chunk","created":1,"model":"qwen3.8-flash","choices":[]}

            data: [DONE]


            """
        case "error":
            body = #"{"code":"InvalidParameter","message":"model unavailable"}"#
        default:
            let content = fixture == "reasoning" ? "null" : #""你好""#
            body = """
            {"id":"mock","object":"chat.completion","created":1,"model":"qwen3.8-flash","choices":[{"index":0,"message":{"role":"assistant","content":\(content),"reasoning_content":"think"},"finish_reason":"stop"}]}
            """
        }
        guard let response = HTTPURLResponse(
            url: url, statusCode: statusCode, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        ) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
