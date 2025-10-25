
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
    }

    /// 执行完整的场景和状态重置
    private func performFullReset() {
        print("🔄 【开始全面重置BasicPanoramaView】")
        
        // 1️⃣ 停止所有手势跟踪
        handGestureManager.stopTracking()
        handTracking.stopTracking()
        regionSelectionHandTracking?.stopTracking()
        print("  ✓ 手势跟踪已停止")
        
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
        
        print("✅ 【BasicPanoramaView 全面重置完成】")
    }
    
    private func cleanupResources() {
        print("🧹 BasicPanoramaView: 开始清理资源")
        
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
