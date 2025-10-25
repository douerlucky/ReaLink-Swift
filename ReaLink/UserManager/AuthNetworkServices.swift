//
//  AuthNetworkServices.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/9/1.
//

import Foundation
import UIKit

// MARK: - 认证模块 (Authentication Module)

// 登录请求/响应
struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let success: Bool
    let message: String?
    let user: User?
    let token: String?
}

// 注册请求/响应
struct RegisterRequest: Codable {
    let username: String
    let password: String
    let avatarUrl: String?
}

struct RegisterResponse: Codable {
    let success: Bool
    let message: String?
    let user: User?
}

// 用户信息更新
struct UpdateProfileRequest: Codable {
    let userId: Int64
    let username: String
    let avatarUrl: String?
}

struct UpdateProfileResponse: Codable {
    let success: Bool
    let message: String?
    let user: User?
}

struct GetUserInfoRequest: Codable {
    let userId: Int64
}

struct GetUserInfoResponse: Codable {
    let success: Bool
    let message: String?
    let user: User?
}

// 检查用户名可用性
struct CheckUsernameRequest: Codable {
    let username: String
    let currentUserId: Int64?
}

struct CheckUsernameResponse: Codable {
    let success: Bool
    let available: Bool
    let message: String?
}

// 上传头像响应
struct UploadAvatarResponse: Codable {
    let success: Bool
    let message: String?
    let avatarUrl: String?
    let user: User?
}

extension NetworkManager{
    
    // MARK: - 认证相关方法
    
