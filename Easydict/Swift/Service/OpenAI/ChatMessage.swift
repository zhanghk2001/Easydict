//
//  ChatMessage.swift
//  Easydict
//
//  Created by tisfeng on 2024/11/3.
//  Copyright © 2024 izual. All rights reserved.
//

import Foundation

func systemMessage(queryType: EZQueryTextType) -> ChatMessage {
    switch queryType {
    case .dictionary:
        .init(role: .system, content: StreamService.dictSystemPrompt)
    default:
        .init(role: .system, content: StreamService.translationSystemPrompt)
    }
}

func chatMessagePair(userContent: String, assistantContent: String) -> [ChatMessage] {
    [
        .init(role: .user, content: userContent),
        .init(role: .assistant, content: assistantContent),
    ]
}

// MARK: - ChatMessage

struct ChatMessage {
    // MARK: - ChatRole

    enum ChatRole: String, Codable, Equatable, CaseIterable {
        case system
        case user
        case assistant
        case tool
        case model // Gemini role, equal to OpenAI assistant role.
    }

    let role: ChatRole
    let content: String
}

// MARK: - AIToolType

enum AIToolType {
    case polishing
    case summary
}

// MARK: - ChatQueryParam

struct ChatQueryParam {
    let text: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let queryType: EZQueryTextType
    let enableSystemPrompt: Bool

    /// Uses this request's values even when there is no active query window, such as during validation.
    func renderPrompt(_ prompt: String, firstLanguage: Language) -> String {
        prompt
            .replacingOccurrences(of: "${{queryFromLanguage}}", with: sourceLanguage.rawValue)
            .replacingOccurrences(of: "${{queryTargetLanguage}}", with: targetLanguage.rawValue)
            .replacingOccurrences(of: "${{firstLanguage}}", with: firstLanguage.rawValue)
            .replacingOccurrences(of: "${{queryText}}", with: text)
    }

    func unpack() -> (String, Language, Language, EZQueryTextType, Bool) {
        (text, sourceLanguage, targetLanguage, queryType, enableSystemPrompt)
    }
}
