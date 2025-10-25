//
//  QuestionNetworkServices.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/9/1.
//

import Foundation



// MARK: - 辅助类型和扩展 (Helper Types and Extensions)

// 排序选项枚举
enum QuestionSortOption: String, CaseIterable {
    case newest = "created_at_DESC"
    case oldest = "created_at_ASC"
    case mostReplies = "reply_count_DESC"
    case leastReplies = "reply_count_ASC"
    case recentlyUpdated = "updated_at_DESC"
    
    var displayName: String {
        switch self {
        case .newest: return "最新发布"
        case .oldest: return "最早发布"
        case .mostReplies: return "回复最多"
        case .leastReplies: return "回复最少"
        case .recentlyUpdated: return "最近更新"
        }
    }
    
    var sortBy: String {
        switch self {
        case .newest, .oldest: return "created_at"
        case .mostReplies, .leastReplies: return "reply_count"
        case .recentlyUpdated: return "updated_at"
        }
    }
    
    var sortOrder: String {
        switch self {
        case .newest, .mostReplies, .recentlyUpdated: return "DESC"
        case .oldest, .leastReplies: return "ASC"
        }
    }
}

// 创建问题请求
struct CreateQuestionRequest: Codable {
    let latitude: Double
    let longitude: Double
    let locationName: String
    let actualPlace: String?
    let title: String
    let content: String
    let userId: Int64
}

// 创建问题响应
struct CreateQuestionResponse: Codable {
    let success: Bool
    let message: String?
    let question: QuestionWithLocation?
}




// MARK: - NetworkManager 扩展 - 新增问题相关方法

extension NetworkManager {
    
    // MARK: - 创建问题
    func createQuestion(
        latitude: Double,
        longitude: Double,
        locationName: String,
        actualPlace: String? = nil,
        title: String,
        content: String,
        userId: Int64
    ) async throws -> CreateQuestionResponse {
        guard let url = URL(string: "\(baseURL)/question/create-question") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let createQuestionRequest = CreateQuestionRequest(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            actualPlace: actualPlace,
            title: title,
            content: content,
            userId: userId
        )
        
        request.httpBody = try JSONEncoder().encode(createQuestionRequest)
        
        print("🌐 发送创建问题请求: userId=\(userId), title=\(title.prefix(20))...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 创建问题响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(CreateQuestionResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode == 404 {
                    let errorResponse = try JSONDecoder().decode(CreateQuestionResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let createQuestionResponse = try JSONDecoder().decode(CreateQuestionResponse.self, from: data)
            
            if createQuestionResponse.success {
                print("🌐 问题创建成功: \(createQuestionResponse.question?.title ?? "未知问题")")
            } else {
                print("🌐 问题创建失败: \(createQuestionResponse.message ?? "未知错误")")
            }
            
            return createQuestionResponse
            
        } catch let error as DecodingError {
            print("🌐 创建问题响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 创建问题网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - 获取用户创建的问题列表
    func getUserQuestions(
        userId: Int64,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> GetUserQuestionsResponse {
        guard let url = URL(string: "\(baseURL)/question/get-user-questions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let getUserQuestionsRequest = GetUserQuestionsRequest(
            userId: userId,
            page: page,
            pageSize: pageSize
        )
        
        request.httpBody = try JSONEncoder().encode(getUserQuestionsRequest)
        
        print("🌐 发送获取用户问题请求: userId=\(userId), page=\(page)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 获取用户问题响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(GetUserQuestionsResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let getUserQuestionsResponse = try JSONDecoder().decode(GetUserQuestionsResponse.self, from: data)
            
            if getUserQuestionsResponse.success {
                print("🌐 获取用户问题成功: \(getUserQuestionsResponse.questions.count) 个问题")
            }
            
            return getUserQuestionsResponse
            
        } catch let error as DecodingError {
            print("🌐 获取用户问题响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 获取用户问题网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}

// 带3D位置的问题创建请求
struct CreateQuestionWith3DPositionRequest: Codable {
    let latitude: Double
    let longitude: Double
    let locationName: String
    let actualPlace: String?
    let title: String
    let content: String
    let userId: Int64
    let position3D: Position3DRequest
}

struct Position3DRequest: Codable {
    let x: Float
    let y: Float
    let z: Float
    
    init(from simd: SIMD3<Float>) {
        self.x = simd.x
        self.y = simd.y
        self.z = simd.z
    }
}

// 带3D位置的问题创建响应
struct CreateQuestionWith3DPositionResponse: Codable {
    let success: Bool
    let message: String?
    let question: QuestionWithLocation?
    let questionId: Int64?
    let real3DViewId: Int64?
    let position3D: Position3D?
}

// MARK: - NetworkManager扩展 - 新增带3D位置的问题创建方法

extension NetworkManager {
    
    // 创建带3D位置的问题
    func createQuestionWith3DPosition(
        latitude: Double,
        longitude: Double,
        locationName: String,
        actualPlace: String? = nil,
        title: String,
        content: String,
        userId: Int64,
        position3D: SIMD3<Float>
    ) async throws -> CreateQuestionWith3DPositionResponse {
        guard let url = URL(string: "\(baseURL)/question/create-question-with-3d-position") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let createQuestionRequest = CreateQuestionWith3DPositionRequest(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            actualPlace: actualPlace,
            title: title,
            content: content,
            userId: userId,
            position3D: Position3DRequest(from: position3D)
        )
        
        request.httpBody = try JSONEncoder().encode(createQuestionRequest)
        
        print("🌐 发送创建带3D位置问题请求: userId=\(userId), title=\(title.prefix(20))..., position=\(position3D)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 创建带3D位置问题响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(CreateQuestionWith3DPositionResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode == 404 {
                    let errorResponse = try JSONDecoder().decode(CreateQuestionWith3DPositionResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let createQuestionResponse = try JSONDecoder().decode(CreateQuestionWith3DPositionResponse.self, from: data)
            
            if createQuestionResponse.success {
                print("🌐 带3D位置问题创建成功: questionId=\(createQuestionResponse.questionId ?? 0), real3DViewId=\(createQuestionResponse.real3DViewId ?? 0)")
            } else {
                print("🌐 带3D位置问题创建失败: \(createQuestionResponse.message ?? "未知错误")")
            }
            
            return createQuestionResponse
            
        } catch let error as DecodingError {
            print("🌐 创建带3D位置问题响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 创建带3D位置问题网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}

// MARK: - 为了兼容性，也需要更新CreateQuestionResponse结构
extension CreateQuestionResponse {
    // 创建一个从CreateQuestionWith3DPositionResponse转换的便利初始化器
    init(from response: CreateQuestionWith3DPositionResponse) {
        self.success = response.success
        self.message = response.message
        self.question = response.question
    }
}
