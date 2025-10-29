import Foundation

let backendURL = "http://192.168.3.132:3000"
//192.168.3.132
// 真机http://172.20.10.3:3000
// 否则http://localhost:3000

// MARK: - 网络错误类型
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case no3DView
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL"
        case .noData: return "没有数据"
        case .decodingError: return "数据解析失败"
        case .serverError(let message): return "服务器错误: \(message)"
        case .no3DView: return "该位置暂无3D视图数据"
        }
    }
}

// MARK: - 基础数据模型 (Core Data Models)

// 用户相关模型
struct User: Codable, Identifiable {
    let id: Int64
    let username: String
    let avatarUrl: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarUrl = "avatarUrl"     // 改成这样，因为JSON中就是avatarUrl
        case createdAt = "createdAt"     // 同样改成camelCase
        case updatedAt = "updatedAt"     // 同样改成camelCase
    }
}

// 问题模型
struct Question: Codable, Identifiable {
    let id: Int64
    let locationID: Int64
    let userID: Int64
    let actualPlace: String
    let title: String
    let content: String
    let replyCount: Int
    let status: String
    let createdAt: String
    let updatedAt: String
    let username: String?
    let avatarUrl: String?
   
    enum CodingKeys: String, CodingKey {
        case id, title, content, status
        case locationID = "locationId"
        case userID = "userId"
        case actualPlace = "actualPlace"
        case replyCount = "replyCount"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
        case username = "username"
        case avatarUrl = "avatarUrl"
    }
}

// 答案模型
struct AnswerData: Codable, Identifiable {
    let id: Int64
    let userId: Int64
    let username: String
    let avatarUrl: String?
    let content: String
    let createdAt: String
    let updatedAt: String
}

// 位置模型
struct LocationInfo: Codable, Identifiable {
    let id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
}

// MARK: - 位置模块 (Location Module)

// 位置坐标
struct LocationCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    let name: String?
}

// 位置检查
struct LocationCheckRequest: Codable {
    let locations: [LocationCoordinate]
}

struct LocationCheckResponse: Codable {
    let results: [LocationResult]
}

struct LocationResult: Codable {
    let latitude: Double
    let longitude: Double
    let hasQuestions: Bool
    let name: String?
}

// 附近问题搜索
struct NearbyQuestionsRequest: Codable {
    let centerLatitude: Double
    let centerLongitude: Double
    let radiusMeters: Double
}

struct NearbyQuestionsResponse: Codable {
    let centerLatitude: Double
    let centerLongitude: Double
    let radiusMeters: Double
    let locationsWithQuestions: [LocationWithQuestions]
    let totalFound: Int
}

struct LocationWithQuestions: Codable {
    let id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
    let questionCount: Int
    let distance: Int
}

// MARK: - 问答模块 (Q&A Module)

// 问题相关
struct LocationQuestionsRequest: Codable {
    let locationId: Int64
}

struct LocationQuestionsResponse: Codable {
    let success: Bool
    let locationId: Int64
    let questionCount: Int
    let questions: [Question]
}

// 获取问题答案
struct getQuestionAnswerRequest: Codable {
    let questionid: Int64
}

struct getQuestionAnswerResponse: Codable {
    let success: Bool
    let questionId: Int64
    let questionTitle: String?      // 改为可选，防止服务器不返回时解码失败
    let questionContent: String?    // 改为可选，防止服务器不返回时解码失败
    let answerCount: Int
    let answers: [AnswerData]
}

// 发送答案
struct SendAnswerRequest: Codable {
    let questionId: Int64
    let userId: Int64
    let content: String
}

struct SendAnswerResponse: Codable {
    let success: Bool
    let message: String?
    let answer: AnswerInfo?
    let questionTitle: String?
}

struct AnswerInfo: Codable {
    let id: Int64
    let questionId: Int64
    let userId: Int64
    let username: String
    let content: String
    let createdAt: String
    let updatedAt: String
}

// 获取所有问答
struct GetAllQuestionsRequest: Codable {
    let searchQuery: String?
    let sortBy: String?
    let sortOrder: String?
}

