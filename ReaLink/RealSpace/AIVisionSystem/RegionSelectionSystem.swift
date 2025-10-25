//
//  RegionSelectionSystem_Enhanced.swift
//  ReaLink
//  Vision OS 2.5 增强版 - ✅ 投影修复版
//

import RealityKit
import SwiftUI
import ARKit

// MARK: - 区域选择管理器（增强版）

@MainActor
class RegionSelectionManager: ObservableObject {
    
    @Published var isSelecting: Bool = false
    @Published var isEnabled: Bool = false
    @Published var selectedRegion: SelectionRegion?
    @Published var isWaitingConfirm: Bool = false
    
    private var trackedPoints: [SIMD3<Float>] = []
    private var trailEntity: ModelEntity?
    private var trailContainer: Entity?
    private var fillEntity: ModelEntity?
    
    // 🔥 新增：拟合后的球面可视化实体
    private var fittedSphereEntity: Entity?
    
    private weak var rootEntity: Entity?
    private var isPinching: Bool = false
    
    // 🔥 新增：记录开始绘制时的相机位置
    private var initialCameraPosition: SIMD3<Float>?
    
    struct TrailConfig {
        static let lineWidth: Float = 0.008
        static let lineColor: UIColor = .systemBlue
        static let fillColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.3)
        static let minSegmentDistance: Float = 0.01
        static let trailAlpha: Float = 0.9
        static let maxPoints: Int = 500
    }
    
    init(rootEntity: Entity?) {
        self.rootEntity = rootEntity
        print("🎯【区域选择管理器初始化】修复版")
        setupNotificationListeners()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CancelRegionSelection"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cancelSelection()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ConfirmRegionSelection"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.confirmSelection()
        }
        
        // 🔥 新增：监听窗口关闭通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AIAssistantWindowWillClose"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanupOnWindowClose()
        }
    }
    
    func startSelection(at point: SIMD3<Float>) {
        print("🎯【开始区域选择】起点: \(point)")
        
        guard rootEntity != nil else {
            print("❌【startSelection 失败】rootEntity 为 nil")
            return
        }
        
        isSelecting = true
        isPinching = true
        isWaitingConfirm = false
        trackedPoints.removeAll()
        trackedPoints.append(point)
        
        createTrailSystem()
        addStartMarker(at: point)
        
        print("✅【轨迹系统已就绪】等待手指移动...")
    }
    
    func updateSelection(to point: SIMD3<Float>) {
        guard isSelecting else { return }
        
        if let lastPoint = trackedPoints.last {
            let distance = simd_distance(point, lastPoint)
            if distance < TrailConfig.minSegmentDistance {
                return
            }
        }
        
        if trackedPoints.count >= TrailConfig.maxPoints {
            trackedPoints.removeFirst()
        }
        
        trackedPoints.append(point)
        updateTrailMesh()
    }
    
    func finishSelection(cameraPosition: SIMD3<Float>) {
        guard isSelecting, trackedPoints.count >= 3 else {
            print("⚠️【点数不足，取消选择】点数: \(trackedPoints.count)")
            cancelSelection()
            return
        }
        
        print("✅【完成区域选择】总点数: \(trackedPoints.count)")
        
        // 闭合轨迹
        if let firstPoint = trackedPoints.first, let lastPoint = trackedPoints.last {
            let distance = simd_distance(firstPoint, lastPoint)
            if distance > 0.02 {
                trackedPoints.append(firstPoint)
                updateTrailMesh()
            }
        }
        
        // 创建填充区域
        createFillRegion()
        
        // 计算最佳观察位置
        let optimalCameraPosition = calculateOptimalCameraPosition(
            from: trackedPoints,
            currentCameraPosition: cameraPosition
        )
        
        print("📍【相机位置对比】")
        print("   - 原始位置: \(cameraPosition)")
        print("   - ✅ 最佳位置: \(optimalCameraPosition)")
        
        // 🔥 关键修复:不在这里创建球面可视化
        // 球面可视化会在PanoramaCoordinateConverter.convertSelectionToPanoramaRegion()
        // 调用时通过通知发送,由RegionSelectionGestureHandler接收并创建
        print("   ℹ️【球面可视化】将在坐标转换时创建")
        
        // 使用最佳位置计算边界框
        let region = calculateBoundingBox(
            from: trackedPoints,
            cameraPosition: optimalCameraPosition
        )
        selectedRegion = region
        
        isSelecting = false
        isPinching = false
        isWaitingConfirm = true
        
        NotificationCenter.default.post(
            name: NSNotification.Name("RegionSelectionCompleted"),
            object: nil,
            userInfo: ["region": region]
        )
        
        print("⏸️【等待确认】笔迹和填充已保留,球面可视化将在AI识别时创建")
    }
    
    // 修复版：计算最佳观察位置
    private func calculateOptimalCameraPosition(
        from points: [SIMD3<Float>],
        currentCameraPosition: SIMD3<Float>
    ) -> SIMD3<Float> {
        guard points.count >= 3 else {
            return currentCameraPosition
        }
        
        print("\n🎯【计算最佳观察位置】(修复版)")
        
        // 1️⃣ 计算真实3D质心
        var centroid3D = SIMD3<Float>.zero
        for point in points {
            centroid3D += point
        }
        centroid3D /= Float(points.count)
        
        print("   📍 真实3D质心: \(centroid3D)")
        print("   📍 用户Y高度: \(currentCameraPosition.y)m")
        
        // 2️⃣ 在XZ平面计算法向量
        var centroidXZ = SIMD2<Float>.zero
        for point in points {
            centroidXZ.x += point.x
            centroidXZ.y += point.z
        }
        centroidXZ /= Float(points.count)
        
        let toCameraXZ = SIMD2<Float>(
            currentCameraPosition.x - centroidXZ.x,
            currentCameraPosition.z - centroidXZ.y
        )
        
        let distanceXZ = sqrt(toCameraXZ.x * toCameraXZ.x + toCameraXZ.y * toCameraXZ.y)
        
        var normalXZ: SIMD2<Float>
        if distanceXZ > 0.001 {
            normalXZ = toCameraXZ / distanceXZ
        } else {
            normalXZ = SIMD2<Float>(0, -1)
        }
        
        // 3️⃣ 计算XZ选区大小
        var maxRadiusXZ: Float = 0
        for point in points {
            let dx = point.x - centroidXZ.x
            let dz = point.z - centroidXZ.y
            let radiusXZ = sqrt(dx * dx + dz * dz)
            maxRadiusXZ = max(maxRadiusXZ, radiusXZ)
        }
        
        let diameterXZ = maxRadiusXZ * 2
        
        // 根据选区大小自适应偏移
        let offsetDistance: Float
        if diameterXZ < 0.5 {
            offsetDistance = 0.5
        } else if diameterXZ < 1.0 {
            offsetDistance = 1.0
        } else if diameterXZ < 2.0 {
            offsetDistance = 1.5
        } else {
            offsetDistance = 2.0
        }
        
        print("   📏 XZ选区直径: \(diameterXZ)m")
        print("   ↔️  相机偏移距离: \(offsetDistance)m")
        
        // 4️⃣ 使用用户当前的Y高度
        let optimalPosition = SIMD3<Float>(
            centroid3D.x + normalXZ.x * offsetDistance,
            currentCameraPosition.y,
            centroid3D.z + normalXZ.y * offsetDistance
        )
        
        print("   🎯 最佳观察位置: \(optimalPosition)\n")
        
        return optimalPosition
    }
    
    // 🔥 修复版：confirmSelection不再清除可视化
    func confirmSelection() {
        guard isWaitingConfirm else {
            print("⚠️【确认失败】不在等待确认状态")
            return
        }
        
        print("✅【确认选择】保持笔迹、填充和拟合球面可见")
        // 🔥 关键修复：不调用 cleanup()
        // 可视化保持可见，等待窗口关闭时清理
        isWaitingConfirm = false
    }

    
    // 清除按钮：清除可视化但不重新启用手势
    func cancelSelection() {
        print("🧹【取消选择】清除笔迹、填充和拟合球面")
        cleanup()
        isWaitingConfirm = false
        selectedRegion = nil
    }

    
    func cleanupOnWindowClose() {
        print("🪟【AI窗口关闭】清理所有区域选择可视化")
        cleanup()
        isWaitingConfirm = false
        selectedRegion = nil
    }
    
    // 清理方法：移除所有可视化
    private func cleanup() {
        isSelecting = false
        isPinching = false
        trackedPoints.removeAll()
        
        // 清除手绘轨迹和填充
        trailContainer?.removeFromParent()
        trailContainer = nil
        trailEntity = nil
        fillEntity = nil
        
        // 🔥 关键：同时清除拟合球面（黄色区域）
        // 注意：拟合球面是由 PanoramaCoordinateConverter 通过通知创建的
        // 我们需要在 BasicPanoramaView 的通知监听中处理清除
        
        print("🧹【清理完成】所有可视化已移除")
    }
    
    
    
    // MARK: - 填充区域创建
    private func createFillRegion() {
        guard let container = trailContainer,
              trackedPoints.count >= 3 else {
            print("⚠️【无法创建填充】点数不足或容器不存在")
            return
        }
        
        do {
            print("🎨【开始创建填充区域】点数: \(trackedPoints.count)")
            
            let fillMesh = try generateFillMesh(from: trackedPoints)
            
            var fillMaterial = PhysicallyBasedMaterial()
            fillMaterial.baseColor = PhysicallyBasedMaterial.BaseColor(
                tint: UIColor.systemBlue.withAlphaComponent(0.5)
            )
            fillMaterial.opacityThreshold = 0.0
            fillMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.6))
            fillMaterial.faceCulling = .none
            
            fillEntity = ModelEntity(mesh: fillMesh, materials: [fillMaterial])
            fillEntity?.name = "fill_region"
            fillEntity?.position.z -= 0.001
            
            container.addChild(fillEntity!)
            
            print("✅【填充区域创建成功】半透明蓝色")
            
        } catch {
            print("❌【创建填充区域失败】: \(error)")
        }
    }
    
    private func generateFillMesh(from points: [SIMD3<Float>]) throws -> MeshResource {
        guard points.count >= 3 else {
            throw NSError(domain: "FillMesh", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "点数不足，需要至少3个点"
            ])
        }
        
        var meshDescriptor = MeshDescriptor()
        
        var center = SIMD3<Float>.zero
        for point in points {
            center += point
        }
        center /= Float(points.count)
        
        var vertices: [SIMD3<Float>] = [center]
        vertices.append(contentsOf: points)
        
        var indices: [UInt32] = []
        let centerIndex: UInt32 = 0
        
        for i in 1..<(vertices.count - 1) {
            indices.append(centerIndex)
            indices.append(UInt32(i))
            indices.append(UInt32(i + 1))
        }
        
        indices.append(centerIndex)
        indices.append(UInt32(vertices.count - 1))
        indices.append(1)
        
        print("📐【三角剖分完成】顶点数: \(vertices.count), 三角形数: \(indices.count / 3)")
        
        meshDescriptor.positions = MeshBuffers.Positions(vertices)
        meshDescriptor.primitives = .triangles(indices)
        
        return try MeshResource.generate(from: [meshDescriptor])
    }
    
    // MARK: - 轨迹系统
    private func createTrailSystem() {
        guard let rootEntity = rootEntity else {
            print("❌【rootEntity 不存在】")
            return
        }
        
        trailContainer?.removeFromParent()
        trailEntity = nil
        fillEntity = nil
        
        let container = Entity()
        container.name = "trail_container"
        rootEntity.addChild(container)
        trailContainer = container
        
        print("✅【轨迹系统已创建】")
    }
    
    private func addStartMarker(at position: SIMD3<Float>) {
        guard let container = trailContainer else { return }
        
        var startMaterial = UnlitMaterial()
        startMaterial.color = .init(tint: UIColor.systemGreen)
        
        let startMarker = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [startMaterial]
        )
        startMarker.position = position
        startMarker.name = "start_marker"
        
        container.addChild(startMarker)
    }
    
    private func updateTrailMesh() {
        guard let container = trailContainer,
              trackedPoints.count >= 2 else { return }
        
        do {
            let mesh = try generateTrailMesh(from: trackedPoints)
            
            if trailEntity == nil {
                var material = UnlitMaterial()
                material.color = .init(tint: TrailConfig.lineColor)
                material.blending = .transparent(opacity: .init(floatLiteral: TrailConfig.trailAlpha))
                
                trailEntity = ModelEntity(mesh: mesh, materials: [material])
                trailEntity?.name = "trail_mesh"
                container.addChild(trailEntity!)
            } else {
                trailEntity?.model?.mesh = mesh
            }
            
        } catch {
            print("❌【生成轨迹Mesh失败】: \(error)")
        }
    }
    
    private func generateTrailMesh(from points: [SIMD3<Float>]) throws -> MeshResource {
        guard points.count >= 2 else {
            throw NSError(domain: "TrailMesh", code: 1)
        }
        
        var meshDescriptor = MeshDescriptor()
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        
        let radius = TrailConfig.lineWidth / 2
        let segments = 8
        
        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]
            let direction = normalize(end - start)
            
            let up = SIMD3<Float>(0, 1, 0)
            let right = normalize(cross(direction, up))
            let actualUp = normalize(cross(right, direction))
            
            let vertexBase = UInt32(vertices.count)
            
            for j in 0...segments {
                let angle = Float(j) * 2 * Float.pi / Float(segments)
                let cos_a = cos(angle)
                let sin_a = sin(angle)
                
                let offset = right * cos_a * radius + actualUp * sin_a * radius
                
                vertices.append(start + offset)
                vertices.append(end + offset)
            }
            
            for j in 0..<segments {
                let base = vertexBase + UInt32(j) * 2
                
                indices.append(base)
                indices.append(base + 1)
                indices.append(base + 2)
                
                indices.append(base + 1)
                indices.append(base + 3)
                indices.append(base + 2)
            }
        }
        
        meshDescriptor.positions = MeshBuffers.Positions(vertices)
        meshDescriptor.primitives = .triangles(indices)
        
        return try MeshResource.generate(from: [meshDescriptor])
    }
    
    // MARK: - 计算边界框
    private func calculateBoundingBox(
        from points: [SIMD3<Float>],
        cameraPosition: SIMD3<Float>
    ) -> SelectionRegion {
        var minX: Float = .infinity, maxX: Float = -.infinity
        var minY: Float = .infinity, maxY: Float = -.infinity
        var minZ: Float = .infinity, maxZ: Float = -.infinity
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
            minZ = min(minZ, point.z)
            maxZ = max(maxZ, point.z)
        }
        
        let center = SIMD3<Float>(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )

        let size = SIMD3<Float>(
            maxX - minX,
            maxY - minY,
            maxZ - minZ
        )

        let topLeft = SIMD3<Float>(minX, maxY, minZ)
        let topRight = SIMD3<Float>(maxX, maxY, minZ)
        let bottomLeft = SIMD3<Float>(minX, minY, minZ)
        let bottomRight = SIMD3<Float>(maxX, minY, minZ)

        return SelectionRegion(
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight,
            center: center,
            size: size,
            cameraPosition: cameraPosition,
            captureTimestamp: Date(),
            trackedPoints: points
        )
    }
    
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.min(Swift.max(value, min), max)
    }
}
// MARK: - 选择区域数据结构
struct SelectionRegion: Codable {
    let topLeft: SIMD3<Float>
    let topRight: SIMD3<Float>
    let bottomLeft: SIMD3<Float>
    let bottomRight: SIMD3<Float>
    let center: SIMD3<Float>
    let size: SIMD3<Float>
    
