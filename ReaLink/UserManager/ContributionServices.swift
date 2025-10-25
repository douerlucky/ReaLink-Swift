// 在 BaseNetworkServices.swift 或新建 ContributionNetworkServices.swift 中添加

import Foundation

// MARK: - 用户贡献相关请求/响应模型

struct GetUserContributionsRequest: Codable {
    let userId: Int64
}

struct GetUserContributionsResponse: Codable {
    let success: Bool
    let contributions: [UserContributionData]
    let message: String?
}

struct UserContributionData: Codable {
    let id: Int64
    let locationId: Int64
    let locationName: String
    let fileURL: String
    let latitude: Double?
    let longitude: Double?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case locationId = "location_id"
        case locationName = "location_name"
        case fileURL
        case latitude
        case longitude
        case createdAt = "created_at"
    }
    
    func toUserContribution() -> UserContribution {
        return UserContribution(
            id: self.id,
            locationId: self.locationId,
            locationName: self.locationName,
            fileURL: self.fileURL,
            latitude: self.latitude,
            longitude: self.longitude,
            createdAt: self.createdAt
        )
    }
}

struct DeleteContributionRequest: Codable {
    let real3DViewId: Int64
    let userId: Int64
}

struct DeleteContributionResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - NetworkManager 扩展

extension NetworkManager {
    
    // 获取用户的3D贡献列表
    func getUserContributions(userId: Int64) async throws -> [UserContribution] {
        guard let url = URL(string: "\(baseURL)/realspace/get-user-contributions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = GetUserContributionsRequest(userId: userId)
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("📊 获取用户贡献请求: userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 用户贡献响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let contributionsResponse = try JSONDecoder().decode(GetUserContributionsResponse.self, from: data)
            
            if contributionsResponse.success {
                print("📊 获取用户贡献成功: \(contributionsResponse.contributions.count)个")
                return contributionsResponse.contributions.map { $0.toUserContribution() }
            } else {
                throw NetworkError.serverError(contributionsResponse.message ?? "获取用户贡献失败")
            }
            
        } catch let error as DecodingError {
            print("📊 用户贡献响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("📊 获取用户贡献网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    // 删除3D贡献
    func deleteContribution(real3DViewId: Int64, userId: Int64) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/realspace/delete-contribution") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = DeleteContributionRequest(
            real3DViewId: real3DViewId,
            userId: userId
        )
        request.httpBody = try JSONEncoder().encode(requestData)
        
        print("🗑️ 删除贡献请求: real3DViewId=\(real3DViewId), userId=\(userId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🗑️ 删除贡献响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 403 {
                    throw NetworkError.serverError("无权限删除此贡献")
                } else if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("贡献不存在")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let deleteResponse = try JSONDecoder().decode(DeleteContributionResponse.self, from: data)
            
            if deleteResponse.success {
                print("🗑️ 删除贡献成功")
                return true
            } else {
                throw NetworkError.serverError(deleteResponse.message ?? "删除贡献失败")
            }
            
        } catch let error as DecodingError {
            print("🗑️ 删除贡献响应解析错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("🗑️ 删除贡献网络请求失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}