struct GetAllQuestionsResponse: Codable {
    let success: Bool
    let questions: [QuestionWithLocation]
    let total: Int
    let search: SearchInfo
    let sorting: SortingInfo
    let message: String?
}

struct QuestionWithLocation: Codable, Identifiable {
    let id: Int64
    let locationId: Int64?
    let userId: Int64
    let actualPlace: String
    let title: String
    let content: String
    let replyCount: Int
    let status: String
    let createdAt: String
    let updatedAt: String
    let username: String
    let avatarUrl: String?
    let locationName: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    
    func toQuestion() -> Question {
        return Question(
            id: self.id,
            locationID: self.locationId ?? 0,
            userID: self.userId,
            actualPlace: self.actualPlace,
            title: self.title,
            content: self.content,
            replyCount: self.replyCount,
            status: self.status,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            username: self.username,
            avatarUrl: self.avatarUrl
        )
    }
}

struct SearchInfo: Codable {
    let query: String?
    let resultsCount: Int
}

struct SortingInfo: Codable {
    let sortBy: String
    let sortOrder: String
}


// MARK: - 统计模块 (Statistics Module)

struct QuestionsStatisticsResponse: Codable {
    let totalQuestions: Int
    let totalAnswers: Int
    let activeUsers: Int
    let averageRepliesPerQuestion: String
    let locationStatistics: [LocationQuestionStats]
    let timestamp: String
}

struct LocationQuestionStats: Codable {
    let locationName: String
    let questionCount: Int
    let totalReplies: Int
    
    enum CodingKeys: String, CodingKey {
        case locationName = "location_name"
        case questionCount = "question_count"
        case totalReplies = "total_replies"
    }
}

// MARK: - 网络服务类 (Network Services)