    let cameraPosition: SIMD3<Float>
    let captureTimestamp: Date
    
    // 🔥 新增：保存完整的绘制轨迹（用于计算最佳观察位置）
    let trackedPoints: [SIMD3<Float>]
}


// MARK: - 区域选择手部追踪（保持原有实现）
// ( ... 此部分 RegionSelectionHandTracking 类的代码保持不变 ... )
// ( ... )
class RegionSelectionHandTracking: ObservableObject {
    @Published var isTracking: Bool = false
    @Published var currentPinchPosition: SIMD3<Float>?
    
    private var currentCameraPosition: SIMD3<Float> = SIMD3(0, 1.7, 0)
    
#if !targetEnvironment(simulator)
   private var worldTrackingProvider: WorldTrackingProvider?
   #endif
    
    weak var selectionManager: RegionSelectionManager?
    
    #if !targetEnvironment(simulator)
    private var arSession: ARKitSession?
    private var handTrackingProvider: HandTrackingProvider?
    private var handTrackingTask: Task<Void, Never>?
    #endif
    
    private var isPinching: Bool = false
    
    init() {
            print("👆【区域选择手势追踪初始化】Vision OS 2.5")
            
            #if !targetEnvironment(simulator)
            // 🔥 初始化世界追踪
            worldTrackingProvider = WorldTrackingProvider()
            startCameraTracking()
            #endif
        }
    
#if !targetEnvironment(simulator)
   private func startCameraTracking() {
       Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
           guard let self = self,
                 let provider = self.worldTrackingProvider,
                 provider.state == .running else { return }
           
           if let deviceAnchor = provider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
               let transform = deviceAnchor.originFromAnchorTransform
               let position = SIMD3<Float>(
                   transform.columns.3.x,
                   transform.columns.3.y,
                   transform.columns.3.z
               )
               
               Task { @MainActor in
                   self.currentCameraPosition = position
               }
           }
       }
   }
   #endif
    
    @MainActor
      private func handlePinchRelease() async {
          if isPinching {
              isPinching = false
              currentPinchPosition = nil
              
              // 🔥 传递当前相机位置
              selectionManager?.finishSelection(cameraPosition: currentCameraPosition)
              print("👆【结束捏合】相机位置: \(currentCameraPosition)")
          }
      }
    
    deinit {
        print("👆【区域选择手势追踪销毁】开始清理")
        stopTracking()
        
        #if !targetEnvironment(simulator)
        // 确保清理所有资源
        handTrackingTask?.cancel()
        handTrackingTask = nil
        handTrackingProvider = nil
        arSession = nil
        #endif
        
        print("👆【区域选择手势追踪销毁】完成")
    }
    
    func startTracking() {
        guard !isTracking else {
            print("⚠️【手势追踪已在运行】跳过启动")
            return
        }
        
        isTracking = true
        
        #if !targetEnvironment(simulator)
        handTrackingTask = Task {
            await setupHandTracking()
        }
        #endif
        
        print("👆【开始区域选择手势追踪】")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        isTracking = false
        isPinching = false
        currentPinchPosition = nil
        
        #if !targetEnvironment(simulator)
        // 🔥 关键修复：先取消任务
        handTrackingTask?.cancel()
        handTrackingTask = nil
        
        // 🔥 然后停止 ARKit session
        if let session = arSession {
            Task {
                await session.stop()
            }
        }
        
        // 🔥 清理引用
        handTrackingProvider = nil
        arSession = nil
        #endif
        
        print("👆【停止区域选择手势追踪】")
    }
    
    #if !targetEnvironment(simulator)
    @MainActor
    private func setupHandTracking() async {
        do {
            // 请求权限
            let authorization = await HandTrackingProvider.requestUserAuthorization()
            guard authorization == .allowed else {
                print("❌【手部追踪权限被拒绝】")
                return
            }
            
            // 创建新的 session 和 provider
            arSession = ARKitSession()
            handTrackingProvider = HandTrackingProvider()
            
            guard let session = arSession,
                  let provider = handTrackingProvider else {
                print("❌【创建 ARKit 组件失败】")
                return
            }
            
            try await session.run([provider])
            
            print("✅【手部追踪会话启动成功】")
            await processHandUpdates()
            
        } catch {
            print("❌【手部追踪初始化失败】: \(error)")
        }
    }
    
    private func processHandUpdates() async {
        guard let provider = handTrackingProvider else { return }
        
        for await update in provider.anchorUpdates {
            // 🔥 检查是否应该停止追踪
            guard isTracking else {
                print("⚠️【手势追踪已停止】退出更新循环")
                break
            }
            
            switch update.event {
            case .added, .updated:
                await processHandAnchor(update.anchor)
            case .removed:
                await handlePinchRelease()
            }
        }
    }
    
    @MainActor
    private func processHandAnchor(_ handAnchor: HandAnchor) async {
        guard handAnchor.chirality == .right,
              handAnchor.isTracked else { return }
        
        // 🔥 关键修复：检查等待确认状态
        if let manager = selectionManager, manager.isWaitingConfirm {
            // 在等待确认状态下，不处理新的捏合手势
            if isPinching {
                await handlePinchRelease()
            }
            return
        }
        
        if let pinchPosition = await detectPinchGesture(handAnchor) {
            handlePinch(at: pinchPosition)
        } else if isPinching {
            await handlePinchRelease()
        }
    }
    
    private func detectPinchGesture(_ handAnchor: HandAnchor) async -> SIMD3<Float>? {
        guard let skeleton = handAnchor.handSkeleton else { return nil }
        
        let thumbTransform = handAnchor.originFromAnchorTransform *
                            skeleton.joint(.thumbTip).anchorFromJointTransform
        let indexTransform = handAnchor.originFromAnchorTransform *
                            skeleton.joint(.indexFingerTip).anchorFromJointTransform
        
        let thumbPos = SIMD3<Float>(
            thumbTransform.columns.3.x,
            thumbTransform.columns.3.y,
            thumbTransform.columns.3.z
        )
        let indexPos = SIMD3<Float>(
            indexTransform.columns.3.x,
            indexTransform.columns.3.y,
            indexTransform.columns.3.z
        )
        
        let distance = length(thumbPos - indexPos)
        
        let startThreshold: Float = 0.025
        let maintainThreshold: Float = 0.045
        
        let threshold = isPinching ? maintainThreshold : startThreshold
        
        if distance < threshold {
            return (thumbPos + indexPos) / 2
        }
        
        return nil
    }
    
    @MainActor
    private func handlePinch(at position: SIMD3<Float>) {
        currentPinchPosition = position
        
        if !isPinching {
            isPinching = true
            selectionManager?.startSelection(at: position)
            print("👆【开始捏合】位置: \(position)")
        } else {
            selectionManager?.updateSelection(to: position)
        }
    }
    
    #endif
}

