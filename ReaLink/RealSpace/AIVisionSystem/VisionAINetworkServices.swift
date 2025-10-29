//
//  VisionAINetworkServices_FIXED.swift
//  🔥 修复版：添加 questionId 支持，让AI知道当前场景和问题上下文
//

import Foundation

// MARK: - 场景识别相关数据结构

/// 场景识别请求（🔥 新增：questionId 字段）
struct SceneRecognitionRequest: Codable {
    let locationId: Int64
    let questionId: Int64?  // 🔥 新增：问题ID（可选）
    let topLeftX: Int
    let topLeftY: Int
    let bottomRightX: Int
    let bottomRightY: Int
    let panoramaWidth: Int
    let panoramaHeight: Int
    let userPrompt: String?
    
    enum CodingKeys: String, CodingKey {
        case locationId = "location_id"
        case questionId = "question_id"  // 🔥 新增
        case topLeftX = "top_left_x"
        case topLeftY = "top_left_y"
        case bottomRightX = "bottom_right_x"
        case bottomRightY = "bottom_right_y"
        case panoramaWidth = "panorama_width"
        case panoramaHeight = "panorama_height"
        case userPrompt = "user_prompt"
    }
}

/// 场景识别响应
struct SceneRecognitionResponse: Codable {
    let success: Bool
    let result: String
    let croppedImageUrl: String?
    let usage: AIUsageInfo?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case result
        case croppedImageUrl = "cropped_image_url"
        case usage
        case message
    }
}

// MARK: - NetworkManager 场景识别扩展（修复版）

extension NetworkManager {
    
