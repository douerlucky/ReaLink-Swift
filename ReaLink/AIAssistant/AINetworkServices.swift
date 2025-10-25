
//
//  AINetworkServices.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/9/1.
//

import Foundation

// 在 NetworkServices.swift 中添加以下代码
struct AIMessageRequest: Codable {
    let message: String
    let context: String?
    let conversationId: String?
}

struct AIMessageResponse: Codable {
    let success: Bool
    let content: String
    let conversationId: String?
    let usage: AIUsageInfo?
    let message: String?
}

struct AIUsageInfo: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// AI对话历史
struct AIConversationRequest: Codable {
    let conversationId: String
    let limit: Int?
}

struct AIConversationResponse: Codable {
    let success: Bool
    let conversationId: String
    let messages: [AIHistoryMessage]
    let message: String?
}

struct AIHistoryMessage: Codable {
    let role: String
    let content: String
    let timestamp: String
}

// MARK: - NetworkManager AI扩展
extension NetworkManager {
    
    // MARK: - 发送AI消息
    func sendAIMessage(
        message: String,
        context: String? = nil,
        conversationId: String? = nil
    ) async throws -> AIMessageResponse {
        guard let url = URL(string: "\(baseURL)/ai/chat") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let aiRequest = AIMessageRequest(
            message: message,
            context: context,
            conversationId: conversationId
        )
        
        request.httpBody = try JSONEncoder().encode(aiRequest)
        
        print("🤖 发送AI消息请求: \(message.prefix(50))...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 AI消息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(AIMessageResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁，请稍后再试")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let aiResponse = try JSONDecoder().decode(AIMessageResponse.self, from: data)
            
            if aiResponse.success {
                print("🤖 AI消息响应成功: \(aiResponse.content.prefix(100))...")
                if let usage = aiResponse.usage {
                    print("🤖 Token使用情况: \(usage.totalTokens) tokens")
                }
            } else {
                print("🤖 AI消息响应失败: \(aiResponse.message ?? "未知错误")")
            }
            
            return aiResponse
            
        } catch let error as DecodingError {
            print("🤖 AI消息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🤖 AI消息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - 获取AI对话历史
    func getAIConversationHistory(
        conversationId: String,
        limit: Int = 20
    ) async throws -> AIConversationResponse {
        guard let url = URL(string: "\(baseURL)/ai/conversation-history") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let historyRequest = AIConversationRequest(
            conversationId: conversationId,
            limit: limit
        )
        
        request.httpBody = try JSONEncoder().encode(historyRequest)
        
        print("🤖 获取AI对话历史请求: \(conversationId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 对话历史响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("对话历史不存在")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let historyResponse = try JSONDecoder().decode(AIConversationResponse.self, from: data)
            
            if historyResponse.success {
                print("🤖 获取对话历史成功: \(historyResponse.messages.count)条消息")
            }
            
            return historyResponse
            
        } catch let error as DecodingError {
            print("🤖 对话历史响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🤖 对话历史网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - 清除AI对话历史
    func clearAIConversationHistory(conversationId: String) async throws {
        guard let url = URL(string: "\(baseURL)/ai/clear-conversation") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let clearRequest = ["conversationId": conversationId]
        request.httpBody = try JSONSerialization.data(withJSONObject: clearRequest)
        
        print("🤖 清除AI对话历史请求: \(conversationId)")
        
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 清除对话历史响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("清除对话历史失败")
                }
            }
            
            print("🤖 对话历史清除成功")
            
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🤖 清除对话历史网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}

struct QuestionSummaryRequest: Codable {
    let questionId: Int64
}

struct QuestionSummaryResponse: Codable {
    let success: Bool
    let questionId: Int64
    let summary: String
    let questionInfo: QuestionSummaryInfo?
    let usage: AIUsageInfo?
    let message: String?
}

struct QuestionSummaryInfo: Codable {
    let title: String
    let actualPlace: String
    let answerCount: Int
    let status: String
}

struct QuestionFullInfoRequest: Codable {
    let questionId: Int64
}

struct QuestionFullInfoResponse: Codable {
    let success: Bool
    let question: DetailedQuestionInfo
    let answers: [DetailedAnswerInfo]
    let totalAnswers: Int
    let message: String?
}

struct DetailedQuestionInfo: Codable {
    let id: Int64
    let title: String
    let content: String
    let actualPlace: String
    let status: String
    let replyCount: Int
    let createdAt: String
    let authorName: String?
    let authorAvatar: String?
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
}

struct DetailedAnswerInfo: Codable {
    let id: Int64
    let content: String
    let createdAt: String
    let answererName: String?
    let answererAvatar: String?
}

// MARK: - NetworkManager AI总结扩展
extension NetworkManager {
    
    // MARK: - 获取问题AI总结
    func getQuestionSummary(questionId: Int64) async throws -> String {
        guard let url = URL(string: "\(baseURL)/ai/question-summary") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let summaryRequest = QuestionSummaryRequest(questionId: questionId)
        request.httpBody = try JSONEncoder().encode(summaryRequest)
        
        print("🤖 请求问题AI总结: questionId=\(questionId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 AI总结响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("问题不存在")
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁，请稍后再试")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let summaryResponse = try JSONDecoder().decode(QuestionSummaryResponse.self, from: data)
            
            if summaryResponse.success {
                print("🤖 AI总结获取成功: \(summaryResponse.summary.prefix(100))...")
                if let usage = summaryResponse.usage {
                    print("🤖 Token使用: \(usage.totalTokens) tokens")
                }
                return summaryResponse.summary
            } else {
                throw NetworkError.serverError(summaryResponse.message ?? "获取AI总结失败")
            }
            
        } catch let error as DecodingError {
            print("🤖 AI总结响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🤖 AI总结网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - 获取问题完整信息
    func getQuestionFullInfo(questionId: Int64) async throws -> QuestionFullInfoResponse {
        guard let url = URL(string: "\(baseURL)/ai/question-full-info") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let fullInfoRequest = QuestionFullInfoRequest(questionId: questionId)
        request.httpBody = try JSONEncoder().encode(fullInfoRequest)
        
        print("📝 请求问题完整信息: questionId=\(questionId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📝 问题完整信息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("问题不存在")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let fullInfoResponse = try JSONDecoder().decode(QuestionFullInfoResponse.self, from: data)
            
            if fullInfoResponse.success {
                print("📝 问题完整信息获取成功: \(fullInfoResponse.question.title), \(fullInfoResponse.totalAnswers)个回答")
                return fullInfoResponse
            } else {
                throw NetworkError.serverError(fullInfoResponse.message ?? "获取问题完整信息失败")
            }
            
        } catch let error as DecodingError {
            print("📝 问题完整信息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("📝 问题完整信息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - 发送AI消息（增强版，包含更多上下文信息）
    func sendEnhancedAIMessage(
        message: String,
        questionId: Int64? = nil,
        locationInfo: String? = nil,
        conversationId: String? = nil
    ) async throws -> AIMessageResponse {
        guard let url = URL(string: "\(baseURL)/ai/chat") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建增强的上下文信息
        var enhancedContext = ""
        
        if let questionId = questionId {
            do {
                let fullInfo = try await getQuestionFullInfo(questionId: questionId)
                let question = fullInfo.question
                
                enhancedContext += """
            用户正在查看的问题详情：
            标题：\(question.title)
            内容：\(question.content)
            地点：\(question.actualPlace)
            提问者：\(question.authorName ?? "匿名用户")
            提问时间：\(question.createdAt)
            问题状态：\(question.status)
            回答数量：\(fullInfo.totalAnswers)
            
            """
                
                if !fullInfo.answers.isEmpty {
                    enhancedContext += "已有的回答：\n"
                    for (index, answer) in fullInfo.answers.enumerated() {
                        enhancedContext += """
                    回答\(index + 1)：
                    回答者：\(answer.answererName ?? "匿名用户")
                    回答时间：\(answer.createdAt)
                    回答内容：\(answer.content)
                    
                    """
                    }
                }
                
                if let lat = question.latitude, let lon = question.longitude {
                    enhancedContext += "地理位置：纬度\(lat), 经度\(lon)\n"
                }
                
            } catch {
                print("⚠️ 获取问题详情失败，使用基础上下文: \(error)")
            }
        }
        
        if let locationInfo = locationInfo {
            enhancedContext += "位置信息：\(locationInfo)\n"
        }
        
        let aiRequest = AIMessageRequest(
            message: message,
            context: enhancedContext.isEmpty ? nil : enhancedContext,
            conversationId: conversationId
        )
        
        request.httpBody = try JSONEncoder().encode(aiRequest)
        
        print("🤖 发送增强AI消息请求: \(message.prefix(50))...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 增强AI消息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(AIMessageResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁，请稍后再试")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let aiResponse = try JSONDecoder().decode(AIMessageResponse.self, from: data)
            
            if aiResponse.success {
                print("🤖 增强AI消息响应成功: \(aiResponse.content.prefix(100))...")
                if let usage = aiResponse.usage {
                    print("🤖 Token使用情况: \(usage.totalTokens) tokens")
                }
            }
            
            return aiResponse
            
        } catch let error as DecodingError {
            print("🤖 增强AI消息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🤖 增强AI消息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}
extension NetworkManager {
    
    // 修改后的发送AI消息方法，支持保存对话记录
    func sendAIMessage(
        message: String,
        context: String? = nil,
        conversationId: String? = nil,
        questionId: Int64? = nil,
        userId: Int64? = nil
    ) async throws -> AIMessageResponse {
        guard let url = URL(string: "\(baseURL)/ai/chat") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建包含所有必要参数的请求
        let aiRequest: [String: Any] = [
            "message": message,
            "context": context ?? "",
            "conversationId": conversationId ?? "",
            "questionId": questionId ?? 0,
            "userId": userId ?? 0
        ].compactMapValues { value in
            if let stringValue = value as? String, stringValue.isEmpty {
                return stringValue == "" ? nil : stringValue
            }
            if let intValue = value as? Int64, intValue == 0 {
                return questionId == 0 ? nil : intValue
            }
            return value
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: aiRequest)
        
        print("🤖 发送AI消息请求: questionId=\(questionId ?? 0), userId=\(userId ?? 0)")
        print("🤖 消息内容: \(message.prefix(50))...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 AI消息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(AIMessageResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁，请稍后再试")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let aiResponse = try JSONDecoder().decode(AIMessageResponse.self, from: data)
            
            if aiResponse.success {
                print("🤖 AI消息响应成功: \(aiResponse.content.prefix(100))...")
                if let usage = aiResponse.usage {
                    print("🤖 Token使用情况: \(usage.totalTokens) tokens")
                }
            } else {
                print("🤖 AI消息响应失败: \(aiResponse.message ?? "未知错误")")
            }
            
            return aiResponse
            
        } catch let error as DecodingError {
            print("🤖 AI消息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🤖 AI消息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // 获取AI对话历史
    func getAIConversationHistory(
        questionId: Int64,
        userId: Int64,
        limit: Int = 20
    ) async throws -> [AIChatMessage] {
        guard let url = URL(string: "\(baseURL)/ai/conversation-history") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let historyRequest: [String: Any] = [
            "questionId": questionId,
            "userId": userId,
            "limit": limit
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: historyRequest)
        
        print("🤖 获取AI对话历史请求: questionId=\(questionId), userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 对话历史响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    return [] // 没有历史记录
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let historyResponse = try JSONDecoder().decode(AIConversationResponse.self, from: data)
            
            if historyResponse.success {
                let messages = historyResponse.messages.map { historyMessage in
                    AIChatMessage(
                        content: historyMessage.content,
                        isUser: historyMessage.role == "user",
                        timestamp: ISO8601DateFormatter().date(from: historyMessage.timestamp) ?? Date()
                    )
                }
                
                print("🤖 获取对话历史成功: \(messages.count)条消息")
                return messages
            }
            
            return []
            
        } catch let error as DecodingError {
            print("🤖 对话历史响应解析错误: \(error)")
            return []
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🤖 对话历史网络请求失败: \(error)")
            return []
        }
    }
}

// MARK: - 问题发布AI助手相关请求响应模型
struct QuestionSmartSuggestionRequest: Codable {
    let location: String
    let specificPlace: String?
    let title: String
    let content: String
}

struct QuestionSmartSuggestionResponse: Codable {
    let success: Bool
    let suggestion: String
    let originalData: QuestionSuggestionData?
    let usage: AIUsageInfo?
    let message: String?
}

struct QuestionSuggestionData: Codable {
    let location: String
    let specificPlace: String?
    let title: String
    let content: String
}

struct RelatedQuestionsSearchRequest: Codable {
    let location: String
    let title: String?
    let content: String?
    let radius: Double? // 搜索半径(米)
}

struct RelatedQuestionsSearchResponse: Codable {
    let success: Bool
    let summary: String
    let relatedQuestions: [RelatedQuestionInfo]
    let searchLocation: String
    let totalFound: Int
    let usage: AIUsageInfo?
    let message: String?
}

struct RelatedQuestionInfo: Codable {
    let id: Int64
    let title: String
    let content: String
    let actualPlace: String
    let status: String
    let replyCount: Int
    let createdAt: String
}

struct QuestionAIFollowUpRequest: Codable {
    let message: String
    let context: String
}

struct QuestionAIFollowUpResponse: Codable {
    let success: Bool
    let content: String
    let usage: AIUsageInfo?
    let message: String?
}

// MARK: - NetworkManager 问题AI助手扩展
extension NetworkManager {
    
    // MARK: - 修复后的智能提问建议
    func getQuestionSmartSuggestion(
        location: String,
        specificPlace: String,
        title: String,
        content: String
    ) async throws -> QuestionSmartSuggestionResponse {
        guard let url = URL(string: "\(baseURL)/ai/question-smart-suggestion") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 确保参数格式正确
        let suggestionRequest: [String: Any] = [
            "location": location.trimmingCharacters(in: .whitespacesAndNewlines),
            "specificPlace": specificPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : specificPlace.trimmingCharacters(in: .whitespacesAndNewlines),
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "content": content.trimmingCharacters(in: .whitespacesAndNewlines)
        ].compactMapValues { $0 }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: suggestionRequest)
        
        print("🤖 发送智能提问建议请求: \(location) - \(title.prefix(20))...")
        print("🤖 请求URL: \(url)")
        print("🤖 请求参数: \(suggestionRequest)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 智能建议响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    print("❌ API端点不存在，检查后端路由是否正确")
                    throw NetworkError.serverError("API端点不存在，请检查后端服务")
                } else if httpResponse.statusCode == 400 {
                    // 尝试解析错误响应
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorData["message"] as? String {
                        throw NetworkError.serverError("请求参数错误: \(message)")
                    }
                    throw NetworkError.serverError("请求参数错误")
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁，请稍后再试")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // 打印响应数据用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("🤖 响应数据: \(responseString.prefix(200))...")
            }
            
            let suggestionResponse = try JSONDecoder().decode(QuestionSmartSuggestionResponse.self, from: data)
            
            if suggestionResponse.success {
                print("✅ 智能建议获取成功: \(suggestionResponse.suggestion.prefix(100))...")
                if let usage = suggestionResponse.usage {
                    print("🤖 Token使用: \(usage.totalTokens) tokens")
                }
            } else {
                print("❌ 智能建议获取失败: \(suggestionResponse.message ?? "未知错误")")
            }
            
            return suggestionResponse
            
        } catch let error as DecodingError {
            print("❌ 智能建议响应解析错误: \(error)")
            print("❌ 解析错误详情: \(error.localizedDescription)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ 智能建议网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - 修复后的相关问题搜索
    func getRelatedQuestionsSummary(
        location: String,
        latitude: Double,
        longitude: Double,
        title: String,
        content: String,
        radius: Double = 100.0
    ) async throws -> RelatedQuestionsSearchResponse {
        guard let url = URL(string: "\(baseURL)/ai/related-questions-search") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let searchRequest: [String: Any] = [
            "location": location.trimmingCharacters(in: .whitespacesAndNewlines),
            "latitude": latitude,   // 新增
            "longitude": longitude, // 新增
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title.trimmingCharacters(in: .whitespacesAndNewlines),
            "content": content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content.trimmingCharacters(in: .whitespacesAndNewlines),
            "radius": radius
        ].compactMapValues { $0 }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: searchRequest)
        
        print("🤖 发送相关问题搜索请求: \(location)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 相关问题搜索响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("API端点不存在，请检查后端服务")
                } else if httpResponse.statusCode == 400 {
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorData["message"] as? String {
                        throw NetworkError.serverError("请求参数错误: \(message)")
                    }
                    throw NetworkError.serverError("请求参数错误")
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁，请稍后再试")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let searchResponse = try JSONDecoder().decode(RelatedQuestionsSearchResponse.self, from: data)
            
            if searchResponse.success {
                print("✅ 相关问题搜索成功: 找到\(searchResponse.totalFound)个相关问题")
                if let usage = searchResponse.usage {
                    print("🤖 Token使用: \(usage.totalTokens) tokens")
                }
            } else {
                print("❌ 相关问题搜索失败: \(searchResponse.message ?? "未知错误")")
            }
            
            return searchResponse
            
        } catch let error as DecodingError {
            print("❌ 相关问题搜索响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ 相关问题搜索网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - AI后续对话方法
    func sendQuestionAIFollowUp(
        message: String,
        context: String
    ) async throws -> QuestionAIFollowUpResponse {
        guard let url = URL(string: "\(baseURL)/ai/question-followup") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let followUpRequest: [String: Any] = [
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
            "context": context
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: followUpRequest)
        
        print("🤖 发送AI后续对话请求: \(message.prefix(50))...")
        print("🤖 请求URL: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 AI后续对话响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("API端点不存在，请检查后端服务")
                } else if httpResponse.statusCode == 400 {
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorData["message"] as? String {
                        throw NetworkError.serverError("请求参数错误: \(message)")
                    }
                    throw NetworkError.serverError("请求参数错误")
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁，请稍后再试")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let followUpResponse = try JSONDecoder().decode(QuestionAIFollowUpResponse.self, from: data)
            
            if followUpResponse.success {
                print("✅ AI后续对话成功: \(followUpResponse.content.prefix(100))...")
                if let usage = followUpResponse.usage {
                    print("🤖 Token使用: \(usage.totalTokens) tokens")
                }
            } else {
                print("❌ AI后续对话失败: \(followUpResponse.message ?? "未知错误")")
            }
            
            return followUpResponse
            
        } catch let error as DecodingError {
            print("❌ AI后续对话响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ AI后续对话网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }

    // MARK: - 添加网络状态检查方法
    func checkAIServiceStatus() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/ai/status") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 AI服务状态检查: \(httpResponse.statusCode)")
                return httpResponse.statusCode == 200
            }
            
            return false
            
        } catch {
            print("❌ AI服务状态检查失败: \(error)")
            return false
        }
    }
}

// 地点问题总结请求
struct LocationQuestionsSummaryRequest: Codable {
    let locationId: Int64
}

// 地点问题总结响应
struct LocationQuestionsSummaryResponse: Codable {
    let success: Bool
    let locationId: Int64
    let locationName: String
    let summary: String
    let questionCount: Int
    let usage: AIUsageInfo?
    let message: String?
}

// MARK: - NetworkManager 地点问题总结扩展
extension NetworkManager {
    
    func getLocationQuestionsSummary(locationId: Int64) async throws -> LocationQuestionsSummaryResponse {
        guard let url = URL(string: "\(baseURL)/ai/location-questions-summary") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let summaryRequest = LocationQuestionsSummaryRequest(locationId: locationId)
        request.httpBody = try JSONEncoder().encode(summaryRequest)
        
        print("🤖 请求地点问题总结: locationId=\(locationId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 地点问题总结响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("地点不存在")
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁,请稍后再试")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let summaryResponse = try JSONDecoder().decode(LocationQuestionsSummaryResponse.self, from: data)
            
            if summaryResponse.success {
                print("✅ 地点问题总结获取成功: \(summaryResponse.summary.prefix(100))...")
                if let usage = summaryResponse.usage {
                    print("🤖 Token使用: \(usage.totalTokens) tokens")
                }
            }
            
            return summaryResponse
            
        } catch let error as DecodingError {
            print("❌ 地点问题总结响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ 地点问题总结网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}
