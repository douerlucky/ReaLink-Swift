//
//  ModelTestingSpace.swift
//  ReaLink
//
//  Created by Assistant on 2025/8/20.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit



// MARK: - 主视图

struct ModelTestingSpace: View {
    @State private var rootEntity = Entity()
    @State private var placedModels: [PlacedModel] = []
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var gestureHandler = ModelGestureHandler()
    
    // 环境对象
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        ZStack {
            // 主3D视图
            RealityView { content in
                // 创建天空球
                let skybox = await createSkybox(imageName: "docklands_02")
                rootEntity.addChild(skybox)
                content.add(rootEntity)
                
                print("🧊 3D模型测试空间已初始化")
                
            } update: { content in
                // 更新逻辑 - 这里可以处理实时更新
            }
            .gesture(
                // 正确的拖动手势实现 - 修复权限检查
                DragGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        // 检查是否为模型实体
                        guard isModelEntity(value.entity) else { return }
                        
                        // 检查用户权限 - 修复权限检查逻辑
                        if let model = findModelByEntity(value.entity) {
                            let currentUserId = userManager.getUserId()
                            if !model.canUserManipulate(currentUserId: currentUserId) {
                                print("🚫 用户无权限操作此模型：当前用户\(currentUserId ?? -1)，模型归属\(model.userId ?? -1)")
                                return
                            }
                        } else {
                            print("⚠️ 未找到对应的PlacedModel，允许操作")
                        }
                        
                        // 使用苹果官方推荐的坐标转换方法
                        value.entity.position = value.convert(value.location3D, from: .local, to: value.entity.parent!)
                        print("🧊 拖动模型到位置: \(value.entity.position)")
                    }
            )
            .simultaneousGesture(
                // 空间点击手势
                SpatialTapGesture()
                    .onEnded { value in
                        let position = SIMD3<Float>(Float(value.location3D.x), Float(value.location3D.y), Float(value.location3D.z))
                        handleSpatialTap(at: position)
                    }
            )
            .simultaneousGesture(
                // 缩放手势 - 修复权限检查
                MagnifyGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        // 检查是否为模型实体
                        guard isModelEntity(value.entity) else { return }
                        
                        // 检查用户权限 - 修复权限检查逻辑
                        if let model = findModelByEntity(value.entity) {
                            let currentUserId = userManager.getUserId()
                            if !model.canUserManipulate(currentUserId: currentUserId) {
                                print("🚫 用户无权限缩放此模型：当前用户\(currentUserId ?? -1)，模型归属\(model.userId ?? -1)")
                                return
                            }
                        } else {
                            print("⚠️ 未找到对应的PlacedModel，允许缩放")
                        }
                        
                        let baseScale: Float = 1.0
                        let newScale = baseScale * Float(value.magnification)
                        let clampedScale = max(0.1, min(3.0, newScale))
                        value.entity.scale = SIMD3<Float>(repeating: clampedScale)
                        print("🧊 缩放模型: \(clampedScale)")
                    }
            )
            
            // 状态指示器（右上角）
            VStack {
                HStack {
                    Spacer()
                    statusIndicator
                }
                Spacer()
            }
        }
        .onAppear {
            print("🧊 进入3D模型测试模式")
            setupNotificationListeners()
        }
        .onDisappear {
            print("🧊 退出3D模型测试模式")
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // MARK: - 通知监听器设置
    private func setupNotificationListeners() {
        // 监听添加模型通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AddCube"),
            object: nil,
            queue: .main
        ) { _ in
            addCube()
        }
        
        // 监听清空模型通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClearAllModels"),
            object: nil,
            queue: .main
        ) { _ in
            clearAllModels()
        }
        
        // 监听云端模型操作通知 - 修复异步调用
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudModelOperation"),
            object: nil,
            queue: .main
        ) { notification in
            print("🧊 收到云端模型操作通知")
            Task {
                await handleCloudModelOperation(notification.userInfo)
            }
        }
        
    }
    
    // MARK: - 状态指示器
    private var statusIndicator: some View {
        VStack(spacing: 8) {
            // 模型测试状态
            HStack {
                Circle()
                    .fill(modelManager.isModelTestingEnabled ? .green : .red)
                    .frame(width: 12, height: 12)
                Text(modelManager.isModelTestingEnabled ? "模型测试已启用" : "模型测试已禁用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 已放置模型数量
            if modelManager.isModelTestingEnabled {
                HStack {
                    Image(systemName: "cube.fill")
                        .foregroundColor(.blue)
                        .frame(width: 8, height: 8)
                    Text("已放置: \(placedModels.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 操作提示
                VStack(alignment: .leading, spacing: 4) {
                    Text("操作说明:")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("• 空间点击放置模型")
                    Text("• 拖动移动模型")
                    Text("• 双指捏合缩放模型")
                    Text("• 使用控制面板管理")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.trailing, 20)
        .padding(.top, 60)
    }
    
    
    
    // MARK: - 云端模型操作处理
    private func handleCloudModelOperation(_ userInfo: [AnyHashable: Any]?) async {
        guard let userInfo = userInfo,
              let action = userInfo["action"] as? String else {
            print("🧊 无效的云端模型操作通知")
            sendModelOperationResult(success: false, message: "无效的操作请求")
            return
        }
        
        print("🧊 处理云端模型操作: \(action)")
        
        let locationId = userInfo["locationId"] as? Int64
        let questionId = userInfo["questionId"] as? Int64
        let answerId = userInfo["answerId"] as? Int64
        
        switch action {
        case "saveModelsToCloud":
            await saveModelsToCloud(locationId: locationId, questionId: questionId, answerId: answerId)
        case "loadModelsFromCloud":
            await loadModelsFromCloud(locationId: locationId, questionId: questionId, answerId: answerId)
        default:
            print("🧊 未知的云端模型操作: \(action)")
            sendModelOperationResult(success: false, message: "未知的操作类型")
        }
    }
    
    /// 保存模型到云端
    private func saveModelsToCloud(locationId: Int64?, questionId: Int64?, answerId: Int64?) async {
        print("🧊 开始执行云端模型保存操作")
        
        do {
            // 将当前场景中的所有模型序列化
            let modelsData = try await serializeCurrentModels()
            
            // 将ThreeDModelsData编码为JSON Data
            let jsonData = try JSONEncoder().encode(modelsData)
            
            // 通过NetworkManager上传
            try await NetworkManager.shared.upload3DModels(
                jsonData,
                locationId: locationId,
                questionId: questionId,
                userId: answerId
            )
            
            print("🧊 3D模型保存到云端成功")
            sendModelOperationResult(success: true, message: "3D模型保存成功")
            
        } catch {
            print("🧊 3D模型保存到云端失败: \(error.localizedDescription)")
            sendModelOperationResult(success: false, message: "保存失败: \(error.localizedDescription)")
        }
    }
    /// 从云端加载模型
    private func loadModelsFromCloud(locationId: Int64?, questionId: Int64?, answerId: Int64?) async {
        print("🧊 开始执行云端加载操作")
        
        do {
            let modelsData = try await NetworkManager.shared.download3DModels(
                locationId: locationId,
                questionId: questionId,
                userId: answerId
            )
            
            await MainActor.run {
                loadModelsIntoScene(modelsData)
            }
            
            print("🧊 从云端加载3D模型成功")
            
            // 发送成功通知
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudModelOperationResult"),
                    object: nil,
                    userInfo: ["success": true, "message": "3D模型加载成功"]
                )
            }
        } catch {
            print("🧊 从云端加载3D模型失败: \(error.localizedDescription)")
            
            // 发送失败通知
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudModelOperationResult"),
                    object: nil,
                    userInfo: ["success": false, "message": "加载失败: \(error.localizedDescription)"]
                )
            }
        }
    }
    
    /// 检查云端模型是否存在
    private func checkCloudModelsExists(locationId: Int64?, questionId: Int64?, answerId: Int64?) async {
        print("🧊 检查云端模型存在性")
        
        let exists = await NetworkManager.shared.check3DModelsExists(
            locationId: locationId,
            questionId: questionId,
            userId: answerId
        )
        
        print("🧊 云端模型存在性检查结果: \(exists)")
        
        // 发送检查结果通知
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudModelsExistsResult"),
                object: nil,
                userInfo: ["exists": exists]
            )
        }
    }
    
    // MARK: - 模型序列化和反序列化
    
    /// 序列化当前场景中的所有模型
    private func serializeCurrentModels() async throws -> ThreeDModelsData {
        var serializedModels: [SerializedModel] = []
        
        for model in placedModels {
            // 改进颜色序列化：使用UIColor的RGB组件
            let uiColor = UIColor(model.color)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            // 确保能获取到RGB组件
            if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                print("🧊 序列化模型 \(model.id): 颜色 R=\(red), G=\(green), B=\(blue), A=\(alpha)")
            } else {
                // 如果获取失败，尝试转换到RGB色彩空间
                let cgColor = uiColor.cgColor
                if let rgbColor = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
                   let components = rgbColor.components, components.count >= 3 {
                    red = components[0]
                    green = components[1]
                    blue = components[2]
                    alpha = components.count > 3 ? components[3] : 1.0
                    print("🧊 序列化模型 \(model.id): 通过转换获取颜色 R=\(red), G=\(green), B=\(blue), A=\(alpha)")
                } else {
                    // 最后的fallback
                    red = 0; green = 0; blue = 1; alpha = 1
                    print("🧊 序列化模型 \(model.id): 使用默认蓝色")
                }
            }
            
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
                rotation: ModelRotation(from: model.entity.orientation), // ✅ 添加这行
                color: ModelColor(
                    red: Float(red),
                    green: Float(green),
                    blue: Float(blue),
                    alpha: Float(alpha)
                ),
                opacity: model.opacity,
                size: model.size,
                userId: model.userId,
                text: model.text,
                username: model.username,
                avatarUrl: model.avatarUrl
            )
            serializedModels.append(serializedModel)
        }
        
        return ThreeDModelsData(
            version: "1.0",
            timestamp: Date().timeIntervalSince1970,
            models: serializedModels,
            totalCount: serializedModels.count
        )
    }
    
    private func sendModelOperationResult(success: Bool, message: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudModelOperationResult"),
                object: nil,
                userInfo: ["success": success, "message": message]
            )
        }
    }

    private func sendPaintingOperationResult(success: Bool, message: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudOperationResult"),
                object: nil,
                userInfo: ["success": success, "message": message]
            )
        }
    }
    
    /// 加载模型到场景中
    private func loadModelsIntoScene(_ modelsData: ThreeDModelsData) {
        // 先清空现有模型
        clearAllModels()
        
        // 加载新模型
        for serializedModel in modelsData.models {
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
            
            let color = Color(
                red: Double(serializedModel.color.red),
                green: Double(serializedModel.color.green),
                blue: Double(serializedModel.color.blue),
                opacity: Double(serializedModel.color.alpha)
            )
            
            print("反序列化模型 \(serializedModel.id): 颜色 R=\(serializedModel.color.red), G=\(serializedModel.color.green), B=\(serializedModel.color.blue), A=\(serializedModel.color.alpha)")
            print("创建Color: \(color)")
            
            // 直接创建具有正确属性的模型 - 修复：包含userId
            let model = createCubeModelAt(
                position: position,
                color: color,
                size: serializedModel.size,
                opacity: serializedModel.opacity,
                userId: serializedModel.userId // 传递用户ID
            )
            model.entity.scale = scale
            
            // 添加到场景
            rootEntity.addChild(model.entity)
            placedModels.append(model)
        }
        
        print("已加载 \(modelsData.models.count) 个模型到场景")
    }
    
    // MARK: - 空间点击处理
    private func handleSpatialTap(at location: SIMD3<Float>) {
        guard modelManager.isModelTestingEnabled else { return }
        
        // 在点击位置放置一个立方体
        addCubeAt(position: location)
    }
    
    // MARK: - 添加立方体（默认位置）
    private func addCube() {
        // 在用户前方1米处放置立方体
        let defaultPosition = SIMD3<Float>(0, 0, 0)
        addCubeAt(position: defaultPosition)
    }
    
    // MARK: - 在指定位置添加立方体
    private func addCubeAt(position: SIMD3<Float>) {
        // 获取当前用户ID
        let currentUserId = userManager.getUserId()
        
        let cubeModel = createCubeModelAt(
            position: position,
            userId: currentUserId  // 修复：传递userId参数
        )
        rootEntity.addChild(cubeModel.entity)
        placedModels.append(cubeModel)
        
        print("🧊 添加立方体到位置: x=\(position.x), y=\(position.y), z=\(position.z), 用户ID: \(currentUserId ?? -1)")
    }
    
    // MARK: - 创建立方体模型 - 修复：添加userId参数的重载
    private func createCubeModelAt(position: SIMD3<Float>, userId: Int64? = nil) -> PlacedModel {
        return createCubeModelAt(
            position: position,
            color: modelManager.cubeColor,
            size: modelManager.cubeSize,
            opacity: modelManager.modelOpacity,
            userId: userId  // 传递userId
        )
    }
    
    private func createCubeModelAt(position: SIMD3<Float>, color: Color, size: Float, opacity: Float, userId: Int64? = nil) -> PlacedModel {
        // 创建立方体几何体
        let mesh = MeshResource.generateBox(size: size)
        
        // 创建材质
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor(color))
        material.metallic = 0.3
        material.roughness = 0.7
        
        // 创建模型实体
        let cubeEntity = ModelEntity(mesh: mesh, materials: [material])
        cubeEntity.position = position
        
        // 重要：添加必要的组件以支持交互
        // 生成碰撞形状
        cubeEntity.generateCollisionShapes(recursive: false)
        
        // 添加输入目标组件以支持手势
        cubeEntity.components.set(InputTargetComponent(allowedInputTypes: .all))
        
        // 添加悬停效果组件
        cubeEntity.components.set(HoverEffectComponent())
        
        // 创建唯一的实体名称，用于识别
        cubeEntity.name = "cube_\(UUID().uuidString)"
        
        let model = PlacedModel(
            id: UUID(),
            entity: cubeEntity,
            originalScale: SIMD3<Float>(repeating: 1.0),
            originalPosition: position,
            type: .cube,
            color: color,
            size: size,
            opacity: opacity,
            userId: userId,
            text: nil// 设置用户ID
        )
        
        return model
    }
    
    // MARK: - 清空所有模型
    private func clearAllModels() {
        for model in placedModels {
            model.entity.removeFromParent()
        }
        placedModels.removeAll()
        print("🧊 已清空所有模型，当前模型数量: \(placedModels.count)")
    }
    
    // MARK: - 辅助方法：检查实体是否为模型实体
    private func isModelEntity(_ entity: Entity) -> Bool {
        let entityName = entity.name
        return entityName.starts(with: "cube_") ||
               entityName.starts(with: "sphere_") ||
               entityName.starts(with: "cylinder_") ||
               entityName.starts(with: "cone_") ||
               entityName.starts(with: "capsule_") ||
               entityName.starts(with: "sign_") ||
               entityName.starts(with: "plane_") ||
               entityName.contains("usdz") ||  // USDZ文件标识
               (entity.components.has(ModelComponent.self) &&
                entity.components.has(InputTargetComponent.self)) // 有模型和输入组件的实体
    }
    
    // MARK: - 辅助方法：根据实体查找对应的PlacedModel
    private func findModelByEntity(_ entity: Entity) -> PlacedModel? {
        return placedModels.first { model in
            model.entity.name == entity.name
        }
    }
    
    // MARK: - Skybox 创建
    private func createSkybox(imageName: String) async -> Entity {
        let texture = try? await TextureResource(named: imageName)

        var material = UnlitMaterial()
        if let texture {
            material.color = .init(texture: .init(texture))
        } else {
            material.color = .init(tint: .blue) // 默认背景
        }

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 50),
            materials: [material]
        )
        sphere.scale = SIMD3<Float>(-1, 1, 1)
        sphere.name = "skybox"
        return sphere
    }
}

#Preview(immersionStyle: .full) {
    ModelTestingSpace()
        .environmentObject(UserManager.shared)
}