    /// 🎯 场景识别 - 分析用户圈选的全景图区域（修复版 - 支持问题上下文）
    /// - Parameters:
    ///   - locationId: 位置ID（对应全景图）
    ///   - questionId: 问题ID（可选，如果提供则AI会知道用户在问什么）
    ///   - region: 全景图坐标区域
    ///   - userPrompt: 用户自定义提示词（可选）
    ///   - timeout: 超时时间（默认60秒）
    /// - Returns: AI识别结果
    func recognizeSceneRegion(
        locationId: Int64,
        questionId: Int64? = nil,  // 🔥 新增参数
        region: PanoramaRegion,
        userPrompt: String? = nil,
        timeout: TimeInterval = 60.0
    ) async throws -> SceneRecognitionResponse {
        
        guard let url = URL(string: "\(baseURL)/ai/scene-recognition") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        let requestBody = SceneRecognitionRequest(
            locationId: locationId,
            questionId: questionId,  // 🔥 传递问题ID
            topLeftX: region.topLeft.x,
            topLeftY: region.topLeft.y,
            bottomRightX: region.bottomRight.x,
            bottomRightY: region.bottomRight.y,
            panoramaWidth: 8704,
            panoramaHeight: 4352,
            userPrompt: userPrompt
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("📤【发送场景识别请求】")
        print("   - 位置ID: \(locationId)")
        if let qid = questionId {
            print("   - 问题ID: \(qid)")  // 🔥 打印问题ID
        }
        print("   - 区域: (\(region.topLeft.x),\(region.topLeft.y)) → (\(region.bottomRight.x),\(region.bottomRight.y))")
        print("   - 尺寸: \(region.width)x\(region.height)")
        print("   - 超时时间: \(timeout)秒")
        if let prompt = userPrompt {
            print("   - 用户提示: \(prompt)")
        }
        
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(for: request)
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("⏱️【请求耗时】\(String(format: "%.2f", elapsedTime))秒")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥【场景识别响应】状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError("全景图不存在")
                } else if httpResponse.statusCode == 400 {
                    let errorResponse = try? JSONDecoder().decode(SceneRecognitionResponse.self, from: data)
                    throw NetworkError.serverError(errorResponse?.message ?? "请求参数错误")
                } else if httpResponse.statusCode == 429 {
                    throw NetworkError.serverError("AI服务请求过于频繁，请稍后再试")
                } else if httpResponse.statusCode == 500 {
                    throw NetworkError.serverError("服务器内部错误")
                } else if httpResponse.statusCode != 200 {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let recognitionResponse = try JSONDecoder().decode(SceneRecognitionResponse.self, from: data)
            
            if recognitionResponse.success {
                print("✅【场景识别成功】")
                print("   - 识别结果长度: \(recognitionResponse.result.count) 字符")
                
                if let imageUrl = recognitionResponse.croppedImageUrl {
                    print("   - 🖼️ 裁剪图片URL: \(imageUrl)")
                    print("   - 📥 完整下载链接: \(self.baseURL)\(imageUrl)")
                } else {
                    print("   - ⚠️ 未返回裁剪图片URL")
                }
            } else {
                print("❌【场景识别失败】: \(recognitionResponse.message ?? "未知错误")")
            }
            
            return recognitionResponse
            
        } catch let error as URLError where error.code == .timedOut {
            print("❌【请求超时】")
            throw NetworkError.serverError("请求超时，请检查网络连接")
        } catch let error as DecodingError {
            print("❌【场景识别响应解析错误】: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌【场景识别网络请求失败】: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
    
    /// 🎯 快速场景识别（使用默认提示词）
    func quickRecognizeScene(
        locationId: Int64,
        questionId: Int64? = nil,  // 🔥 新增参数
        region: PanoramaRegion,
        timeout: TimeInterval = 60.0
    ) async throws -> String {
        let response = try await recognizeSceneRegion(
            locationId: locationId,
            questionId: questionId,  // 🔥 传递问题ID
            region: region,
            userPrompt: "这是什么地方？请详细描述你看到的内容。",
            timeout: timeout
        )
        
        if response.success {
            return response.result
        } else {
            throw NetworkError.serverError(response.message ?? "识别失败")
        }
    }
}

// MARK: - VisionAIView 集成示例（修复版）

extension AIAssistantWindow {
    
    /// 处理场景识别完成（修复版 - 传递问题ID）
    func handleSceneRecognitionCompleted(region: SelectionRegion) {
        print("🎯【开始处理场景识别】")
        
        Task {
            do {
                await MainActor.run {
                    core.sceneRecognitionState = .recognizing
                    core.errorMessage = nil
                }
                
                // 1. 创建坐标转换器
                let converter = PanoramaCoordinateConverter(
                    panoramaWidth: 8704,
                    panoramaHeight: 4352
                )
                
                // 2. 转换为全景图坐标
                let panoramaRegion = converter.convertSelectionToPanoramaRegion(region)
                
                // 🔥 发送可视化通知
                print("🎨【发送可视化通知 - 点击发送按钮后】")
                
                let finalMinU = Float(panoramaRegion.topLeft.x) / 8704.0
                let finalMaxU = Float(panoramaRegion.bottomRight.x) / 8704.0
                let finalMinV = Float(panoramaRegion.topLeft.y) / 4352.0
                let finalMaxV = Float(panoramaRegion.bottomRight.y) / 4352.0
                
                let finalAzimuthStart = (finalMinU - 0.5) * 2.0 * Float.pi
                let finalAzimuthEnd = (finalMaxU - 0.5) * 2.0 * Float.pi
                let finalElevationTop = (0.5 - finalMinV) * Float.pi
                let finalElevationBottom = (0.5 - finalMaxV) * Float.pi
                
                print("   🌐 球面坐标:")
                print("      方位角: \(String(format: "%.1f", finalAzimuthStart * 180.0 / Float.pi))° → \(String(format: "%.1f", finalAzimuthEnd * 180.0 / Float.pi))°")
                print("      仰角: \(String(format: "%.1f", finalElevationTop * 180.0 / Float.pi))° → \(String(format: "%.1f", finalElevationBottom * 180.0 / Float.pi))°")
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFittedSphericalRegion"),
                    object: nil,
                    userInfo: [
                        "fittedPoints": region.trackedPoints,
                        "radius": 10.0,
                        "azimuthRange": [finalAzimuthStart, finalAzimuthEnd],
                        "elevationRange": [finalElevationTop, finalElevationBottom],
                        "averageY": region.trackedPoints.map { $0.y }.reduce(0, +) / Float(region.trackedPoints.count),
                        "pixelRegion": panoramaRegion
                    ]
                )
                print("   ✅ 已发送可视化通知（基于最终像素坐标）")
                
                // 3. 🔥 获取当前位置ID和问题ID
                guard let locationId = await getLocationIdFromContext() else {
                    await MainActor.run {
                        core.errorMessage = "无法获取位置信息"
                        core.sceneRecognitionState = .idle
                    }
                    return
                }
                
                // 🔥 新增：获取当前问题ID
                let questionId = await getQuestionIdFromContext()
                
                if let qid = questionId {
                    print("🔍【识别上下文】位置ID: \(locationId), 问题ID: \(qid)")
                } else {
                    print("🔍【识别上下文】位置ID: \(locationId), 问题ID: 无")
                }
                
                // 4. 🔥 发送AI识别请求（带问题ID）
                print("🤖【发送AI识别请求】")
                let response = try await NetworkManager.shared.recognizeSceneRegion(
                    locationId: locationId,
                    questionId: questionId,  // 🔥 传递问题ID
                    region: panoramaRegion,
                    userPrompt: "请详细描述这个场景中的内容，包括建筑、设施、环境等。",
                    timeout: 60.0
                )
                
                // 5. 显示识别结果
                await MainActor.run {
                    if response.success {
                        let aiMessage = AIChatMessage(
                            content: response.result,
                            isUser: false,
                            timestamp: Date()
                        )
                        core.messages.append(aiMessage)
                        core.sceneRecognitionState = .completed
                        print("✅ 场景识别完成")
                    } else {
                        core.errorMessage = response.message ?? "识别失败"
                        core.sceneRecognitionState = .idle
                        print("❌ 场景识别失败: \(response.message ?? "未知错误")")
                    }
                }
                
            } catch let error as NetworkError {
                await MainActor.run {
                    core.errorMessage = error.localizedDescription
                    core.sceneRecognitionState = .idle
                    print("❌ 网络错误: \(error)")
                }
            } catch {
                await MainActor.run {
                    core.errorMessage = "场景识别出错: \(error.localizedDescription)"
                    core.sceneRecognitionState = .idle
                    print("❌ 场景识别出错: \(error)")
                }
            }
        }
    }
    
    // 发送场景识别请求（带用户提示词和问题ID）
    public func sendSceneRecognitionRequest(region: SelectionRegion, userPrompt: String) {
        print("🤖【开始场景识别请求】")
        
        Task {
            do {
                await MainActor.run {
                    core.sceneRecognitionState = .recognizing
                    core.errorMessage = nil
                }
                
                // 1. 坐标转换
                let converter = PanoramaCoordinateConverter(
                    panoramaWidth: 8704,
                    panoramaHeight: 4352
                )
                let panoramaRegion = converter.convertSelectionToPanoramaRegion(region)
                
                // 🔥 发送可视化通知
                print("🎨【发送可视化通知 - 自定义提示词发送】")
                
                let finalMinU = Float(panoramaRegion.topLeft.x) / 8704.0
                let finalMaxU = Float(panoramaRegion.bottomRight.x) / 8704.0
                let finalMinV = Float(panoramaRegion.topLeft.y) / 4352.0
                let finalMaxV = Float(panoramaRegion.bottomRight.y) / 4352.0
                
                let finalAzimuthStart = (finalMinU - 0.5) * 2.0 * Float.pi
                let finalAzimuthEnd = (finalMaxU - 0.5) * 2.0 * Float.pi
                let finalElevationTop = (0.5 - finalMinV) * Float.pi
                let finalElevationBottom = (0.5 - finalMaxV) * Float.pi
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFittedSphericalRegion"),
                    object: nil,
                    userInfo: [
                        "fittedPoints": region.trackedPoints,
                        "radius": 10.0,
                        "azimuthRange": [finalAzimuthStart, finalAzimuthEnd],
                        "elevationRange": [finalElevationTop, finalElevationBottom],
                        "averageY": region.trackedPoints.map { $0.y }.reduce(0, +) / Float(region.trackedPoints.count),
                        "pixelRegion": panoramaRegion
                    ]
                )
                print("   ✅ 已发送可视化通知")
                
                // 2. 🔥 获取位置ID和问题ID
                guard let locationId = await getLocationIdFromContext() else {
                    await MainActor.run {
                        core.errorMessage = "无法获取位置信息"
                        core.sceneRecognitionState = .idle
                    }
                    return
                }
                
                let questionId = await getQuestionIdFromContext()  // 🔥 获取问题ID
                
                // 3. 🔥 发送请求（带问题ID）
                let response = try await NetworkManager.shared.recognizeSceneRegion(
                    locationId: locationId,
                    questionId: questionId,  // 🔥 传递问题ID
                    region: panoramaRegion,
                    userPrompt: userPrompt,
                    timeout: 60.0
                )
                
                // 4. 处理结果
                await MainActor.run {
                    if response.success {
                        let aiMessage = AIChatMessage(
                            content: response.result,
                            isUser: false,
                            timestamp: Date()
                        )
                        core.messages.append(aiMessage)
                        core.sceneRecognitionState = .completed
                    } else {
                        core.errorMessage = response.message ?? "识别失败"
                        core.sceneRecognitionState = .idle
                    }
                }
                
            } catch {
                await MainActor.run {
                    core.errorMessage = "识别出错: \(error.localizedDescription)"
                    core.sceneRecognitionState = .idle
                }
            }
        }
    }

    // 🔥 获取位置ID的方法（需要你根据实际情况实现）
    private func getLocationIdFromContext() async -> Int64? {
        // 🔥 TODO: 从你的应用上下文中获取当前位置ID
        // 例如：从 VRManager、SceneManager 或其他管理器中获取
        
        // 示例实现（需要替换为实际逻辑）：
        // if let currentLocation = SceneManager.shared.currentLocation {
        //     return Int64(currentLocation.id)
        // }
        
        // 临时返回测试值
        return 1
    }
    
    // 🔥 新增：获取问题ID的方法（需要你根据实际情况实现）
    private func getQuestionIdFromContext() async -> Int64? {
        // 🔥 TODO: 从你的应用上下文中获取当前问题ID
        // 例如：从 TargetQuestionManager 中获取
        
        // 示例实现（需要替换为实际逻辑）：
        // if let currentQuestion = TargetQuestionManager.shared.currentQuestion {
        //     return Int64(currentQuestion.id)
        // }
        
        return nil  // 如果没有关联问题，返回nil
    }
}
