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
                
                // ✅ 注意：convertSelectionToPanoramaRegion() 内部已经发送了可视化通知
                // 格式完整，包含 isWrapping、segment1Azimuth、segment2Azimuth 等参数
                // 不需要重复发送！
                
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
                
                // ✅ 注意：convertSelectionToPanoramaRegion() 内部已经发送了可视化通知
                // 格式完整，包含 isWrapping、segment1Azimuth、segment2Azimuth 等参数
                // 不需要重复发送！
                
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

    // 🔥 增强版：获取位置ID的方法（多重容错）
    private func getLocationIdFromContext() async -> Int64? {
        // 方法1：从 SceneManager 获取当前真实的 location_id
        if let currentLocationId = SceneManager.shared?.currentLocationId, currentLocationId > 0 {
            print("✅【获取位置ID】从SceneManager: \(currentLocationId)")
            return Int64(currentLocationId)
        }
        
        // 方法2：从 VRSessionManager 获取
        let vrLocationId = await VRSessionManager.shared.currentLocationId
        if vrLocationId > 0 {
            print("✅【获取位置ID】从VRSessionManager: \(vrLocationId)")
            
            // 同步更新 SceneManager（保持一致性）
            SceneManager.shared?.currentLocationId = vrLocationId
            
            return vrLocationId
        }
        
        // 方法3：尝试从 VRManager 的 URL 中解析
        let panoramaURL = await VRSessionManager.shared.panoramaImageURL
        if !panoramaURL.isEmpty, let extractedId = extractLocationIdFromURL(panoramaURL) {
            print("✅【获取位置ID】从URL解析: \(extractedId)")
            
            // 同步更新管理器（保持一致性）
            SceneManager.shared?.currentLocationId = extractedId
            await MainActor.run {
                VRSessionManager.shared.currentLocationId = extractedId
            }
            
            return extractedId
        }
        
        print("⚠️【获取位置ID】所有方法都失败，返回nil")
        print("   - SceneManager.currentLocationId: \(SceneManager.shared?.currentLocationId ?? -1)")
        print("   - VRSessionManager.currentLocationId: \(vrLocationId)")
        print("   - VRSessionManager.panoramaImageURL: \(panoramaURL)")
        return nil
    }
    
    // 🔥 新增：从URL中提取 locationId 的辅助方法
    private func extractLocationIdFromURL(_ url: String) -> Int64? {
        let pattern = "location_(\\d+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let nsString = url as NSString
        let results = regex.matches(in: url, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results.first, match.numberOfRanges > 1 {
            let locationIdRange = match.range(at: 1)
            let locationIdString = nsString.substring(with: locationIdRange)
            return Int64(locationIdString)
        }
        
        return nil
    }
    
    // 🔥 实现：获取问题ID的方法（从TargetQuesitonManager）
    private func getQuestionIdFromContext() async -> Int64? {
        // 从 TargetQuesitonManager 获取当前问题
        let currentQuestion = await TargetQuesitonManager.shared.currentQuestion
        
        if currentQuestion.id > 0 {
            print("✅【获取问题ID】从TargetQuesitonManager: \(currentQuestion.id)")
            return Int64(currentQuestion.id)
        }
        
        print("ℹ️【获取问题ID】当前没有关联的问题")
        return nil
    }
}
