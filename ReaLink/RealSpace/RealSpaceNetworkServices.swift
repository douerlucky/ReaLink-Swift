//
//  RealSpaceNetworkServices.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/9/1.
//

import Foundation

// MARK: - 3D空间模块 (RealSpace Module)

// 3D视图相关
struct View3DRequest: Codable {
    let locationId: Int64
}

struct View3DResponse: Codable {
    let success: Bool
    let locationId: Int64
    let locationName: String
    let has3DView: Bool
    let view3D: View3DData?
}

struct View3DData: Codable {
    let id: Int64
    let name: String
    let fileURL: String
    let createdAt: String
    let updatedAt: String
}

// 3D视图问题
struct Get3DViewQuestionsRequest: Codable {
    let real3DViewId: Int64
}

struct Get3DViewQuestionsResponse: Codable {
    let success: Bool
    let real3DViewId: Int64
    let questionCount: Int
    let questions: [QuestionWith3DPosition]
}

struct QuestionWith3DPosition: Codable, Identifiable {
    let id: Int64
    let locationId: Int64
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
    let position: Position3D
    let view3DName: String
}

struct Position3D: Codable {
    let x: Float
    let y: Float
    let z: Float
    
    var simd3: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}

struct Get3DViewIdByLocationRequest: Codable {
    let locationId: Int64
}

struct Get3DViewIdByLocationResponse: Codable {
    let success: Bool
    let locationId: Int64
    let real3DViewId: Int64?
    let view3DName: String?
    let fileURL: String?
    let message: String?
}

// 空间绘画相关
struct UploadPaintingRequest: Codable {
    let locationId: Int64?
    let questionId: Int64?
    let userId: Int64? // 新增字段
    let paintingData: String
}

struct UploadPaintingResponse: Codable {
    let success: Bool
    let paintingId: Int64?
    let paintingURL: String?
    let message: String?
}

struct DownloadPaintingRequest: Codable {
    let locationId: Int64?
    let questionId: Int64?
    let userId: Int64? // 新增字段
}


struct DownloadPaintingResponse: Codable {
    let success: Bool
    let paintingData: String?
    let paintingURL: String?
    let createdAt: String?
    let message: String?
}

struct CheckPaintingRequest: Codable {
    let locationId: Int64?
    let questionId: Int64?
    let userId: Int64? // 新增字段
}

struct CheckPaintingResponse: Codable {
    let exists: Bool
    let paintingId: Int64?
    let createdAt: String?
}

// 3D模型相关

struct Upload3DModelsRequest: Codable {
    let locationId: Int64?
    let questionId: Int64?
    let userId: Int64? // 新增字段
    let modelsData: String
}

struct Upload3DModelsResponse: Codable {
    let success: Bool
    let modelId: Int64?
    let modelURL: String?
    let message: String?
}

struct Download3DModelsRequest: Codable {
    let locationId: Int64?
    let questionId: Int64?
    let userId: Int64? // 新增字段
}

struct Download3DModelsResponse: Codable {
    let success: Bool
    let modelsData: String?
    let modelURL: String?
    let createdAt: String?
    let message: String?
}

struct Check3DModelsRequest: Codable {
    let locationId: Int64?
    let questionId: Int64?
    let userId: Int64? // 新增字段
}

struct Check3DModelsResponse: Codable {
    let exists: Bool
    let modelId: Int64?
    let createdAt: String?
}


extension NetworkManager
{
    // MARK: - 空间绘画方法
    