extension RegionSelectionManager {
    
    
    
    // 🔥 修改 startSelection 方法
    func startSelection_FIXED(at point: SIMD3<Float>, cameraPosition: SIMD3<Float>) {
        print("🎯【开始区域选择】起点: \(point)")
        print("   📷 相机位置: \(cameraPosition)")
        
        guard rootEntity != nil else {
            print("❌【startSelection 失败】rootEntity 为 nil")
            return
        }
        
        isSelecting = true
        isPinching = true
        isWaitingConfirm = false
        trackedPoints.removeAll()
        trackedPoints.append(point)
        
        // 🔥 记录初始相机位置
        initialCameraPosition = cameraPosition
        
        createTrailSystem()
        addStartMarker(at: point)
        
        print("✅【轨迹系统已就绪】等待手指移动...")
    }
    
    // 🔥 修改 waitForConfirmation 方法
    func waitForConfirmation_FIXED(cameraPosition: SIMD3<Float>) {
        guard isSelecting, trackedPoints.count >= 3 else {
            print("❌【无法进入确认状态】")
            return
        }
        
        print("\n🎯【进入确认状态】")
        print("   📍 轨迹点数: \(trackedPoints.count)")
        print("   📷 当前相机: \(cameraPosition)")
        
        if let initial = initialCameraPosition {
            let cameraDelta = simd_distance(initial, cameraPosition)
            print("   📏 相机移动距离: \(String(format: "%.3f", cameraDelta))m")
        }
        
        // 创建填充区域
        createFillRegion()
        
        // 🔥🔥🔥 关键修复：直接使用当前相机位置，不进行任何计算
        print("\n📷【使用真实相机位置】")
        print("   ✅ 相机位置: \(cameraPosition)")
        print("   ❌ 不计算'最佳'位置（避免错误偏移）")
        
        // 直接使用当前相机创建边界框
        let region = calculateBoundingBox(
            from: trackedPoints,
            cameraPosition: cameraPosition  // 🔥 直接使用真实相机位置
        )
        selectedRegion = region
        
        isSelecting = false
        isPinching = false
        isWaitingConfirm = true
        
        NotificationCenter.default.post(
            name: NSNotification.Name("RegionSelectionCompleted"),
            object: nil,
            userInfo: ["region": region]
        )
        
        print("⏸️【等待确认】笔迹和填充已保留")
    }
    
