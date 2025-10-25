//
//  NotificationHandlers.swift
//  ReaLink
//
//  通知监听和处理 - 添加自动清理功能
//

import SwiftUI
import RealityKit

extension BasicPanoramaView {
    
    // MARK: - 获取用户面前的位置
    /// 计算用户当前视角前方的位置，用于放置新模型
    /// - Returns: 用户前方1.5米处的3D位置
    func getUserFacingPosition() -> SIMD3<Float> {
           // 🔥 简化方案：直接使用估计值
           // 在visionOS中，用户头部位置通常在 (0, 1.7, 0) 附近
           // 正前方是 -Z 方向
           
           let estimatedHeadPosition = SIMD3<Float>(0, 1.7, 0)
           let estimatedForward = SIMD3<Float>(0, 0, -1)
           let distanceInFront: Float = 1.5
           let targetPosition = estimatedHeadPosition + estimatedForward * distanceInFront
           
           print("📍【计算用户前方位置】")
           print("   头部位置（估计）: \(estimatedHeadPosition)")
           print("   前方向量: \(estimatedForward)")
           print("   目标位置: \(targetPosition)")
           
           return targetPosition
       }
    
    // MARK: - 设置通知监听器
    func setupNotificationListeners() {
        removeNotificationListeners()
        
        // 请求模型列表
        let requestModelsListObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RequestPlacedModelsList"),
            object: nil,
            queue: .main
        ) { _ in
            print("📋 收到模型列表请求")
            
            // ✅ 修复：确保返回完整的用户信息
            let modelInfos = self.placedModels.compactMap { model -> ModelInfo? in
                // 获取真实的用户名和头像
                let username: String
                let avatarUrl: String?
                
                if let userId = model.userId {
                    // ✅ 使用模型中存储的真实用户名和头像
                    username = model.username ?? "用户\(userId)"
                    avatarUrl = model.avatarUrl
                } else {
                    username = "未知用户"
                    avatarUrl = nil
                }
                
                return ModelInfo(
                    id: model.id,
                    type: model.type,
                    username: username,
                    color: model.color,
                    text: model.text,
                    userId: model.userId,      // ✅ 添加 userId 字段
                    avatarUrl: avatarUrl       // ✅ 添加 avatarUrl 字段
                )
            }
            
            // 发送响应
            NotificationCenter.default.post(
                name: NSNotification.Name("PlacedModelsListResponse"),
                object: nil,
                userInfo: ["models": modelInfos]
            )
            
            print("✅ 返回 \(modelInfos.count) 个模型信息")
        }
        notificationObservers.append(requestModelsListObserver)

