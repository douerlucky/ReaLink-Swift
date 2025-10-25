//
//  CloudOperations.swift
//  ReaLink
//
//  云端数据同步操作 - 修复用户ID保存问题
//

import SwiftUI

extension BasicPanoramaView {
    
    // MARK: - 云端模型操作处理
    func handleCloudModelOperation(_ userInfo: [AnyHashable: Any]) {
        guard let action = userInfo["action"] as? String else {
            print("❌ 云端模型操作：无效的action")
            return
        }
        
        print("🧊 处理云端模型操作: \(action)")
        
        switch action {
        case "saveModelsToCloud":
            handleSaveModelsToCloud(userInfo)
        case "loadModelsFromCloud":
            handleLoadModelsFromCloud(userInfo)
        case "checkCloudModels":
            handleCheckCloudModels(userInfo)
        default:
            print("❌ 未知的云端模型操作: \(action)")
        }
    }
    
    // 🔥 修复：保存模型时传递用户ID
    func handleSaveModelsToCloud(_ userInfo: [AnyHashable: Any]) {
        guard let locationId = userInfo["locationId"] as? Int64,
              let questionId = userInfo["questionId"] as? Int64 else {
            print("保存模型到云端：参数不完整")
            sendCloudOperationResult(success: false, message: "参数不完整")
            return
        }
        
        // ✅ 获取当前用户ID
        let currentUserId = userManager.getUserId()
        
        print("开始保存模型到云端: locationId=\(locationId), questionId=\(questionId), userId=\(currentUserId ?? -1)")
        
        Task {
            do {
                let modelsData = collectCurrentModelsData()
                let jsonData = try JSONEncoder().encode(modelsData)
                
                // ✅ 传递用户ID
                try await NetworkManager.shared.upload3DModels(
                    jsonData,
                    locationId: locationId,
                    questionId: questionId,
                    userId: currentUserId  // 🔥 修复：传递真实的用户ID
                )
                
                await MainActor.run {
                    print("✅ 模型保存到云端成功，用户ID: \(currentUserId ?? -1)")
                    sendCloudOperationResult(success: true, message: "模型保存成功")
                }
                
            } catch {
                await MainActor.run {
                    print("❌ 模型保存到云端失败: \(error)")
                    sendCloudOperationResult(success: false, message: "保存失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func handleLoadModelsFromCloud(_ userInfo: [AnyHashable: Any]) {
        guard let locationId = userInfo["locationId"] as? Int64,
              let questionId = userInfo["questionId"] as? Int64 else {
            print("从云端加载模型：参数不完整")
            sendCloudOperationResult(success: false, message: "参数不完整")
            return
        }
        
        print("开始从云端加载模型: locationId=\(locationId), questionId=\(questionId)")
        
        Task {
            do {
                // ✅ 传nil加载所有用户的模型（合并显示）
                let modelsData = try await NetworkManager.shared.download3DModels(
                    locationId: locationId,
                    questionId: questionId,
                    userId: nil  // 加载所有用户的模型
                )
                
                await MainActor.run {
                    clearAllModels()
                    loadModelsIntoScene(modelsData)
                    
                    print("✅ 模型从云端加载成功，总数: \(modelsData.models.count)")
                    sendCloudOperationResult(success: true, message: "模型加载成功")
                }
                
            } catch {
                await MainActor.run {
                    print("❌ 从云端加载模型失败: \(error)")
                    sendCloudOperationResult(success: false, message: "加载失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func handleCheckCloudModels(_ userInfo: [AnyHashable: Any]) {
        guard let locationId = userInfo["locationId"] as? Int64,
              let questionId = userInfo["questionId"] as? Int64,
              let userId = userInfo["userId"] as? Int64 else {
            print("❌ 检查云端模型：参数不完整")
            return
        }
        
        print("🧊 检查云端模型存在性: locationId=\(locationId), questionId=\(questionId), userId=\(userId)")
        
        Task {
            let exists = await NetworkManager.shared.check3DModelsExists(
                locationId: locationId,
                questionId: questionId,
                userId: userId
            )
            
            await MainActor.run {
                print("🧊 云端模型存在性检查结果: \(exists)")
                sendCloudModelsExistsResult(exists: exists)
            }
        }
    }
    
    // 🔥 修复：收集模型数据时保留用户ID
    func collectCurrentModelsData() -> ThreeDModelsData {
        var serializedModels: [SerializedModel] = []
        
        for model in placedModels {
            let serializedModel = SerializedModel(
                id: model.id.uuidString,
                type: model.type.rawValue,
                position: ModelPosition(
                    x: model.entity.position.x,
                    y: model.entity.position.y,
                    z: model.entity.position.z
                ),
                scale: ModelScale(
                    x: model.entity.scale.x,
                    y: model.entity.scale.y,
                    z: model.entity.scale.z
                ),
                rotation: ModelRotation(from: model.entity.orientation),
                color: ModelColor(
                    red: Float(model.color.cgColor?.components?[0] ?? 0),
                    green: Float(model.color.cgColor?.components?[1] ?? 0),
                    blue: Float(model.color.cgColor?.components?[2] ?? 0),
                    alpha: Float(model.color.cgColor?.components?[3] ?? 1)
                ),
                opacity: model.opacity,
                size: model.size,
                userId: model.userId,  // ✅ 保留每个模型的用户ID
                text: model.text,
                username: model.username,
                avatarUrl: model.avatarUrl
            )
            
            serializedModels.append(serializedModel)
            
            // 🔥 添加日志：显示每个模型的用户ID
            print("📦 收集模型: ID=\(model.id), 类型=\(model.type.rawValue), 用户=\(model.userId ?? -1)")
        }
        
        return ThreeDModelsData(
            version: "1.0",
            timestamp: Date().timeIntervalSince1970,
            models: serializedModels,
            totalCount: serializedModels.count
        )
    }
    
    func loadModelsIntoScene(_ modelsData: ThreeDModelsData) {
        print("开始加载 \(modelsData.models.count) 个模型到场景")
        
        clearAllModels()
        
        for (index, serializedModel) in modelsData.models.enumerated() {
            let position = SIMD3<Float>(
                serializedModel.position.x,
                serializedModel.position.y,
                serializedModel.position.z
            )
            
            let scale = SIMD3<Float>(
                serializedModel.scale.x,
                serializedModel.scale.y,
                serializedModel.scale.z
            )
            
            let rotation = serializedModel.safeRotation.quaternion
            
            let color = Color(
                red: Double(serializedModel.color.red),
                green: Double(serializedModel.color.green),
                blue: Double(serializedModel.color.blue),
                opacity: Double(serializedModel.color.alpha)
            )
            
            let modelType = ModelType(rawValue: serializedModel.type) ?? .cube
            
            // 🔥 打印用户信息用于调试
            print("📥 加载模型 \(index + 1): 类型=\(modelType.rawValue), 用户=\(serializedModel.username ?? "未知"), ID=\(serializedModel.userId ?? -1)")
            
            // ✅ 传递完整的用户信息
            let model = createModelWithFullAttributes(
                position: position,
                scale: scale,
                rotation: rotation,
                type: modelType,
                color: color,
                size: serializedModel.size,
                opacity: serializedModel.opacity,
                userId: serializedModel.userId,
                text: serializedModel.text,
                username: serializedModel.username,    // ✅ 传递用户名
                avatarUrl: serializedModel.avatarUrl   // ✅ 传递头像URL
            )
            
            placedModels.append(model)
        }
        
        print("✅ 所有模型加载完成，总数: \(placedModels.count)")
    }
    
    func sendCloudOperationResult(success: Bool, message: String) {
        let userInfo: [String: Any] = [
            "success": success,
            "message": message
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CloudModelOperationResult"),
            object: nil,
            userInfo: userInfo
        )
    }
    
    func sendCloudModelsExistsResult(exists: Bool) {
        let userInfo: [String: Any] = [
            "exists": exists
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CloudModelsExistsResult"),
            object: nil,
            userInfo: userInfo
        )
    }
    
    // MARK: - 云端绘画操作处理
    func handleCloudPaintingOperation(_ userInfo: [AnyHashable: Any]) {
        guard let action = userInfo["action"] as? String else {
            print("❌ 云端绘画操作：无效的action")
            return
        }
        
        print("🎨 处理云端绘画操作: \(action)")
        
        let locationId = userInfo["locationId"] as? Int64
        let questionId = userInfo["questionId"] as? Int64
        let userId = userInfo["userId"] as? Int64
        
        Task {
            switch action {
            case "savePaintingToCloud":
                await handleSavePaintingToCloud(locationId: locationId, questionId: questionId, userId: userId)
            case "loadPaintingFromCloud":
                await handleLoadPaintingFromCloud(locationId: locationId, questionId: questionId, userId: userId)
            case "checkCloudPainting":
                await handleCheckCloudPainting(locationId: locationId, questionId: questionId, userId: userId)
            default:
                print("❌ 未知的云端绘画操作: \(action)")
            }
        }
    }
    
    func handleSavePaintingToCloud(locationId: Int64?, questionId: Int64?, userId: Int64?) async {
        print("开始执行云端保存操作")
        
        do {
            try await paintingCanvas.savePaintingToCloud(
                locationId: locationId,
                questionId: questionId,
                userId: userId
            )
            print("✅ 绘画数据保存完成")
            
        } catch {
            print("❌ 画作保存到云端失败: \(error.localizedDescription)")
            
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": false, "message": "保存失败: \(error.localizedDescription)"]
                )
            }
        }
    }
    
    func handleLoadPaintingFromCloud(locationId: Int64?, questionId: Int64?, userId: Int64?) async {
        print("开始执行云端加载操作")
        
        do {
            try await paintingCanvas.loadPaintingFromCloud(
                locationId: locationId,
                questionId: questionId,
                userId: userId
            )
            print("✅ 绘画数据加载完成")
            
        } catch {
            print("❌ 从云端加载画作失败: \(error.localizedDescription)")
            
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": false, "message": "加载失败: \(error.localizedDescription)"]
                )
            }
        }
    }
    
    func handleCheckCloudPainting(locationId: Int64?, questionId: Int64?, userId: Int64?) async {
        print("检查云端画作存在性")
        
        let exists = await paintingCanvas.checkCloudPaintingExists(
            locationId: locationId,
            questionId: questionId,
            userId: userId
        )
        
        await MainActor.run {
            let userInfo: [String: Any] = ["exists": exists]
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudPaintingExistsResult"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    // ✅ 修复：加载所有模型时传nil（合并所有用户的模型）
    func loadAllModelsData() async {
        isLoadingModels = true
        hasTriedLoadingModels = true
        print("【开始按需加载】模型数据")
        
        do {
            let modelsData = try await NetworkManager.shared.download3DModels(
                locationId: targetQuesionManager.currentQuestion.locationID,
                questionId: targetQuesionManager.currentQuestion.id,
                userId: nil  // ✅ nil表示加载所有用户的模型
            )
            
            await MainActor.run {
                loadModelsIntoScene(modelsData)
                isModelsLoaded = true
                modelsLoadError = nil
                isLoadingModels = false
                print("✅ 模型数据按需加载成功，模型数: \(placedModels.count)")
            }
        } catch {
            await MainActor.run {
                isModelsLoaded = true
                modelsLoadError = error.localizedDescription
                isLoadingModels = false
                print("❌ 模型数据按需加载失败: \(error)")
            }
        }
    }
}