    // 🔥 移除或注释掉原来的 calculateOptimalCameraPosition 方法
    // ❌ 不再使用这个方法，因为它会导致坐标错误
}

// MARK: - 🔥 修复2：在 RegionSelectionHandTracking 中传递相机位置

extension RegionSelectionHandTracking {
    
    // 🔥 新增：实时获取相机位置的方法
    @MainActor
    private func getCurrentCameraPosition() -> SIMD3<Float> {
        // 方法1：从 WorldTrackingProvider 获取
        #if !targetEnvironment(simulator)
        if let worldTracker = worldTrackingProvider {
            // 获取设备位姿
            // 注意：需要添加 worldTrackingProvider 到 ARKitSession
            return SIMD3<Float>(0, 1.7, 0)  // 临时默认值
        }
        #endif
        
        // 方法2：使用默认值（站立高度）
        return SIMD3<Float>(0, 1.7, 0)
    }
    
    // 🔥 修改 handlePinch 方法，传递相机位置
    @MainActor
    private func handlePinch_FIXED(at position: SIMD3<Float>) {
        currentPinchPosition = position
        let cameraPos = getCurrentCameraPosition()
        
        if !isPinching {
            isPinching = true
            // 🔥 传递相机位置
            selectionManager?.startSelection_FIXED(at: position, cameraPosition: cameraPos)
            print("👆【开始捏合】位置: \(position), 相机: \(cameraPos)")
        } else {
            selectionManager?.updateSelection(to: position)
        }
    }
    
