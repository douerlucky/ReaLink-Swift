//
//  BasicPanoramaView.swift
//  ReaLink
//
//  主全景视图 - 真机版（已移除所有模拟器代码）
//

import ARKit
import RealityKit
import RealityKitContent
import SwiftUI

struct BasicPanoramaView: View
{
    // MARK: - 环境对象

    @EnvironmentObject var vrManager: VRSessionManager
    @EnvironmentObject var targetQuesionManager: TargetQuesitonManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var windowStateManager: WindowStateManager

    // MARK: - 状态管理

    @State var isProcessingAddModel = false
    @StateObject public var handGestureManager = HandGestureManager()

    // 窗口控制
    @Environment(\.openWindow) public var openWindow
    @Environment(\.dismissWindow) public var dismissWindow
    @Environment(\.dismissImmersiveSpace) public var dismissImmersiveSpace

    @State public var isMenuWindowOpen = false
    @State public var canDetectGesture = true

    // 3D视图问题状态
    @State var questionsInSpace: [QuestionWith3DPosition] = []
    @State public var isLoadingQuestions = false
    @State public var current3DViewId: Int64?

    // 3D模型相关状态
    @State var placedModels: [PlacedModel] = []
    @StateObject public var modelManager = ModelManager.shared
    @State var isModelsLoaded = false
    @State var modelsLoadError: String?
    @State var isLoadingModels = false
    @State var hasTriedLoadingModels = false

    // 空间绘画相关状态
    @State var paintingCanvas = PaintingCanvas()
    @StateObject public var brushManager = BrushManager.shared
    @State var handTracking = PaintingHandTracking()
    @State var lastPinchPosition: SIMD3<Float>?
    @State var isPinching = false
    @State var isCurrentlyDrawing = false
    @State var isPaintingLoaded = false
    @State var paintingLoadError: String?
    @State var isLoadingPainting = false
    @State var hasTriedLoadingPainting = false

    // 场景实体管理
    @State var rootEntity = Entity()
    @State public var isRootEntityInitialized = false
    @State public var isSceneReady = false

    @State var modelOperationHistory: [ModelOperationRecord] = []

    @State public var gestureTranslation: SIMD3<Float> = .zero
    @State public var itemTranslations: [UUID: SIMD3<Float>] = [:]
    @State public var gestureScale: Float = 1.0
    @State public var itemScales: [UUID: Float] = [:]

    @State public var modelRotationX: Double = 0
    @State public var modelRotationY: Double = 0
    @State public var modelRotationZ: Double = 0

    @State var notificationObservers: [NSObjectProtocol] = []
    @State public var forceUpdateCounter = 0
    @State public var lastUpdateTime = Date()
    public let updateThrottle: TimeInterval = 0.2

    @State var hideOtherQuestionSpheres = false
    @State var selectedQuestionId: Int64?

    @State var pendingModelAttributes: [UUID: (position: SIMD3<Float>, scale: SIMD3<Float>)] = [:]

    @State var virtualGround: Entity?
    @State var isGroundSnapEnabled = true

    // 🔥 区域选择相关状态（真机版）
    @State var regionSelectionManager: RegionSelectionManager?
       @State var isRegionSelectionEnabled = false
    @State var regionSelectionHandTracking: RegionSelectionHandTracking?  // 🔥 修复：改为 @State 变量
    
    //添加是否吸附
    @State var isModelSnapEnabled = true
    
    @State private var arSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()
    
    // 🌟 新增：模型附着到手上的状态
    @State private var handAttachedModel: PlacedModel?
    @State private var isModelAttachedToHand = false
    @State private var handAttachmentTimer: Timer?
       
    // MARK: - 主视图