        // 切换单个模型可见性
        let toggleModelVisibilityObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ToggleModelVisibility"),
            object: nil,
            queue: .main
        ) { notification in
            guard let modelIdString = notification.userInfo?["modelId"] as? String,
                  let modelId = UUID(uuidString: modelIdString),
                  let isHidden = notification.userInfo?["isHidden"] as? Bool else {
                print("⚠️ 切换模型可见性参数错误")
                return
            }
            
            if let model = self.placedModels.first(where: { $0.id == modelId }) {
                model.entity.isEnabled = !isHidden
                print("🔄 模型可见性已切换: \(modelId), isEnabled=\(!isHidden)")
            }
        }
        notificationObservers.append(toggleModelVisibilityObserver)

        // 切换全部模型可见性
        let toggleAllModelsVisibilityObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ToggleAllModelsVisibility"),
            object: nil,
            queue: .main
        ) { notification in
            guard let hideAll = notification.userInfo?["hideAll"] as? Bool else {
                print("⚠️ 切换全部模型可见性参数错误")
                return
            }
            
            for model in self.placedModels {
                model.entity.isEnabled = !hideAll
            }
            
            print(hideAll ? "🙈 已隐藏全部 \(self.placedModels.count) 个模型" : "👀 已显示全部 \(self.placedModels.count) 个模型")
        }
        notificationObservers.append(toggleAllModelsVisibilityObserver)
        
        let realityWindowClosedObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RealityWindowClosed"),
                object: nil,
                queue: .main
            ) { _ in
                print("🔴【Reality Window 已关闭，恢复所有问答球显示】")
                self.handleRealityWindowClosed()
            }
            notificationObservers.append(realityWindowClosedObserver)
        
        // 退出实景模式事件
        let exitImmersiveObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExitImmersiveSpace"),
            object: nil,
            queue: .main
        ) { _ in
            print("🚪 收到退出实景模式通知，关闭所有相关窗口")
            
            self.dismissWindow(id: "RealityWindow")
            self.dismissWindow(id: "ControlMenuWindow")
            self.dismissWindow(id: "BrushControlWindow")
            self.dismissWindow(id: "ModelControlWindow")
            
            self.hideOtherQuestionSpheres = false
            self.selectedQuestionId = nil
            
            Task { @MainActor in
                await self.animateQuestionSpheresVisibility()
            }
            
            print("✅ 所有窗口关闭指令已发送，问题球已恢复显示")
        }
        notificationObservers.append(exitImmersiveObserver)
        
        // 🔥 RealityWindow关闭通知（增强版 - 自动清理）
        let windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RealityWindowClosed"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔕 收到 RealityWindow 关闭通知")
            print("🧹 开始自动清理绘画和模型...")
            
            // 1️⃣ 禁用绘画模式
            if self.brushManager.isPaintingEnabled {
                print("🎨 禁用空间绘画模式")
                self.brushManager.isPaintingEnabled = false
            }
            
            // 2️⃣ 清空画布
            print("🎨 清空绘画画布")
            self.paintingCanvas.clearAllStrokes()
            
            // 3️⃣ 禁用模型测试模式
            if self.modelManager.isModelTestingEnabled {
                print("🧊 禁用3D模型模式")
                self.modelManager.isModelTestingEnabled = false
            }
            
            // 4️⃣ 清除所有模型
            print("🧊 清除所有3D模型")
            self.clearAllModelsFromScene()
            
            // 5️⃣ 重置绘画状态
            self.hasTriedLoadingPainting = false
            self.isPaintingLoaded = false
            self.paintingLoadError = nil
            
            // 6️⃣ 重置模型状态
            self.hasTriedLoadingModels = false
            self.isModelsLoaded = false
            self.modelsLoadError = nil
            
            // 7️⃣ 停止手部追踪
            self.handTracking.stopTracking()
            
            // 8️⃣ 重置窗口状态
            self.windowStateManager.isRealityWindowOpen = false
            self.hideOtherQuestionSpheres = false
            self.selectedQuestionId = nil
            
            print("✅ 清理完成，恢复问题球显示")
            
            Task { @MainActor in
                await self.animateQuestionSpheresVisibility()
            }
            
            print("🔕 RealityWindow 状态已重置，所有资源已清理")
        }
        notificationObservers.append(windowCloseObserver)
        
        // 退出沉浸式空间通知
        let exitObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExitImmersiveSpace"),
            object: nil,
            queue: .main
        ) { _ in
            print("收到退出沉浸式空间指令")
            Task {
                await self.dismissImmersiveSpace()
                await self.openWindow(id: "MainWindow")
            }
        }
        notificationObservers.append(exitObserver)
        
        // 添加模型通知
        let addCubeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AddCube"),
            object: nil,
            queue: .main
        ) { notification in
            print("【通知】收到添加模型指令")
            if let userInfo = notification.userInfo {
                self.handleAddModelNotification(userInfo)
            } else {
                self.addCube()
            }
        }
        notificationObservers.append(addCubeObserver)
        
        // 清空模型通知
        let clearModelsObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClearAllModels"),
            object: nil,
            queue: .main
        ) { _ in
            print("【通知】收到清空所有模型指令")
            self.clearAllModels()
        }
        notificationObservers.append(clearModelsObserver)
        
        // 撤回操作通知
        let undoObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExecuteUndoOperation"),
            object: nil,
            queue: .main
        ) { _ in
            print("【撤回】收到执行撤回操作指令")
            self.undoLastOperation()
        }
        notificationObservers.append(undoObserver)
        
        // 模型编辑操作通知
        let editObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ModelEditOperation"),
            object: nil,
            queue: .main
        ) { notification in
            print("🔧 收到模型编辑操作通知")
            if let userInfo = notification.userInfo {
                self.handleModelEditOperation(userInfo)
            }
        }
        notificationObservers.append(editObserver)
        
        // 云端模型操作通知
        let cloudModelObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudModelOperation"),
            object: nil,
            queue: .main
        ) { notification in
            print("🧊 收到云端模型操作通知")
            if let userInfo = notification.userInfo {
                self.handleCloudModelOperation(userInfo)
            }
        }
        notificationObservers.append(cloudModelObserver)
        
        // 云端绘画操作通知
        let cloudPaintingObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudPaintingOperation"),
            object: nil,
            queue: .main
        ) { notification in
            print("🎨 收到云端绘画操作通知")
            if let userInfo = notification.userInfo {
                self.handleCloudPaintingOperation(userInfo)
            }
        }
        notificationObservers.append(cloudPaintingObserver)
        
        print("✅ 通知监听器设置完成，共 \(notificationObservers.count) 个")
    }
    
    @MainActor
    public func handleRealityWindowClosed() {
        // 重置状态
        hideOtherQuestionSpheres = false
        selectedQuestionId = nil
        
        // 恢复所有问答球的显示
        Task { @MainActor in
            await animateQuestionSpheresVisibility()
        }
        
        print("✅【所有问答球已恢复显示】")
    }
    
    func removeNotificationListeners() {
        print("🧹 BasicPanoramaView: 移除所有通知监听器 (共\(notificationObservers.count)个)")
        
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        
        notificationObservers.removeAll()
        print("✅ 通知监听器已全部移除")
    }
    
    // MARK: - 添加模型通知处理
    // 修复的添加模型通知处理方法
    func handleAddModelNotification(_ userInfo: [AnyHashable: Any]) {
        guard !isProcessingAddModel else {
            print("⚠️ 正在处理添加模型操作，跳过重复请求")
            return
        }
        
        print("🎯 收到添加模型通知，开始处理")
        
        isProcessingAddModel = true
        
        // 解析模型类型
        let modelTypeString = userInfo["modelType"] as? String ?? "cube"
        let modelType = ModelType(rawValue: modelTypeString) ?? .cube
        
        // 解析颜色
        var color = Color.blue
        if let colorInfo = userInfo["color"] as? [String: Any] {
            let red = colorInfo["red"] as? CGFloat ?? 0.0
            let green = colorInfo["green"] as? CGFloat ?? 0.0
            let blue = colorInfo["blue"] as? CGFloat ?? 1.0
            let alpha = colorInfo["alpha"] as? CGFloat ?? 1.0
            color = Color(red: red, green: green, blue: blue, opacity: alpha)
        }
        
        // 🔥 修复：解析位置信息
        // 如果通知中包含位置信息（如复制操作），使用提供的位置
        // 否则，获取用户当前视角前方的位置
        var position: SIMD3<Float>
        if let positionInfo = userInfo["position"] as? [String: Float] {
            // 使用提供的位置（复制等操作）
            position = SIMD3<Float>(
                positionInfo["x"] ?? 0,
                positionInfo["y"] ?? 1.5,
                positionInfo["z"] ?? -1.5
            )
            print("🎯 使用指定位置: \(position)")
        } else {
            // 🌟 新增：获取用户面前的位置
            position = getUserFacingPosition()
            print("🎯 使用用户前方位置: \(position)")
        }
        
        // 🔥 修复：解析缩放信息
        var scale = SIMD3<Float>(repeating: 1.0)
        if let scaleInfo = userInfo["scale"] as? [String: Float] {
            scale = SIMD3<Float>(
                scaleInfo["x"] ?? 1.0,
                scaleInfo["y"] ?? 1.0,
                scaleInfo["z"] ?? 1.0
            )
        }
        
        // 🔥 修复：解析旋转信息
        var rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        if let rotationInfo = userInfo["rotation"] as? [String: Float] {
            rotation = simd_quatf(
                ix: rotationInfo["x"] ?? 0,
                iy: rotationInfo["y"] ?? 0,
                iz: rotationInfo["z"] ?? 0,
                r: rotationInfo["w"] ?? 1
            )
        }
        
        // 🔥 修复：解析文本信息
        let text = userInfo["text"] as? String
        
        // 解析其他参数
        let size = userInfo["size"] as? Float ?? modelManager.cubeSize
        let opacity = userInfo["opacity"] as? Float ?? modelManager.modelOpacity
        
        // 🔥 关键修复：对于复制操作，跳过地面吸附
        let isFromDuplication = userInfo["scale"] != nil || userInfo["rotation"] != nil
        
        let finalPosition: SIMD3<Float>
        if isFromDuplication {
            // 复制操作：保持原始位置，不进行地面吸附
            finalPosition = position
            print("🎯 复制操作：保持原始位置 \(position)")
        } else {
            // 新建操作：应用地面吸附
            let sceneManager = SceneManager(vrManager: vrManager)
            finalPosition = sceneManager.calculateGroundSnapPosition(
                from: position,
                enableSnap: isGroundSnapEnabled
            )
            print("🎯 新建操作：位置吸附 \(position) -> \(finalPosition)")
        }
        
        let currentUserId = userManager.getUserId()
        // 🔥 关键修复：获取当前用户的用户名和头像
        let username = userManager.getUsername()
        let avatarUrl = userManager.getAvatarUrl()
        
        print("🎯 创建模型参数:")
        print("   - 类型: \(modelType.rawValue)")
        print("   - 位置: \(finalPosition)")
        print("   - 缩放: \(scale)")
        print("   - 旋转: \(rotation)")
        print("   - 颜色: \(color)")
        print("   - 大小: \(size)")
        print("   - 不透明度: \(opacity)")
        print("   - 用户ID: \(currentUserId ?? -1)")
        print("   - 用户名: \(username ?? "未知")")
        print("   - 头像: \(avatarUrl ?? "无")")
        if let text = text, !text.isEmpty {
            print("   - 文本: \(text)")
        }
        
        DispatchQueue.main.async {
            // 🔥 使用完整属性创建模型（包含用户信息）
            let model = self.createModelWithFullAttributes(
                position: finalPosition,
                scale: scale,
                rotation: rotation,
                type: modelType,
                color: color,
                size: size,
                opacity: opacity,
                userId: currentUserId,
                text: text,
                username: username,     // ✅ 传递用户名
                avatarUrl: avatarUrl    // ✅ 传递头像URL
            )
            self.placedModels.append(model)
            
            let snapshot = ModelSnapshot(
                modelId: model.id,
                modelType: modelType,
                position: finalPosition,
                scale: scale,
                color: color,
                userId: currentUserId
            )
            self.recordOperation(.add, snapshot: snapshot)
            
            print("✅ 模型创建完成: \(model.id)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isProcessingAddModel = false
                print("🔄 添加模型处理标志已重置")
            }
        }
    }
    func addCube() {
        guard modelManager.isModelTestingEnabled else {
            print("模型测试未启用")
            return
        }
        
        // 🌟 使用用户面前的位置而不是固定位置
        let userFacingPosition = getUserFacingPosition()
        
        print("🎯【addCube】使用用户前方位置: \(userFacingPosition)")
        
        DispatchQueue.main.async {
            self.addModelAt(
                position: userFacingPosition,
                type: self.modelManager.selectedModelType,
                color: self.modelManager.cubeColor,
                size: self.modelManager.cubeSize,
                opacity: self.modelManager.modelOpacity
            )
        }
    }
    
    func addModelAt(position: SIMD3<Float>, type: ModelType, color: Color, size: Float, opacity: Float, userId: Int64? = nil) {
        guard modelManager.isModelTestingEnabled else {
            print("模型测试未启用，无法添加模型")
            return
        }
        
        let finalUserId = userId ?? userManager.getUserId()
        print("【开始创建模型】类型: \(type.rawValue), 位置: \(position), 用户: \(finalUserId ?? -1)")
        
        let model = createModelAt(
            position: position,
            type: type,
            color: color,
            size: size,
            opacity: opacity,
            userId: finalUserId
        )
        placedModels.append(model)
        
        let snapshot = ModelSnapshot(
            modelId: model.id,
            modelType: type,
            position: position,
            scale: SIMD3<Float>(repeating: 1.0),
            color: color,
            userId: finalUserId
        )
        recordOperation(.add, snapshot: snapshot)
        
        print("【模型创建完成】")
        print("   - 模型ID: \(model.id)")
        print("   - 模型类型: \(type.rawValue)")
        print("   - 实体名称: \(model.entity.name)")
        print("   - 实体位置: \(model.entity.position)")
        print("   - 用户ID: \(finalUserId ?? -1)")
        print("   - 当前总模型数: \(placedModels.count)")
    }
    
    func clearAllModels() {
        let currentUserId = userManager.getUserId()
        
        guard let userId = currentUserId else {
            print("❌ 用户未登录，无法清空模型")
            return
        }
        
        // 🔥 只过滤当前用户的模型
        let userModels = placedModels.filter { $0.userId == userId }
        
        print("🧹 【开始清空当前用户的模型】")
        print("   - 用户ID: \(userId)")
        print("   - 场景总模型数: \(placedModels.count)")
        print("   - 当前用户模型数: \(userModels.count)")
        
        if userModels.isEmpty {
            print("ℹ️ 当前用户没有模型可以清空")
            return
        }
        
        // 记录操作历史（用于撤销）
        for model in userModels {
            let snapshot = ModelSnapshot(
                modelId: model.id,
                modelType: model.type,
                position: model.entity.position,
                scale: model.entity.scale,
                color: model.color,
                userId: model.userId
            )
            recordOperation(.remove, snapshot: snapshot)
        }
        
        // 从场景中移除实体
        for (index, model) in userModels.enumerated() {
            print("🗑️ 移除模型 \(index + 1)/\(userModels.count): \(model.type.rawValue)")
            model.entity.removeFromParent()
        }
        
        // 从数组中移除（只移除当前用户的）
        placedModels.removeAll { model in
            model.userId == userId
        }
        
        print("✅ 【清空完成】")
        print("   - 已清空: \(userModels.count) 个模型")
        print("   - 剩余模型数: \(placedModels.count)")
    }
    
    // MARK: - 模型编辑操作处理
    func handleModelEditOperation(_ userInfo: [AnyHashable: Any]) {
        guard let action = userInfo["action"] as? String,
              let modelIdString = userInfo["modelId"] as? String,
              let modelId = UUID(uuidString: modelIdString) else {
            print("模型编辑操作参数解析失败")
            return
        }
        
        guard let modelIndex = placedModels.firstIndex(where: { $0.id == modelId }) else {
            print("未找到要编辑的模型: \(modelId)")
            return
        }
        
        let model = placedModels[modelIndex]
        
        print("🔧 执行模型编辑操作: \(action) 对模型: \(model.type.rawValue)")
        
        switch action {
        case "changeColor":
            handleChangeModelColor(model, userInfo: userInfo)
        case "setAbsoluteRotation":
            handleSetModelAbsoluteRotation(model, userInfo: userInfo)
        case "rotateWithAngle":
            handleRotateModelWithAngle(model, userInfo: userInfo)
        case "rotate":
            handleRotateModel(model)
        case "delete":
            handleDeleteModel(model)
        case "updateText":
            handleUpdateModelText(model, userInfo: userInfo)
        default:
            print("未知的模型编辑操作: \(action)")
        }
    }
    
    func handleChangeModelColor(_ model: PlacedModel, userInfo: [AnyHashable: Any]) {
        guard let colorInfo = userInfo["color"] as? [String: Float] else {
            print("❌ 颜色信息解析失败")
            return
        }
        
        let red = colorInfo["red"] ?? 0.0
        let green = colorInfo["green"] ?? 0.0
        let blue = colorInfo["blue"] ?? 0.0
        let alpha = colorInfo["alpha"] ?? 1.0
        
        let newColor = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
        
        print("🎨 更改模型颜色: \(model.id) -> R:\(red) G:\(green) B:\(blue)")
        
        applyMaterialRecursive(model.entity, color: newColor)
        
        let updatedModel = PlacedModel(
            id: model.id,
            entity: model.entity,
            originalScale: model.originalScale,
            originalPosition: model.originalPosition,
            type: model.type,
            color: Color(newColor),
            size: model.size,
            opacity: model.opacity,
            userId: model.userId,
            text: model.text,
            username: model.username,      // ✅ 保留用户名
            avatarUrl: model.avatarUrl     // ✅ 保留头像
        )
        placedModels[placedModels.firstIndex(where: { $0.id == model.id })!] = updatedModel
    }
    
    func handleSetModelAbsoluteRotation(_ model: PlacedModel, userInfo: [AnyHashable: Any]) {
        guard let quaternionInfo = userInfo["quaternion"] as? [String: Float] else {
            print("旋转信息解析失败")
            return
        }
        
        let x = quaternionInfo["x"] ?? 0.0
        let y = quaternionInfo["y"] ?? 0.0
        let z = quaternionInfo["z"] ?? 0.0
        let w = quaternionInfo["w"] ?? 1.0
        
        let quaternion = simd_quatf(ix: x, iy: y, iz: z, r: w)
        
        print("🔧 应用绝对旋转: \(model.id) -> 四元数(\(x), \(y), \(z), \(w))")
        
        model.entity.orientation = quaternion
    }
    
    func handleRotateModelWithAngle(_ model: PlacedModel, userInfo: [AnyHashable: Any]) {
        guard let axis = userInfo["axis"] as? String,
              let angle = userInfo["angle"] as? Double else {
            print("❌ 旋转参数解析失败")
            return
        }
        
        let radians = Float(angle * .pi / 180)
        
        var rotationQuaternion: simd_quatf
        
        switch axis {
        case "x":
            rotationQuaternion = simd_quatf(angle: radians, axis: SIMD3<Float>(1, 0, 0))
        case "y":
            rotationQuaternion = simd_quatf(angle: radians, axis: SIMD3<Float>(0, 1, 0))
        case "z":
            rotationQuaternion = simd_quatf(angle: radians, axis: SIMD3<Float>(0, 0, 1))
        default:
            print("❌ 无效的旋转轴: \(axis)")
            return
        }
        
        print("🔄 精确旋转模型: \(model.id) 轴:\(axis) 角度:\(angle)°")
        
        model.entity.orientation = rotationQuaternion
    }
    
    func handleRotateModel(_ model: PlacedModel) {
        print("🔄 旋转模型: \(model.id)")
        
        let currentRotation = model.entity.orientation
        let additionalRotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
        model.entity.orientation = currentRotation * additionalRotation
    }
    
    func handleDeleteModel(_ model: PlacedModel) {
        print("🗑️ 删除模型: \(model.id)")
        
        model.entity.removeFromParent()
        
        if let index = placedModels.firstIndex(where: { $0.id == model.id }) {
            placedModels.remove(at: index)
            print("✅ 模型已从数组中移除")
        }
        
        let snapshot = ModelSnapshot(
            modelId: model.id,
            modelType: model.type,
            position: model.entity.position,
            scale: model.entity.scale,
            color: model.color,
            userId: model.userId
        )
        recordOperation(.remove, snapshot: snapshot)
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ModelDeselected"),
            object: nil
        )
    }
    
    func handleUpdateModelText(_ model: PlacedModel, userInfo: [AnyHashable: Any]) {
        guard model.type == .sign,
              let newText = userInfo["text"] as? String else {
            print("❌ Sign模型文字更新参数错误")
            return
        }
        
        print("📝 更新Sign模型文字: \(model.id) -> \(newText)")
        
        addTextToSignModel(model.entity, text: newText)
        
        let updatedModel = PlacedModel(
            id: model.id,
            entity: model.entity,
            originalScale: model.originalScale,
            originalPosition: model.originalPosition,
            type: model.type,
            color: model.color,
            size: model.size,
            opacity: model.opacity,
            userId: model.userId,
            text: newText,
            username: model.username,      // ✅ 保留用户名
            avatarUrl: model.avatarUrl     // ✅ 保留头像
        )
        placedModels[placedModels.firstIndex(where: { $0.id == model.id })!] = updatedModel
    }
}