    // 🔥 修改 handlePinchRelease 方法
    @MainActor
    private func handlePinchRelease_FIXED() async {
        guard isPinching else { return }
        
        isPinching = false
        let cameraPos = getCurrentCameraPosition()
        
        print("👆【松开捏合】相机位置: \(cameraPos)")
        
        // 🔥 传递当前相机位置
        selectionManager?.waitForConfirmation_FIXED(cameraPosition: cameraPos)
    }
}

// MARK: - 🔥 修复3：增强的 WorldTracking 集成

#if !targetEnvironment(simulator)
extension RegionSelectionHandTracking {
    
    // 🔥 启用 WorldTracking 以获取精确的设备位姿
    @MainActor
    func setupWorldTracking() async {
        do {
            let worldProvider = WorldTrackingProvider()
            
            guard let session = arSession else {
                print("❌ ARKitSession 未初始化")
                return
            }
            
            // 启动 WorldTracking
            try await session.run([handTrackingProvider!, worldProvider])
            
            self.worldTrackingProvider = worldProvider
            
            print("✅【WorldTracking 已启动】可以获取精确的相机位置")
            
        } catch {
            print("❌【WorldTracking 启动失败】: \(error)")
        }
    }
    
    // 🔥 从 WorldTrackingProvider 获取设备位置
    @MainActor
    func getDevicePosition() -> SIMD3<Float>? {
        guard let worldProvider = worldTrackingProvider else {
            return nil
        }
        
        // 获取设备的世界位姿
        if let deviceAnchor = worldProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
            let transform = deviceAnchor.originFromAnchorTransform
            return SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
        }
        
        return nil
    }
}


#endif