    var body: some View
    {
        ZStack
        {
            RealityView
            { content in
                print("🌟【RealityView初始化开始】")

                rootEntity = Entity()
                rootEntity.name = "RootEntity"
                content.add(rootEntity)
                isRootEntityInitialized = true

                // 🔥 初始化区域选择管理器
                regionSelectionManager = RegionSelectionManager(rootEntity: rootEntity)
                
                print("🌟【根实体已初始化，等待异步加载天空球】")

                Task { @MainActor in
                    await self.setupChildEntities()
                }

            } update: { _ in
                // 绘画模式的手势更新
                if brushManager.isPaintingEnabled {
                    self.performHandTrackingUpdateSync()
                }
            }
            .simultaneousGesture(
                DragGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        handleMagnifyChanged(value)
                    }
                    .onEnded { value in
                        handleMagnifyEnded(value)
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        handleSpatialTap(value)
                    }
            )
        }
        .onAppear {
            handGestureManager.startTracking()
            
            // ✅ 启动 ARKit 世界追踪
            Task {
                do {
                    try await arSession.run([worldTracking])
                    print("✅【ARKit 世界追踪已启动】")
                } catch {
                    print("⚠️【ARKit 启动失败】: \(error)")
                }
            }
            
            if notificationObservers.isEmpty {
                setupNotificationListeners()
            }
            
            setupResetNotificationListener()
              setupRegionSelectionListeners()
              setupPaintingNotificationListeners()
              setupTestRegionNotifications()  // 🔥 添加这一行
              
            
            Task {
                await load3DViewQuestions()
            }
        }
        .onDisappear {
            // 执行完整清理
            cleanupResources()
        }
        .onChange(of: brushManager.isPaintingEnabled) { _, newValue in
            handlePaintingModeChange(newValue)
        }
        .onChange(of: handGestureManager.isMenuTriggerGestureDetected) { oldValue, newValue in
            if newValue && !oldValue && canDetectGesture {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    print("检测到新手势，触发控制菜单")

                    canDetectGesture = false
                    toggleControlMenu()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        canDetectGesture = true
                        print("手势检测已重新启用")
                    }
                }
            }
        }
        .onChange(of: modelManager.isModelTestingEnabled) { _, newValue in
            handleModelTestingModeChange(newValue)
        }
    }
    
    private func setupResetNotificationListener() {
        let resetObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ResetAllVRStates"),
            object: nil,
            queue: .main
        ) { [self] _ in
            print("🧹 BasicPanoramaView: 收到重置通知")
            self.performFullReset()
        }
        
        notificationObservers.append(resetObserver)
        print("✅ 重置通知监听器已设置")
        
        // 🔥 添加关闭沉浸式空间和所有窗口的监听器
        let closeSpacesObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloseAllImmersiveSpaces"),
            object: nil,
            queue: .main
        ) { [self] _ in
            print("🚪 BasicPanoramaView: 收到关闭所有沉浸式空间通知")
            
            // 先关闭所有窗口
            self.dismissWindow(id: "ModelsListWindow")
            self.dismissWindow(id: "AIAssistantWindow")
            self.dismissWindow(id: "ControlMenuWindow")
            self.dismissWindow(id: "RealityWindow")
            self.dismissWindow(id: "BrushControlWindow")
            self.dismissWindow(id: "ModelControlWindow")
            print("🗑️ 所有窗口已请求关闭")
            
            // 然后退出沉浸式空间
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                await self.dismissImmersiveSpace()
                print("✅ 沉浸式空间已退出")
            }
        }
        
        notificationObservers.append(closeSpacesObserver)
        print("✅ 关闭沉浸式空间监听器已设置")
    }

    /// 执行完整的场景和状态重置
    private func performFullReset() {
        print("🔄 【开始全面重置BasicPanoramaView】")
        
        // 1️⃣ 停止所有手势跟踪
        handGestureManager.stopTracking()
        handTracking.stopTracking()
        regionSelectionHandTracking?.stopTracking()
        print("  ✓ 手势跟踪已停止")
        
        // 🌟 1️⃣.5️⃣ 停止手部附着（如果正在进行）
        if isModelAttachedToHand {
            print("  🤲 停止手部附着")
            handAttachmentTimer?.invalidate()
            handAttachmentTimer = nil
            handAttachedModel = nil
            isModelAttachedToHand = false
            handGestureManager.isTrackingHandPosition = false
        }
        print("  ✓ 手部附着状态已重置")
        
        // 2️⃣ 清除所有3D模型
        for model in placedModels {
            model.entity.removeFromParent()
        }
        placedModels.removeAll()
        hasTriedLoadingModels = false
        isModelsLoaded = false
        modelsLoadError = nil
        print("  ✓ 3D模型已清除")
        
        // 3️⃣ 重置绘画状态
        if brushManager.isPaintingEnabled {
            brushManager.isPaintingEnabled = false
        }
        paintingCanvas = PaintingCanvas()
        isPaintingLoaded = false
        paintingLoadError = nil
        hasTriedLoadingPainting = false
        isCurrentlyDrawing = false
        lastPinchPosition = nil
        isPinching = false
        print("  ✓ 绘画状态已重置")
        
        // 4️⃣ 清除问题数据
        questionsInSpace.removeAll()
        current3DViewId = nil
        isLoadingQuestions = false
        print("  ✓ 问题数据已清除")
        
        // 5️⃣ 重置场景状态
        isSceneReady = false
        isRootEntityInitialized = false
        isProcessingAddModel = false
        print("  ✓ 场景状态已重置")
        
        // 6️⃣ 重置选择和交互状态
        selectedQuestionId = nil
        hideOtherQuestionSpheres = false
        isRegionSelectionEnabled = false
        isMenuWindowOpen = false
        canDetectGesture = true
        print("  ✓ 交互状态已重置")
        
        // 7️⃣ 清空操作历史
        modelOperationHistory.removeAll()
        print("  ✓ 操作历史已清空")
        
        // 8️⃣ 重置所有变换状态
        gestureTranslation = .zero
        itemTranslations.removeAll()
        gestureScale = 1.0
        itemScales.removeAll()
        modelRotationX = 0
        modelRotationY = 0
        modelRotationZ = 0
        pendingModelAttributes.removeAll()
        print("  ✓ 变换状态已重置")
        
        // 9️⃣ 清除场景中的所有子实体（保留根实体）
        let childrenToRemove = rootEntity.children
        for child in childrenToRemove {
            child.removeFromParent()
        }
        print("  ✓ 场景实体已清除 (移除了 \(childrenToRemove.count) 个子实体)")
        
        // 🔟 重置管理器状态
        if modelManager.isModelTestingEnabled {
            modelManager.isModelTestingEnabled = false
        }
        print("  ✓ 管理器状态已重置")
        
        // 1️⃣1️⃣ 强制UI更新
        forceUpdateCounter += 1
        lastUpdateTime = Date()
        print("  ✓ UI更新计数器已重置")
        
        // 1️⃣2️⃣ 🔥 重新设置场景（天空球和地面）
        print("  🌍 开始重新设置场景...")
        Task { @MainActor in
            await self.setupChildEntities()
            print("  ✅ 场景重新设置完成")
        }
        
        // 1️⃣3️⃣ 🔥 重新加载所有问答圈（恢复初始状态）
        print("  🔄 开始重新加载问答圈...")
        Task {
            await self.load3DViewQuestions()
            print("  ✅ 问答圈重新加载完成")
        }
        
        // 1️⃣4️⃣ 🔥 重新启动手势跟踪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handGestureManager.startTracking()
            print("  ✅ 手势跟踪已重新启动")
        }
        
        print("✅ 【BasicPanoramaView 全面重置完成，所有问答圈已恢复显示】")
    }
    
    private func cleanupResources() {
        print("🧹 BasicPanoramaView: 开始清理资源")
        
        // 🌟 停止手部附着（如果正在进行）
        if isModelAttachedToHand {
            print("🤲 清理：停止手部附着")
            handAttachmentTimer?.invalidate()
            handAttachmentTimer = nil
            handAttachedModel = nil
            isModelAttachedToHand = false
            handGestureManager.isTrackingHandPosition = false
        }
        
        // 停止所有跟踪
        handGestureManager.stopTracking()
        handTracking.stopTracking()
        regionSelectionHandTracking?.stopTracking()
        
        // 移除所有通知监听器
        removeNotificationListeners()
        
        // 清除场景
        for child in rootEntity.children {
            child.removeFromParent()
        }
        
        print("✅ BasicPanoramaView: 资源清理完成")
    }


    // MARK: - 子实体设置

    @MainActor
    private func setupChildEntities() async {
        let sceneManager = SceneManager(vrManager: vrManager)

        // 创建天空球
        print("🌟【开始创建天空球】")
        let skybox = await sceneManager.createSkybox()
        skybox.name = "skybox"
        rootEntity.addChild(skybox)
        print("✅【天空球创建完成并已添加】")

        // 创建虚拟地面
        let ground = sceneManager.createVirtualGround()
        virtualGround = ground
        rootEntity.addChild(ground)
        print("✅【虚拟地面已添加到场景】")

        // 可选：添加地面网格
        if SceneManager.GroundConfig.showGrid {
            let grid = sceneManager.createGroundGrid()
            rootEntity.addChild(grid)
            print("✅【地面网格已添加】")
        }

        // 现有模型加载逻辑
        if modelManager.isModelTestingEnabled {
            for (index, model) in placedModels.enumerated() {
                rootEntity.addChild(model.entity)
                print("✅【模型已添加】\(index + 1)/\(placedModels.count): \(model.id)")
            }
        }

        // 场景就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isSceneReady = true
            print("🌟【延迟标记场景就绪】")

            Task { @MainActor in
                await self.updatePaintingCanvasInScene()
            }
        }
    }

    // MARK: - 模型测试模式处理

    private func handleModelTestingModeChange(_ newValue: Bool) {
        if newValue {
            Task {
                await loadAllModelsData()
            }
        } else {
            print("🧊 模型测试禁用，清除场景中的所有模型")
            clearAllModelsFromScene()
        }
    }

    public func clearAllModelsFromScene() {
        // 🌟 先停止手部附着（如果正在进行）
        if isModelAttachedToHand {
            print("🤲 检测到正在进行手部附着，先停止")
            handAttachmentTimer?.invalidate()
            handAttachmentTimer = nil
            handAttachedModel = nil
            isModelAttachedToHand = false
            handGestureManager.isTrackingHandPosition = false
        }
        
        for model in placedModels {
            model.entity.removeFromParent()
            print("🗑️ 从场景移除模型: \(model.entity.name)")
        }

        placedModels.removeAll()

        hasTriedLoadingModels = false
        isModelsLoaded = false
        modelsLoadError = nil

        DispatchQueue.main.async {
            self.forceUpdateCounter += 1
        }

        print("🧊 模型测试禁用完成，已清除模型并重置加载状态")
    }

    // MARK: - 控制菜单切换

    private func toggleControlMenu() {
        if isMenuWindowOpen {
            dismissWindow(id: "ControlMenuWindow")
            isMenuWindowOpen = false
        } else {
            openWindow(id: "ControlMenuWindow")
            isMenuWindowOpen = true
        }
    }
    
    func getUserFacingPosition(distanceInFront: Float = 2.0) -> SIMD3<Float> {
            print("📍【获取用户视线位置】")
            
            #if targetEnvironment(simulator)
            // 模拟器环境：使用估计值
            let estimatedPosition = SIMD3<Float>(0, 1.5, -distanceInFront)
            print("   🖥️ 模拟器模式，使用估计位置: \(estimatedPosition)")
            return estimatedPosition
            #else
            // 真机环境：使用 ARKit
            
            // 尝试获取设备锚点（Device Anchor）
            if let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
                // ✅ 获取设备的变换矩阵
                let transform = deviceAnchor.originFromAnchorTransform
                
                // 提取位置（平移部分）
                let position = SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )
                
                // 提取前方向量（-Z 方向，因为 ARKit 使用右手坐标系）
                let forward = SIMD3<Float>(
                    -transform.columns.2.x,
                    -transform.columns.2.y,
                    -transform.columns.2.z
                )
                
                // 归一化方向向量
                let normalizedForward = normalize(forward)
                
                // 计算目标位置：当前位置 + 前方向量 * 距离
                let targetPosition = position + normalizedForward * distanceInFront
                
                print("   ✅ ARKit 设备位置: \(position)")
                print("   📐 前方向量: \(normalizedForward)")
                print("   🎯 目标位置: \(targetPosition)")
                
                return targetPosition
                
            } else {
                // 如果无法获取设备锚点，使用估计值作为回退
                print("   ⚠️ 无法获取 ARKit 设备锚点，使用估计位置")
                let fallbackPosition = SIMD3<Float>(0, 1.5, -distanceInFront)
                return fallbackPosition
            }
            #endif
        }
        
        // MARK: - 获取用户视线方向（可选的辅助方法）
        /// 仅返回用户当前的视线方向向量
        /// - Returns: 归一化的方向向量
        func getUserFacingDirection() -> SIMD3<Float> {
            #if targetEnvironment(simulator)
            return SIMD3<Float>(0, 0, -1) // 模拟器默认朝向 -Z
            #else
            if let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
                let transform = deviceAnchor.originFromAnchorTransform
                let forward = SIMD3<Float>(
                    -transform.columns.2.x,
                    -transform.columns.2.y,
                    -transform.columns.2.z
                )
                return normalize(forward)
            } else {
                return SIMD3<Float>(0, 0, -1)
            }
            #endif
        }
        
        // MARK: - 获取用户当前位置（不包含方向）
        /// 仅返回用户头部/设备的当前位置
        /// - Returns: 设备的3D位置
        func getUserCurrentPosition() -> SIMD3<Float> {
            #if targetEnvironment(simulator)
            return SIMD3<Float>(0, 1.7, 0)
            #else
            if let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
                let transform = deviceAnchor.originFromAnchorTransform
                return SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )
            } else {
                return SIMD3<Float>(0, 1.7, 0)
            }
            #endif
        }
    
    // MARK: - 🌟 手部附着模型功能
    
    /// 开始将模型附着到手上
    func startAttachingModelToHand(modelType: ModelType, color: Color, size: Float, opacity: Float) {
        print("🤲【收到附着模型到手上请求】")
        
        // 🌟 检查模型测试模式是否启用
        guard modelManager.isModelTestingEnabled else {
            print("⚠️ 模型测试模式未启用，无法创建模型")
            return
        }
        
        // 🌟 如果已经有模型在附着，先停止
        if isModelAttachedToHand {
            print("⚠️ 已有模型在附着，先停止当前附着")
            stopAttachingModelToHand()
        }
        
        print("🤲【开始附着模型到手上】类型: \(modelType.rawValue)")
        
        // 获取手部位置，如果没有则使用用户前方位置
        let initialPosition: SIMD3<Float>
        if let handPos = handGestureManager.getPrimaryHandPosition() {
            initialPosition = handPos
            print("   ✅ 使用手部位置: \(handPos)")
        } else {
            initialPosition = getUserFacingPosition(distanceInFront: 0.5)
            print("   ⚠️ 未检测到手部，使用前方位置: \(initialPosition)")
        }
        
        // 创建模型
        let currentUserId = userManager.getUserId()
        let username = userManager.getUsername()
        let avatarUrl = userManager.getAvatarUrl()
        
        let model = createModelWithFullAttributes(
            position: initialPosition,
            scale: SIMD3<Float>(repeating: 0.8),  // 略小一点，便于观察
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            type: modelType,
            color: color,
            size: size,
            opacity: opacity,
            userId: currentUserId,
            text: nil,
            username: username,
            avatarUrl: avatarUrl
        )
        
        // 设置附着状态
        handAttachedModel = model
        isModelAttachedToHand = true
        handGestureManager.isTrackingHandPosition = true
        
        // 添加到场景
        placedModels.append(model)
        
        // 启动更新计时器
        startHandAttachmentTimer()
        
        print("✅【模型已创建并附着到手上】ID: \(model.id)")
    }
    
    /// 启动手部附着更新计时器
    private func startHandAttachmentTimer() {
        handAttachmentTimer?.invalidate()
        
        handAttachmentTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard
                  let model = self.handAttachedModel,
                  self.isModelAttachedToHand else {
                return
            }
            
            // 获取手部位置
            if let handPos = self.handGestureManager.getPrimaryHandPosition() {
                // 🔥 关键：直接更新模型位置到手部位置，不进行地面吸附
                model.entity.position = handPos
            }
        }
    }
    
    /// 停止附着，将模型固定在当前位置
    func stopAttachingModelToHand() {
        print("🤲【收到停止附着模型请求】")
        
        // 🌟 防御性检查：即使没有模型，也要清理状态
        guard let model = handAttachedModel else {
            print("⚠️ 没有找到附着的模型，仅清理状态")
            handAttachmentTimer?.invalidate()
            handAttachmentTimer = nil
            isModelAttachedToHand = false
            handGestureManager.isTrackingHandPosition = false
            return
        }
        
        print("🤲【停止附着模型到手上】ID: \(model.id)")
        
        // 停止计时器
        handAttachmentTimer?.invalidate()
        handAttachmentTimer = nil
        
        // 🌟 检查模型是否还在场景中
        guard model.entity.parent != nil else {
            print("⚠️ 模型已不在场景中，跳过位置更新")
            handAttachedModel = nil
            isModelAttachedToHand = false
            handGestureManager.isTrackingHandPosition = false
            return
        }
        
        // 获取最终位置
        let finalPosition = model.entity.position
        
        // 🔥 应用地面吸附到最终位置
        let sceneManager = SceneManager(vrManager: vrManager)
        let snappedPosition = sceneManager.calculateGroundSnapPosition(
            from: finalPosition,
            enableSnap: isGroundSnapEnabled
        )
        
        model.entity.position = snappedPosition
        
        // 更新模型记录
        if let index = placedModels.firstIndex(where: { $0.id == model.id }) {
            let updatedModel = PlacedModel(
                id: model.id,
                entity: model.entity,
                originalScale: model.originalScale,
                originalPosition: snappedPosition,  // 更新为吸附后的位置
                type: model.type,
                color: model.color,
                size: model.size,
                opacity: model.opacity,
                userId: model.userId,
                text: model.text,
                username: model.username,
                avatarUrl: model.avatarUrl
            )
            placedModels[index] = updatedModel
            
            // 记录操作
            let snapshot = ModelSnapshot(
                modelId: model.id,
                modelType: model.type,
                position: snappedPosition,
                scale: model.entity.scale,
                color: model.color,
                userId: model.userId
            )
            recordOperation(.add, snapshot: snapshot)
            
            print("✅【模型已固定并更新记录】最终位置: \(snappedPosition)")
        } else {
            print("⚠️ 未在 placedModels 中找到模型，仅固定位置")
        }
        
        // 重置状态
        handAttachedModel = nil
        isModelAttachedToHand = false
        handGestureManager.isTrackingHandPosition = false
        
        print("✅【手部附着状态已重置】")
    }
    
}

#Preview(immersionStyle: .full)
{
    BasicPanoramaView()
        .environmentObject({
            let manager = VRSessionManager.shared
            manager.updateLocationInfo(
                title: "华中农业大学梧桐广场",
                panoramaImage: "docklands_02"
            )
            return manager
        }())
}