extension BasicPanoramaView {
    
    // MARK: - 设置测试球面区域的通知监听
    func setupTestRegionNotifications() {
        print("🎯【设置测试球面区域通知监听】")
        
        // 监听：显示测试球面区域
        let showObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowTestSphericalRegion"),
            object: nil,
            queue: .main
        ) { [self] notification in
            print("📢【收到显示测试球面区域通知】")
            
            // 获取参数
            let expectedTopLeft = notification.userInfo?["expectedTopLeft"] as? (Int, Int) ?? (2840, 1122)
            let expectedBottomRight = notification.userInfo?["expectedBottomRight"] as? (Int, Int) ?? (5631, 2494)
            let sphereRadius = notification.userInfo?["sphereRadius"] as? Float ?? 10.0
            
            // 移除旧的测试区域
            self.hideTestSphericalRegion()
            
            // 🔥 像素 → UV
            let uvTL = (u: Float(expectedTopLeft.0) / 8704.0, v: Float(expectedTopLeft.1) / 4352.0)
            let uvBR = (u: Float(expectedBottomRight.0) / 8704.0, v: Float(expectedBottomRight.1) / 4352.0)
            
            // 🔥 UV → 方位角/仰角
            let azStart = (uvTL.u - 0.5) * 2.0 * .pi
            let azEnd = (uvBR.u - 0.5) * 2.0 * .pi
            let elTop = (0.5 - uvTL.v) * .pi
            let elBottom = (0.5 - uvBR.v) * .pi
            
            // 🔥 创建测试区域（使用正确的方法名和参数）
            let testRegion = TestSphericalRegion.createFittedRegionVisualization(
                azimuthRange: (azStart, azEnd),
                elevationRange: (elTop, elBottom),
                radius: sphereRadius
            )
            
            self.rootEntity.addChild(testRegion)
            
            print("✅【测试球面区域已添加到场景】")
            print("   - 期望映射像素: (\(expectedTopLeft.0),\(expectedTopLeft.1))→(\(expectedBottomRight.0),\(expectedBottomRight.1))")
            print("   - 半径: \(sphereRadius)m")
        }