    func uploadPaintingData(_ jsonData: Data, locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async throws {
        guard let url = URL(string: "\(baseURL)/realspace/spatial-painting/upload-spatial-painting") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Data = jsonData.base64EncodedString()
        
        let requestBody = UploadPaintingRequest(
            locationId: locationId,
            questionId: questionId,
            userId: userId, // 新增userId字段
            paintingData: base64Data
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("🌐 上传空间画作: locationId=\(locationId ?? 0), questionId=\(questionId ?? 0), userId=\(userId ?? 0)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 上传响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(UploadPaintingResponse.self, from: data)
            
            if responseData.success {
                print("🌐 空间画作上传成功: ID=\(responseData.paintingId ?? 0), URL=\(responseData.paintingURL ?? "")")
            } else {
                throw NetworkError.serverError(responseData.message ?? "上传失败")
            }
            
        } catch let error as DecodingError {
            print("🌐 解析上传响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 上传空间画作失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    func downloadPaintingData(locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async throws -> SpatialPaintingData {
        guard let url = URL(string: "\(baseURL)/realspace/spatial-painting/download-spatial-painting") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = DownloadPaintingRequest(
            locationId: locationId,
            questionId: questionId,
            userId: userId // 新增userId字段
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("🌐 下载空间画作: locationId=\(locationId ?? 0), questionId=\(questionId ?? 0), userId=\(userId ?? 0)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 下载响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("未找到空间画作数据")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(DownloadPaintingResponse.self, from: data)
            
            if responseData.success, let base64Data = responseData.paintingData {
                guard let jsonData = Data(base64Encoded: base64Data) else {
                    throw NetworkError.decodingError
                }
                
                let paintingData = try JSONDecoder().decode(SpatialPaintingData.self, from: jsonData)
                
                print("🌐 空间画作下载成功: \(paintingData.strokes.count) 个笔画")
                return paintingData
                
            } else {
                throw NetworkError.serverError(responseData.message ?? "下载失败")
            }
            
        } catch let error as DecodingError {
            print("🌐 解析下载响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 下载空间画作失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }

    func checkPaintingExists(locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/realspace/spatial-painting/check-spatial-painting") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = CheckPaintingRequest(
            locationId: locationId,
            questionId: questionId,
            userId: userId // 新增userId字段
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return false
                }
            }
            
            let responseData = try JSONDecoder().decode(CheckPaintingResponse.self, from: data)
            return responseData.exists
            
        } catch {
            print("🌐 检查空间画作存在性失败: \(error)")
            return false
        }
    }
    // MARK: - 3D模型方法
    
    func upload3DModels(_ jsonData: Data, locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async throws {
        guard let url = URL(string: "\(baseURL)/realspace/3d-models/upload-3d-models") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Data = jsonData.base64EncodedString()
        
        let requestBody = Upload3DModelsRequest(
            locationId: locationId,
            questionId: questionId,
            userId: userId, // 新增userId字段
            modelsData: base64Data
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("🧊 上传3D模型: locationId=\(locationId ?? 0), questionId=\(questionId ?? 0), userId=\(userId ?? 0)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🧊 上传响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(Upload3DModelsResponse.self, from: data)
            
            if responseData.success {
                print("🧊 3D模型上传成功: ID=\(responseData.modelId ?? 0), URL=\(responseData.modelURL ?? "")")
            } else {
                throw NetworkError.serverError(responseData.message ?? "上传失败")
            }
            
        } catch let error as DecodingError {
            print("🧊 解析上传响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🧊 上传3D模型失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }

    func download3DModels(locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async throws -> ThreeDModelsData {
        guard let url = URL(string: "\(baseURL)/realspace/3d-models/download-3d-models") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = Download3DModelsRequest(
            locationId: locationId,
            questionId: questionId,
            userId: userId // 新增userId字段
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("🧊 下载3D模型: locationId=\(locationId ?? 0), questionId=\(questionId ?? 0), userId=\(userId ?? 0)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🧊 下载响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("未找到3D模型数据")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(Download3DModelsResponse.self, from: data)
            
            if responseData.success, let base64Data = responseData.modelsData {
                guard let jsonData = Data(base64Encoded: base64Data) else {
                    throw NetworkError.decodingError
                }
                
                let modelsData = try JSONDecoder().decode(ThreeDModelsData.self, from: jsonData)
                
                print("🧊 3D模型下载成功: \(modelsData.models.count) 个模型")
                return modelsData
                
            } else {
                throw NetworkError.serverError(responseData.message ?? "下载失败")
            }
            
        } catch let error as DecodingError {
            print("🧊 解析下载响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🧊 下载3D模型失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    func check3DModelsExists(locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async -> Bool {
        guard let url = URL(string: "\(baseURL)/realspace/3d-models/check-3d-models") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = Check3DModelsRequest(
            locationId: locationId,
            questionId: questionId,
            userId: userId // 新增userId字段
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return false
                }
            }
            
            let responseData = try JSONDecoder().decode(Check3DModelsResponse.self, from: data)
            return responseData.exists
            
        } catch {
            print("🧊 检查3D模型存在性失败: \(error)")
            return false
        }
    }
    #if DEBUG
    func createTestUsers() async throws {
        guard let url = URL(string: "\(baseURL)/auth/create-test-users") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🌐 发送创建测试用户请求")
        
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 创建测试用户响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 创建测试用户网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    #endif
    
    
    // MARK: - Location Detail Response Models
    struct GetLocationInfoRequest: Codable {
        let locationId: Int64
    }

    struct GetLocationInfoResponse: Codable {
        let success: Bool
        let location: LocationDetail?
        let message: String?
    }

    struct LocationDetail: Codable {
        let id: Int64
        let name: String
        let longitude: Double
        let latitude: Double
        let questionCount: Int
        let createdAt: String
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id, name, longitude, latitude
            case questionCount = "question_count"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
        
        func toLocationInfo() -> LocationInfo {
            return LocationInfo(
                id: self.id,
                name: self.name,
                latitude: self.latitude,
                longitude: self.longitude
            )
        }
    }

    // MARK: - Add this method to the NetworkManager class in NetworkServices.swift

    func getLocationInfo(locationId: Int64) async throws -> LocationDetail {
        guard let url = URL(string: "\(baseURL)/locations/\(locationId)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("🌍 获取位置信息请求: locationId=\(locationId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌍 位置信息响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("位置不存在")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let locationResponse = try JSONDecoder().decode(GetLocationInfoResponse.self, from: data)
            
            if locationResponse.success, let location = locationResponse.location {
                print("🌍 获取位置信息成功: \(location.name)")
                return location
            } else {
                throw NetworkError.serverError(locationResponse.message ?? "获取位置信息失败")
            }
            
        } catch let error as DecodingError {
            print("🌍 位置信息响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌍 获取位置信息网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }


}

extension NetworkManager{
    // MARK: - 3D空间相关方法 (RealSpace Methods)
    
    func fetch3DView(for locationId: Int64) async throws -> View3DData {
        guard let url = URL(string: "\(baseURL)/realspace/get-3d-view") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = View3DRequest(locationId: locationId)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("🌐 发送3D视图请求: locationId=\(locationId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.no3DView
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(View3DResponse.self, from: data)
            
            if responseData.success, let view3D = responseData.view3D {
                print("🌐 成功获取3D视图: \(view3D.name), URL: \(view3D.fileURL)")
                return view3D
            } else {
                throw NetworkError.no3DView
            }
            
        } catch let error as DecodingError {
            print("🌐 解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌐 网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    func get3DViewQuestions(real3DViewId: Int64) async throws -> Get3DViewQuestionsResponse {
        guard let url = URL(string: "\(baseURL)/realspace/get-3d-view-questions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = Get3DViewQuestionsRequest(real3DViewId: real3DViewId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🌌 获取3D视图问题请求: real3DViewId=\(real3DViewId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌌 3D视图问题响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(Get3DViewQuestionsResponse.self, from: data)
            
            if responseData.success {
                print("🌌 获取到 \(responseData.questionCount) 个3D视图问题")
            } else {
                throw NetworkError.serverError("获取3D视图问题失败")
            }
            
            return responseData
            
        } catch let error as DecodingError {
            print("🌌 解析3D视图问题响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌌 获取3D视图问题网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    func get3DViewIdByLocation(locationId: Int64) async throws -> Get3DViewIdByLocationResponse {
        guard let url = URL(string: "\(baseURL)/realspace/get-3d-view-id-by-location") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = Get3DViewIdByLocationRequest(locationId: locationId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🌌 根据位置获取3D视图ID请求: locationId=\(locationId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌌 3D视图ID响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    let responseData = try JSONDecoder().decode(Get3DViewIdByLocationResponse.self, from: data)
                    return responseData
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(Get3DViewIdByLocationResponse.self, from: data)
            
            if responseData.success {
                print("🌌 获取3D视图ID成功: \(responseData.real3DViewId ?? 0)")
            }
            
            return responseData
            
        } catch let error as DecodingError {
            print("🌌 解析3D视图ID响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🌌 获取3D视图ID网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}




// MARK: - 检查位置3D视图存在性相关模型
struct CheckLocation3DViewRequest: Codable {
    let locationId: Int64
}

struct CheckLocation3DViewResponse: Codable {
    let success: Bool
    let locationId: Int64
    let has3DView: Bool
    let view3DInfo: Location3DViewInfo?
    let message: String?
}

struct Location3DViewInfo: Codable {
    let id: Int64
    let name: String
    let fileURL: String
}

// MARK: - NetworkManager扩展 - 添加检查3D视图方法
extension NetworkManager {
    
    // 检查位置是否有3D视图数据
    func checkLocationHas3DView(locationId: Int64) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/realspace/check-location-has-3d-view") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = CheckLocation3DViewRequest(locationId: locationId)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("🌌 检查位置3D视图存在性请求: locationId=\(locationId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌌 3D视图检查响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    return false // 出错时默认返回false
                }
            }
            
            let responseData = try JSONDecoder().decode(CheckLocation3DViewResponse.self, from: data)
            
            if responseData.success {
                print("🌌 3D视图检查完成: locationId=\(locationId), has3DView=\(responseData.has3DView)")
                return responseData.has3DView
            } else {
                print("🌌 3D视图检查失败: \(responseData.message ?? "未知错误")")
                return false
            }
            
        } catch let error as DecodingError {
            print("🌌 解析3D视图检查响应错误: \(error)")
            return false // 解析失败时默认返回false
        } catch {
            print("🌌 检查3D视图网络请求失败: \(error)")
            return false // 网络请求失败时默认返回false
        }
    }
}

struct Get3DViewThumbnailRequest: Codable {
    let locationId: Int64
    let width: Int?
    let height: Int?
}

struct Get3DViewThumbnailResponse: Codable {
    let success: Bool
    let locationId: Int64
    let thumbnail: String?  // base64编码的图片数据
    let originalURL: String?
    let message: String?
}

extension NetworkManager {
    func get3DViewThumbnail(locationId: Int64, width: Int = 300, height: Int = 180) async throws -> String {
        guard let url = URL(string: "\(baseURL)/realspace/get-3d-view-thumbnail") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = Get3DViewThumbnailRequest(
            locationId: locationId,
            width: width,
            height: height
        )
        
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🖼️ 请求3D视图缩略图: locationId=\(locationId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🖼️ 缩略图响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.no3DView
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(Get3DViewThumbnailResponse.self, from: data)
            
            if responseData.success, let thumbnail = responseData.thumbnail {
                print("✅ 成功获取3D视图缩略图")
                return thumbnail
            } else {
                throw NetworkError.serverError(responseData.message ?? "获取缩略图失败")
            }
            
        } catch let error as DecodingError {
            print("🖼️ 解析缩略图响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🖼️ 获取缩略图网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}