    func login(username: String, password: String) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginRequest = LoginRequest(username: username, password: password)
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        print("🌐 发送登录请求: username=\(username)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 登录响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    let errorResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            
            if loginResponse.success {
                print("🌐 登录成功: \(loginResponse.user?.username ?? "Unknown")")
            } else {
                print("🌐 登录失败: \(loginResponse.message ?? "未知错误")")
            }
            
            return loginResponse
            
        } catch let error as DecodingError {
            print("🌐 登录响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 登录网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    func register(username: String, password: String, avatarUrl: String? = nil) async throws -> RegisterResponse {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let registerRequest = RegisterRequest(
            username: username,
            password: password,
            avatarUrl: avatarUrl
        )
        request.httpBody = try JSONEncoder().encode(registerRequest)
        
        print("🌐 发送注册请求: username=\(username)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 注册响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 409 {
                    let errorResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
            
            if registerResponse.success {
                print("🌐 注册成功")
            } else {
                print("🌐 注册失败: \(registerResponse.message ?? "未知错误")")
            }
            
            return registerResponse
            
        } catch let error as DecodingError {
            print("🌐 注册响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 注册网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    func updateUserProfile(userId: Int64, username: String, avatarUrl: String? = nil) async throws -> UpdateProfileResponse {
        guard let url = URL(string: "\(baseURL)/auth/update-profile") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let updateRequest = UpdateProfileRequest(
            userId: userId,
            username: username,
            avatarUrl: avatarUrl
        )
        request.httpBody = try JSONEncoder().encode(updateRequest)
        
        print("🌐 发送更新用户资料请求: userId=\(userId), username=\(username)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 更新资料响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("用户不存在")
                } else if httpResponse.statusCode == 409 {
                    let errorResponse = try JSONDecoder().decode(UpdateProfileResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let updateResponse = try JSONDecoder().decode(UpdateProfileResponse.self, from: data)
            
            if updateResponse.success {
                print("🌐 用户资料更新成功")
            } else {
                print("🌐 用户资料更新失败: \(updateResponse.message ?? "未知错误")")
            }
            
            return updateResponse
            
        } catch let error as DecodingError {
            print("🌐 更新资料响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 更新资料网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
   
    
    // MARK: - 新增：检查用户名可用性
    
    func checkUsernameAvailability(username: String, currentUserId: Int64? = nil) async throws -> CheckUsernameResponse {
        guard let url = URL(string: "\(baseURL)/auth/check-username") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let checkRequest = CheckUsernameRequest(
            username: username,
            currentUserId: currentUserId
        )
        request.httpBody = try JSONEncoder().encode(checkRequest)
        
        print("🔍 检查用户名可用性: username=\(username)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 检查用户名响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let checkResponse = try JSONDecoder().decode(CheckUsernameResponse.self, from: data)
            
            if checkResponse.success {
                print("🔍 用户名检查结果: \(checkResponse.available ? "可用" : "不可用")")
            }
            
            return checkResponse
            
        } catch let error as DecodingError {
            print("🔍 检查用户名响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🔍 检查用户名网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - 新增：上传头像
    
    func uploadAvatar(image: UIImage, userId: Int64) async throws -> UploadAvatarResponse {
        guard let url = URL(string: "\(baseURL)/auth/upload-avatar") else {
            throw NetworkError.invalidURL
        }
        
        // 压缩图片
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.serverError("图片压缩失败")
        }
        
        // 创建 multipart/form-data 请求
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // 添加用户ID字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        
        // 添加图片文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📷 上传头像: userId=\(userId), imageSize=\(imageData.count)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📷 上传头像响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let uploadResponse = try JSONDecoder().decode(UploadAvatarResponse.self, from: data)
            
            if uploadResponse.success {
                print("📷 头像上传成功: \(uploadResponse.avatarUrl ?? "")")
            } else {
                print("📷 头像上传失败: \(uploadResponse.message ?? "未知错误")")
            }
            
            return uploadResponse
            
        } catch let error as DecodingError {
            print("📷 上传头像响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("📷 上传头像网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}

struct UserStatsResponse: Codable {
    let success: Bool
    let stats: UserStats?
    let message: String?
}

struct UserStats: Codable {
    let totalQuestions: Int
    let totalAnswers: Int
    let recentQuestions: [RecentQuestion]
    let recentAnswers: [RecentAnswer]
}

struct RecentQuestion: Codable {
    let id: Int64
    let title: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
    }
}

struct RecentAnswer: Codable {
    let id: Int64
    let title: String
    let answerTime: String
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case answerTime = "answer_time"
    }
}

// 用户问题列表请求/响应
struct GetUserQuestionsRequest: Codable {
    let userId: Int64
    let page: Int?
    let pageSize: Int?
}

struct GetUserQuestionsResponse: Codable {
    let success: Bool
    let questions: [QuestionWithLocation]
    let pagination: PaginationInfo
    let message: String?
}

// 用户回答问题请求/响应
struct GetUserAnsweredQuestionsRequest: Codable {
    let userId: Int64
    let page: Int?
    let pageSize: Int?
}

struct GetUserAnsweredQuestionsResponse: Codable {
    let success: Bool
    let questions: [QuestionWithLocation]
    let pagination: PaginationInfo
    let message: String?
}

struct GetUserStatsRequest: Codable {
    let userId: Int64
}

// 分页信息
struct PaginationInfo: Codable {
    let page: Int
    let pageSize: Int
    let total: Int
    let totalPages: Int
}

// NetworkManager 扩展
extension NetworkManager {
    
    // 获取用户统计信息
    func getUserStats(userId: Int64) async throws -> UserStats {
        guard let url = URL(string: "\(baseURL)/question/get-user-stats") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = GetUserStatsRequest(userId: userId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("📊 获取用户统计信息请求: userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 统计信息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let statsResponse = try JSONDecoder().decode(UserStatsResponse.self, from: data)
            
            if statsResponse.success, let stats = statsResponse.stats {
                print("📊 获取用户统计成功: 问题\(stats.totalQuestions)个, 回答\(stats.totalAnswers)个")
                return stats
            } else {
                throw NetworkError.serverError(statsResponse.message ?? "获取统计信息失败")
            }
            
        } catch let error as DecodingError {
            print("📊 统计信息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("📊 获取统计信息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    
    // 获取用户回答过的问题列表
    func getUserAnsweredQuestions(
        userId: Int64,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> GetUserAnsweredQuestionsResponse {
        guard let url = URL(string: "\(baseURL)/question/get-user-answered-questions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = GetUserAnsweredQuestionsRequest(
            userId: userId,
            page: page,
            pageSize: pageSize
        )
        
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("💬 获取用户回答问题请求: userId=\(userId), page=\(page)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("💬 回答问题响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let answeredQuestionsResponse = try JSONDecoder().decode(GetUserAnsweredQuestionsResponse.self, from: data)
            
            if answeredQuestionsResponse.success {
                print("💬 获取用户回答问题成功: \(answeredQuestionsResponse.questions.count)个问题")
            }
            
            return answeredQuestionsResponse
            
        } catch let error as DecodingError {
            print("💬 回答问题响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("💬 获取用户回答问题网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}

// 在 AuthNetworkServices.swift 文件中添加以下内容

// MARK: - 位置相关请求/响应模型
struct UpdateLocationRequest: Codable {
    let userId: Int64
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let timestamp: String?
}

struct UpdateLocationResponse: Codable {
    let success: Bool
    let message: String?
}

struct GetLocationRequest: Codable {
    let userId: Int64
}

struct GetLocationResponse: Codable {
    let success: Bool
    let location: UserLocation?
    let message: String?
}

struct UserLocation: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let updatedAt: String?
}

// MARK: - NetworkManager 位置功能扩展
extension NetworkManager {
    
    // 更新用户位置
    func updateUserLocation(
        userId: Int64,
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil
    ) async throws -> UpdateLocationResponse {
        guard let url = URL(string: "\(baseURL)/auth/update-location") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let locationRequest = UpdateLocationRequest(
            userId: userId,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        
        request.httpBody = try JSONEncoder().encode(locationRequest)
        
        print("📍 发送位置更新请求: userId=\(userId), lat=\(latitude), lng=\(longitude)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📍 位置更新响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("用户不存在")
                } else if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(UpdateLocationResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let locationResponse = try JSONDecoder().decode(UpdateLocationResponse.self, from: data)
            
            if locationResponse.success {
                print("📍 位置更新成功")
            } else {
                print("📍 位置更新失败: \(locationResponse.message ?? "未知错误")")
            }
            
            return locationResponse
            
        } catch let error as DecodingError {
            print("📍 位置更新响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("📍 位置更新网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // 获取用户位置
    func getUserLocation(userId: Int64) async throws -> UserLocation {
        guard let url = URL(string: "\(baseURL)/auth/get-user-location") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let locationRequest = GetLocationRequest(userId: userId)
        request.httpBody = try JSONEncoder().encode(locationRequest)
        
        print("📍 发送获取位置请求: userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📍 获取位置响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("用户位置信息不存在")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let locationResponse = try JSONDecoder().decode(GetLocationResponse.self, from: data)
            
            if locationResponse.success, let location = locationResponse.location {
                print("📍 获取位置成功: (\(location.latitude), \(location.longitude))")
                return location
            } else {
                throw NetworkError.serverError(locationResponse.message ?? "获取位置失败")
            }
            
        } catch let error as DecodingError {
            print("📍 获取位置响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("📍 获取位置网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}