        notificationObservers.append(showObserver)
        
        // 监听：隐藏测试球面区域
        let hideObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HideTestSphericalRegion"),
            object: nil,
            queue: .main
        ) { [self] _ in
            print("📢【收到隐藏测试球面区域通知】")
            self.hideTestSphericalRegion()
        }
        
        notificationObservers.append(hideObserver)
        
        print("✅【测试球面区域通知监听已设置】")
    }
    
}


extension BasicPanoramaView {
    
    /// 🗑️ 隐藏测试球面区域
    /// 移除场景中所有的测试球面区域和拟合球面区域
    func hideTestSphericalRegion() {
        print("🗑️【开始隐藏测试球面区域】")
        
        var removedCount = 0
        
        // 遍历根实体的所有子实体
        rootEntity.children.forEach { child in
            // 🔥 修复：直接访问 name 属性，不使用可选绑定
            // 因为在某些 RealityKit 版本中，Entity.name 可能不是可选类型
            let name = child.name
            
            // 检查名称是否包含测试区域的标识
            if name.hasPrefix("test_spherical_region") ||
                name.hasPrefix("fitted_spherical_region") ||
                name == "debug_spherical_patch" {
                child.removeFromParent()
                removedCount += 1
                print("   ✓ 移除: \(name)")
            }
        }
        
        if removedCount > 0 {
            print("✅【测试球面区域已移除】共移除 \(removedCount) 个实体")
        } else {
            print("ℹ️【没有找到需要移除的测试球面区域】")
        }
    }
}