// 主网络管理器
@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    public let baseURL = backendURL
    public let session = URLSession.shared
    private var answerTasks: [Int64: URLSessionDataTask] = [:] // 存储问题ID对应的请求任务
    
    public init() {}
    // 获取问题答案的方法
       func getQuestionAnswers(questionId: Int64) async throws -> getQuestionAnswerResponse {
           // 取消相同问题ID的现有任务
           if let existingTask = answerTasks[questionId] {
               existingTask.cancel()
               print("🔄 取消重复的问题答案请求: questionId=\(questionId)")
           }
           
           guard let url = URL(string: "\(baseURL)/explore/question/get_answers") else {
               throw NetworkError.invalidURL
           }
           
           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.setValue("application/json", forHTTPHeaderField: "Content-Type")
           request.httpBody = try JSONEncoder().encode(getQuestionAnswerRequest(questionid: questionId))
           
           print("🌐 请求问题答案: questionId=\(questionId)")
           
           let task = session.dataTask(with: request) // 创建任务
           answerTasks[questionId] = task // 存储任务
           
           do {
               let (data, response) = try await session.data(for: request)
               answerTasks.removeValue(forKey: questionId) // 完成后移除任务
               
               if let httpResponse = response as? HTTPURLResponse {
                   print("🌐 响应状态码: \(httpResponse.statusCode)")
                   if httpResponse.statusCode != 200 {
                       throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                   }
               }
               
               let result = try JSONDecoder().decode(getQuestionAnswerResponse.self, from: data)
               print("🌐 获取到 \(result.answerCount) 个答案")
               return result
           } catch {
               answerTasks.removeValue(forKey: questionId) // 出错后移除任务
               throw error
           }
       }
    
    // MARK: - 位置相关方法 (Location Methods)
    
    func checkLocationsForQuestions(coordinates: [LocationCoordinate]) async throws -> LocationCheckResponse {
        guard let url = URL(string: "\(baseURL)/explore/check-locations") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = LocationCheckRequest(locations: coordinates)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(LocationCheckResponse.self, from: data)
    }
    
    func searchNearbyQuestions(centerLatitude: Double, centerLongitude: Double, radiusMeters: Double) async throws -> NearbyQuestionsResponse {
        guard let url = URL(string: "\(baseURL)/explore/nearby-questions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = NearbyQuestionsRequest(
            centerLatitude: centerLatitude,
            centerLongitude: centerLongitude,
            radiusMeters: radiusMeters
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(NearbyQuestionsResponse.self, from: data)
    }
    
    // MARK: - 问答相关方法 (Q&A Methods)
    
    func getLocationQuestions(locationId: Int64) async throws -> LocationQuestionsResponse {
        guard let url = URL(string: "\(baseURL)/explore/location/get-questions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = LocationQuestionsRequest(locationId: locationId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("网络请求获取位置问题: locationId=\(locationId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("获取位置问题响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(LocationQuestionsResponse.self, from: data)
            
            if responseData.success {
                print("获取到 \(responseData.questionCount) 个问题")
            } else {
                throw NetworkError.serverError("获取位置问题失败")
            }
            
            return responseData
            
        } catch let error as DecodingError {
            print("解析位置问题响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("获取位置问题网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    func getQuestionAnswer(question: Question) async throws -> getQuestionAnswerResponse {
        guard let url = URL(string:"\(baseURL)/explore/question/get_answers") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = getQuestionAnswerRequest(questionid: question.id)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🌐 请求问题答案: questionId=\(question.id)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 响应状态码: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let responseData = try JSONDecoder().decode(getQuestionAnswerResponse.self, from: data)
        
        if responseData.success {
            print("🌐 获取到 \(responseData.answerCount) 个答案")
        } else {
            throw NetworkError.serverError("获取问题答案失败")
        }
        
        return responseData
    }
    
    func sendAnswer(questionId: Int64, userId: Int64, content: String) async throws -> SendAnswerResponse {
        guard let url = URL(string: "\(baseURL)/explore/question/send-reply") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = SendAnswerRequest(
            questionId: questionId,
            userId: userId,
            content: content
        )
        
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("💬 发送回复请求: questionId=\(questionId), userId=\(userId), content=\(content.prefix(50))...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("💬 发送回复响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    let errorResponse = try JSONDecoder().decode(SendAnswerResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode == 400 {
                    let errorResponse = try JSONDecoder().decode(SendAnswerResponse.self, from: data)
                    return errorResponse
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let sendAnswerResponse = try JSONDecoder().decode(SendAnswerResponse.self, from: data)
            
            if sendAnswerResponse.success {
                print("💬 回复发送成功: answerId=\(sendAnswerResponse.answer?.id ?? 0)")
            } else {
                print("💬 回复发送失败: \(sendAnswerResponse.message ?? "未知错误")")
            }
            
            return sendAnswerResponse
            
        } catch let error as DecodingError {
            print("💬 发送回复响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("💬 发送回复网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    func getAllQuestions(searchQuery: String = "", sortBy: String = "created_at", sortOrder: String = "DESC") async throws -> GetAllQuestionsResponse {
        guard let url = URL(string: "\(baseURL)/explore/get-all-questions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = GetAllQuestionsRequest(
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            sortBy: sortBy,
            sortOrder: sortOrder
        )
        
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🌐 获取所有问答请求: search=\(searchQuery), sortBy=\(sortBy)")
        
        
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 获取问答响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let questionsResponse = try JSONDecoder().decode(GetAllQuestionsResponse.self, from: data)
            
            // 添加调试日志
            if questionsResponse.success {
                print("获取问答成功，检查头像数据:")
                for (index, question) in questionsResponse.questions.prefix(3).enumerated() {
                    print("问题 \(index + 1): \(question.username) - 头像URL: \(question.avatarUrl ?? "无")")
                }
            }
            
            
            return questionsResponse
            
        } catch let error as DecodingError {
            print("🌐 获取问答响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 获取问答网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    func getQuestionsStatistics() async throws -> QuestionsStatisticsResponse {
        guard let url = URL(string: "\(baseURL)/explore/questions-statistics") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("🌐 获取问答统计信息请求")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 统计信息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let statisticsResponse = try JSONDecoder().decode(QuestionsStatisticsResponse.self, from: data)
            
            print("🌐 获取统计信息成功: 总问答\(statisticsResponse.totalQuestions)个")
            
            return statisticsResponse
            
        } catch let error as DecodingError {
            print("🌐 统计信息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 获取统计信息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}
    
    
    // 在NetworkServices.swift中添加新的请求/响应模型
    struct FindNearestLocationRequest: Codable {
        let latitude: Double
        let longitude: Double
        let maxDistance: Double?
    }
    
struct FindNearestLocationResponse: Codable {
    let success: Bool
    let nearestLocation: NearestLocationInfo?
    let searchCoordinate: CoordinateInfo
    let questionCount: Int  // 保持必需，后端现在总是返回
    let questions: [Question]  // 保持必需，后端现在总是返回
    let message: String?
    
    // 🔧 添加自定义初始化器，提供默认值
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        success = try container.decode(Bool.self, forKey: .success)
        nearestLocation = try container.decodeIfPresent(NearestLocationInfo.self, forKey: .nearestLocation)
        searchCoordinate = try container.decode(CoordinateInfo.self, forKey: .searchCoordinate)
        questionCount = try container.decodeIfPresent(Int.self, forKey: .questionCount) ?? 0  // 默认值
        questions = try container.decodeIfPresent([Question].self, forKey: .questions) ?? []  // 默认值
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}
    
    struct NearestLocationInfo: Codable {
        let id: Int64
        let name: String
        let latitude: Double
        let longitude: Double
        let distance: Int
    }
    
    struct CoordinateInfo: Codable {
        let latitude: Double
        let longitude: Double
    }
    // 在NetworkManager中添加新方法
extension NetworkManager {
    func findNearestLocationQuestions(latitude: Double, longitude: Double, maxDistance: Double = 50) async throws -> FindNearestLocationResponse {
        guard let url = URL(string: "\(baseURL)/explore/find-nearest-location-questions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = FindNearestLocationRequest(
            latitude: latitude,
            longitude: longitude,
            maxDistance: maxDistance
        )
        
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🌍 查找最近位置的问题: (\(latitude), \(longitude))")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌍 响应状态码: \(httpResponse.statusCode)")
                
                // 🔧 改进：不管状态码如何，都尝试解析响应
                // 因为404也是有效的业务响应（未找到匹配位置）
            }
            
            // 🔧 添加调试：打印原始响应
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔧 原始JSON响应: \(jsonString)")
            }
            
            let nearestResponse = try JSONDecoder().decode(FindNearestLocationResponse.self, from: data)
            
            if nearestResponse.success {
                print("🌍 找到最近位置: \(nearestResponse.nearestLocation?.name ?? "未知"), \(nearestResponse.questionCount)个问题")
            } else {
                print("🌍 未找到匹配位置: \(nearestResponse.message ?? "未知原因")")
            }
            
            return nearestResponse
            
        } catch let error as DecodingError {
            print("🌍 解析响应错误: \(error)")
            
            // 🔧 提供详细的解析错误信息
            switch error {
            case .keyNotFound(let key, let context):
                print("❌ 缺少键: \(key.stringValue), 路径: \(context.codingPath)")
            case .typeMismatch(let type, let context):
                print("❌ 类型不匹配: 期望 \(type), 路径: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("❌ 值不存在: \(type), 路径: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("❌ 数据损坏: \(context.debugDescription)")
            @unknown default:
                print("❌ 未知解析错误")
            }
            
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌍 网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}

    
extension NetworkManager {
    func getUserInfo(userId: Int64) async throws -> GetUserInfoResponse {
        guard let url = URL(string: "\(baseURL)/auth/get-user-info") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let getUserRequest = ["userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: getUserRequest)
        
        print("🌐 发送获取用户信息请求: userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // 添加调试：打印原始JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 原始JSON响应: \(jsonString)")
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 获取用户信息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let userInfoResponse = try JSONDecoder().decode(GetUserInfoResponse.self, from: data)
            
            // 添加调试：打印解析后的数据
            if let user = userInfoResponse.user {
                print("🔍 解析后的用户数据:")
                print("  ID: \(user.id)")
                print("  用户名: \(user.username)")
                print("  头像URL: '\(user.avatarUrl ?? "nil")'")
            }
            
            if userInfoResponse.success {
                print("🌐 获取用户信息成功: \(userInfoResponse.user?.username ?? "Unknown")")
            }
            
            return userInfoResponse
            
        } catch let error as DecodingError {
            print("🌐 获取用户信息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 获取用户信息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}
