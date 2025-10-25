// MARK: - 消息模块数据模型 (Message Module Models)

import Foundation

// 收到的回复消息模型
struct ReceivedMessage: Codable, Identifiable {
    let messageId: Int64
    // 回复者信息（显示在AnswerCard中）
    let senderId: Int64
    let senderUsername: String
    let senderAvatarUrl: String?
    // 问题信息（问题创建者的信息）
    let questionId: Int64
    let questionUserId: Int64
    let questionUsername: String
    let questionAvatarUrl: String?
    let questionTitle: String
    let questionContent: String
    let questionCreatedAt: String
    let questionStatus: String
    let questionReplyCount: Int
    let actualPlace: String
    // 回复信息
    let answerId: Int64
    let answerContent: String
    let answerCreatedAt: String
    // 位置信息
    let locationName: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    
    var id: Int64 { messageId }
    
    // 转换为Question对象，使用问题创建者的信息
    func toQuestion() -> Question {
        return Question(
            id: questionId,
            locationID: 0, // 消息中不需要locationID
            userID: questionUserId, // 使用问题创建者的ID
            actualPlace: actualPlace,
            title: questionTitle,
            content: questionContent,
            replyCount: questionReplyCount, // 使用实际的回复数量
            status: questionStatus,
            createdAt: questionCreatedAt,
            updatedAt: answerCreatedAt,
            username: questionUsername, // 使用问题创建者的用户名
            avatarUrl: questionAvatarUrl // 使用问题创建者的头像
        )
    }
}

// 获取收到的消息请求
struct GetReceivedMessagesRequest: Codable {
    let userId: Int64
}

// 获取收到的消息响应
struct GetReceivedMessagesResponse: Codable {
    let success: Bool
    let messages: [ReceivedMessage]
}

// 获取未读消息数量请求
struct GetUnreadMessageCountRequest: Codable {
    let userId: Int64
}

// 获取未读消息数量响应
struct GetUnreadMessageCountResponse: Codable {
    let success: Bool
    let messageCount: Int
}

// 删除消息请求
struct DeleteMessageRequest: Codable {
    let messageId: Int64
    let userId: Int64
}

// 删除消息响应
struct DeleteMessageResponse: Codable {
    let success: Bool
    let message: String
}

// 批量删除消息请求
struct DeleteMessagesBatchRequest: Codable {
    let messageIds: [Int64]
    let userId: Int64
}

// 清空所有消息请求
struct ClearAllMessagesRequest: Codable {
    let userId: Int64
}

// MARK: - NetworkManager 消息模块扩展

extension NetworkManager {
    
    // 获取收到的回复消息
    func getReceivedMessages(userId: Int64) async throws -> GetReceivedMessagesResponse {
        guard let url = URL(string: "\(baseURL)/question/get-received-messages") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = GetReceivedMessagesRequest(userId: userId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("📬 获取收到的回复消息: userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📬 消息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let messagesResponse = try JSONDecoder().decode(GetReceivedMessagesResponse.self, from: data)
            
            if messagesResponse.success {
                print("📬 获取到 \(messagesResponse.messages.count) 条消息")
            }
            
            return messagesResponse
            
        } catch let error as DecodingError {
            print("📬 消息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("📬 获取消息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // 获取未读消息数量
    func getUnreadMessageCount(userId: Int64) async throws -> GetUnreadMessageCountResponse {
        guard let url = URL(string: "\(baseURL)/question/get-unread-message-count") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = GetUnreadMessageCountRequest(userId: userId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🔔 获取未读消息数量: userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔔 未读消息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let countResponse = try JSONDecoder().decode(GetUnreadMessageCountResponse.self, from: data)
            
            if countResponse.success {
                print("🔔 未读消息数量: \(countResponse.messageCount)")
            }
            
            return countResponse
            
        } catch let error as DecodingError {
            print("🔔 未读消息数量响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🔔 获取未读消息数量网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // 删除单条消息
    func deleteMessage(messageId: Int64, userId: Int64) async throws -> DeleteMessageResponse {
        guard let url = URL(string: "\(baseURL)/question/delete-message") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = DeleteMessageRequest(messageId: messageId, userId: userId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🗑️ 删除消息: messageId=\(messageId), userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🗑️ 删除消息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let deleteResponse = try JSONDecoder().decode(DeleteMessageResponse.self, from: data)
            
            if deleteResponse.success {
                print("🗑️ 消息删除成功")
            }
            
            return deleteResponse
            
        } catch let error as DecodingError {
            print("🗑️ 删除消息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🗑️ 删除消息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // 批量删除消息
    func deleteMessagesBatch(messageIds: [Int64], userId: Int64) async throws -> DeleteMessageResponse {
        guard let url = URL(string: "\(baseURL)/question/delete-messages-batch") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = DeleteMessagesBatchRequest(messageIds: messageIds, userId: userId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🗑️ 批量删除消息: \(messageIds.count) 条消息")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🗑️ 批量删除响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let deleteResponse = try JSONDecoder().decode(DeleteMessageResponse.self, from: data)
            
            if deleteResponse.success {
                print("🗑️ 批量删除成功")
            }
            
            return deleteResponse
            
        } catch let error as DecodingError {
            print("🗑️ 批量删除响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🗑️ 批量删除网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // 清空所有消息
    func clearAllMessages(userId: Int64) async throws -> DeleteMessageResponse {
        guard let url = URL(string: "\(baseURL)/question/clear-all-messages") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = ClearAllMessagesRequest(userId: userId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🧹 清空所有消息: userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🧹 清空消息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let clearResponse = try JSONDecoder().decode(DeleteMessageResponse.self, from: data)
            
            if clearResponse.success {
                print("🧹 所有消息清空成功")
            }
            
            return clearResponse
            
        } catch let error as DecodingError {
            print("🧹 清空消息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🧹 清空消息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}



// MessageNetworkServices.swift 中添加
struct GetInviteMessagesRequest: Codable {
    let userId: Int64
}

struct GetInviteMessagesResponse: Codable {
    let success: Bool
    let messages: [Question]  // 或者创建专门的 InviteMessage 模型
}

extension NetworkManager {
    // 获取收到的问题邀请消息
    func getInviteMessages(userId: Int64) async throws -> GetInviteMessagesResponse {
        guard let url = URL(string: "\(baseURL)/question/get-invite-messages") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = GetInviteMessagesRequest(userId: userId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("📨 获取问题邀请消息: userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📨 邀请消息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let inviteResponse = try JSONDecoder().decode(GetInviteMessagesResponse.self, from: data)
            
            if inviteResponse.success {
                print("📨 获取到 \(inviteResponse.messages.count) 条邀请消息")
            }
            
            return inviteResponse
            
        } catch let error as DecodingError {
            print("📨 邀请消息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("📨 获取邀请消息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}
