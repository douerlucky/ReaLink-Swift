import SwiftUI
import RealityKit
import RealityKitContent
import ARKit  // ✅ 添加ARKit导入

struct Question3DSet: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @EnvironmentObject var vrManager: VRSessionManager
    @EnvironmentObject var userManager: UserManager
    
    // 问题设置相关状态
    @State private var questionBallEntity: ModelEntity?
    @State private var isQuestionBallPlaced = false
    @State private var questionBallPosition: SIMD3<Float> = SIMD3<Float>(0, 1.5, -2.0) // 初始位置（会被手部位置覆盖）
    @State private var dragOffset: SIMD3<Float> = .zero
    @State private var isDragging = false
    
    // ✅ ARKit 手部和设备追踪
    @State private var arSession = ARKitSession()
    @State private var handTrackingProvider = HandTrackingProvider()
    @State private var worldTrackingProvider = WorldTrackingProvider()
    @State private var hasInitializedPosition = false  // 标记是否已经初始化位置
    
    // 回调函数
    let onPositionSet: (SIMD3<Float>) -> Void
    let onCancel: () -> Void
    
    // 根实体
    @State private var rootEntity = Entity()
    @State private var isRootEntityInitialized = false
    
    var body: some View {
        ZStack {
            // 主要RealityView内容
            RealityView { content in
                print("🎯【Question3DSet】RealityView初始化开始")
                
                // 创建并添加rootEntity
                rootEntity = Entity()
                rootEntity.name = "Question3DSetRootEntity"
                content.add(rootEntity)
                isRootEntityInitialized = true
                
                // 创建天空球
                Task { @MainActor in
                    await self.setupSkybox()
                    await self.createQuestionBall()
                }
                
            } update: { content in
                // 更新拖动偏移
                if let questionBall = questionBallEntity, isDragging {
                    questionBall.position = questionBallPosition + dragOffset
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
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        handleSpatialTap(value)
                    }
            )
            
            // 顶部提示UI
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎯 设置问题位置")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("拖动橙色球体到合适位置，单击球体确认位置")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button("取消") {
                        handleCancel()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
                
                Spacer()
            }
            
        }
        .onAppear {
            print("🎯【Question3DSet】视图出现")
            
            // ✅ 启动ARKit追踪
            Task {
                await startARKitTracking()
            }
        }
        .onDisappear {
            print("🎯【Question3DSet】视图消失")
            
            // ✅ 停止ARKit追踪
            Task {
                await arSession.stop()
            }
        }
    }
    
    // MARK: - 创建天空球
    @MainActor
    private func setupSkybox() async {
        guard isRootEntityInitialized else {
            print("⚠️ 根实体未初始化，延迟创建天空球")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task { await self.setupSkybox() }
            }
            return
        }
        
        let skybox = await createSkybox()
        skybox.name = "question_set_skybox"
        rootEntity.addChild(skybox)
        print("✅【Question3DSet】天空球创建完成")
    }
    
    private func createSkybox() async -> Entity {
        print("🌍【Question3DSet】开始创建天空球")
        
        // 先创建一个简单的测试材质确保球体可见
        var testMaterial = UnlitMaterial()
        testMaterial.color = .init(tint: .gray)
        
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 50),
            materials: [testMaterial]
        )
        
        // 翻转球体使内表面可见
        sphere.scale = SIMD3<Float>(-1, 1, 1)
        sphere.position = SIMD3<Float>(0, 0, 0)
        
        // 🔥 关键修复：应用与 BasicPanoramaView 相同的天空球旋转
        sphere.transform.rotation = SceneManager.SkyboxConfig.rotation
        print("🎯【Question3DSet】应用统一的天空球旋转: \(String(format: "%.1f", SceneManager.SkyboxConfig.yawAngle * 180.0 / .pi))°")
        
        // 异步加载真实材质
        Task {
            let realMaterial = await loadPanoramaMaterial()
            await MainActor.run {
                if var modelComponent = sphere.components[ModelComponent.self] {
                    modelComponent.materials = [realMaterial]
                    sphere.components.set(modelComponent)
                    print("🌍【Question3DSet】天空球材质已更新")
                }
            }
        }
        
        return sphere
    }
    
    private func loadPanoramaMaterial() async -> UnlitMaterial {
        print("🖼️【Question3DSet】开始加载全景材质")
        
        do {
            let texture: TextureResource
            
            if vrManager.isUsingURL {
                print("🌐【Question3DSet】从URL加载全景图: \(vrManager.panoramaImageURL)")
                
                guard let url = URL(string: vrManager.panoramaImageURL),
                      !vrManager.panoramaImageURL.isEmpty else {
                    print("❌【Question3DSet】无效的全景图URL")
                    return UnlitMaterial(color: .blue)
                }
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    print("❌【Question3DSet】HTTP错误: \(httpResponse.statusCode)")
                    return UnlitMaterial(color: .blue)
                }
                
                #if canImport(UIKit)
                texture = try await withCheckedThrowingContinuation { continuation in
                    Task {
                        do {
                            guard let originalImage = UIImage(data: data) else {
                                continuation.resume(throwing: NSError(domain: "TextureError", code: 1))
                                return
                            }
                            
                            let maxDimension: CGFloat = 6553
                            let resizedImage = resizeImageIfNeeded(originalImage, maxDimension: maxDimension)
                            
                            guard let cgImage = resizedImage.cgImage else {
                                continuation.resume(throwing: NSError(domain: "TextureError", code: 2))
                                return
                            }
                            
                            let textureResource = try await TextureResource(image: cgImage, options: TextureResource.CreateOptions(semantic: .color))
                            continuation.resume(returning: textureResource)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                #else
                return UnlitMaterial(color: .blue)
                #endif
                
            } else {
                guard !vrManager.panoramaImageName.isEmpty else {
                    print("❌【Question3DSet】本地全景图名称为空")
                    return UnlitMaterial(color: .blue)
                }
                
                print("📱【Question3DSet】从本地资源加载全景图: \(vrManager.panoramaImageName)")
                texture = try await TextureResource(named: vrManager.panoramaImageName)
            }
            
            var material = UnlitMaterial()
            material.color = .init(texture: .init(texture))
            material.blending = .transparent(opacity: 1.0)
            material.faceCulling = .back
            
            print("🎨【Question3DSet】全景材质创建完成")
            return material
            
        } catch {
            print("❌【Question3DSet】加载全景图失败: \(error.localizedDescription)")
            
            // 使用回退纹理
            do {
                let fallbackTexture = try await TextureResource(named: "docklands_02")
                var material = UnlitMaterial()
                material.color = .init(texture: .init(fallbackTexture))
                return material
            } catch {
                return UnlitMaterial(color: .blue)
            }
        }
    }
    
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size
        
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            return image
        }
        
        let widthRatio = maxDimension / originalSize.width
        let heightRatio = maxDimension / originalSize.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        let newSize = CGSize(
            width: originalSize.width * scaleFactor,
            height: originalSize.height * scaleFactor
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // MARK: - 创建问题球
    @MainActor
    private func createQuestionBall() async {
        guard isRootEntityInitialized else {
            print("⚠️ 根实体未初始化,延迟创建问题球")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task { await self.createQuestionBall() }
            }
            return
        }
        
        // ✅ 获取初始位置（手部位置或用户前方位置）
        let initialPosition = await getInitialBallPosition()
        questionBallPosition = initialPosition
        
        // 🔥 使用与BasicPanoramaView完全相同的材质配置
        let brightOrange = UnlitMaterial(color: .systemOrange)
        
        // 创建球体实体 - 使用相同的半径 0.1
        let ballEntity = ModelEntity(
            mesh: .generateSphere(radius: 0.1),
            materials: [brightOrange]
        )
        
        ballEntity.position = questionBallPosition
        ballEntity.name = "questionBall"
        
        // 设置为可交互 - 使用相同的配置
        ballEntity.components.set(InputTargetComponent(allowedInputTypes: [.indirect, .direct]))
        ballEntity.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)]))
        
        // 🔥 添加与BasicPanoramaView相同的悬停高亮效果
        let highlightStyle = HoverEffectComponent.HighlightHoverEffectStyle(
            color: .systemBlue,  // 悬停时变为蓝色
            strength: 2          // 高亮强度为2
        )
        let hoverEffect = HoverEffectComponent(.highlight(highlightStyle))
        ballEntity.components.set(hoverEffect)
        
        rootEntity.addChild(ballEntity)
        questionBallEntity = ballEntity
        
        print("🟠【Question3DSet】问题球创建完成(统一样式),位置: \(questionBallPosition)")
    }
    
    // ✅ 新增：获取问题球的初始位置
    @MainActor
    private func getInitialBallPosition() async -> SIMD3<Float> {
        #if targetEnvironment(simulator)
        // 模拟器：返回固定的前方位置
        return SIMD3<Float>(0, 1.5, -1.0)
        #else
        // 真机：尝试获取手部位置，但不长时间等待
        print("🤲【Question3DSet】尝试获取手部位置...")
        
        // 短暂等待ARKit初始化（0.3秒）
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // 尝试获取当前的手部锚点（非阻塞方式）
        var handPosition: SIMD3<Float>?
        
        // 创建一个超时任务
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒超时
        }
        
        // 创建一个获取手部位置的任务，显式指定返回类型为 SIMD3<Float>?
        let handTask = Task<SIMD3<Float>?, Never> { // <T, Failure> 这里的 Failure 是 Never
            for await update in handTrackingProvider.anchorUpdates {
                if case .added = update.event {
                    let handAnchor = update.anchor
                    return SIMD3<Float>(
                        handAnchor.originFromAnchorTransform.columns.3.x,
                        handAnchor.originFromAnchorTransform.columns.3.y,
                        handAnchor.originFromAnchorTransform.columns.3.z
                    )
                } else if case .updated = update.event {
                    let handAnchor = update.anchor
                    return SIMD3<Float>(
                        handAnchor.originFromAnchorTransform.columns.3.x,
                        handAnchor.originFromAnchorTransform.columns.3.y,
                        handAnchor.originFromAnchorTransform.columns.3.z
                    )
                }
            }
            // 当 for await 循环终止时（例如 handTrackingProvider 停止），返回 nil
            return nil
        }
        
        // 等待任一任务完成
        let result: SIMD3<Float>? = await withTaskGroup(of: SIMD3<Float>?.self) { group -> SIMD3<Float>? in
            group.addTask { await handTask.value }
            group.addTask {
                await timeoutTask.value
                return nil
            }
            
            // 返回第一个非nil结果
            for await value in group {
                if let pos = value {
                    group.cancelAll()
                    return pos
                }
            }
            return nil
        }
        
        if let position = result {
            print("✅【Question3DSet】使用手部位置: \(position)")
            return position
        }
        
        // 如果没有检测到手部，使用设备前方位置
        print("⚠️【Question3DSet】未检测到手部，使用设备前方位置")
        return getUserFacingPosition()
        #endif
    }
    
    // ✅ 新增：获取用户前方位置的辅助方法
    @MainActor
    private func getUserFacingPosition() -> SIMD3<Float> {
        #if targetEnvironment(simulator)
        return SIMD3<Float>(0, 1.5, -1.0)
        #else
        if let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
            let transform = deviceAnchor.originFromAnchorTransform
            let devicePosition = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            let forward = SIMD3<Float>(
                -transform.columns.2.x,
                -transform.columns.2.y,
                -transform.columns.2.z
            )
            // 用户前方0.8米，稍微偏低一点（手部高度）
            let position = devicePosition + normalize(forward) * 0.8 - SIMD3<Float>(0, 0.2, 0)
            print("📍【Question3DSet】使用设备前方位置: \(position)")
            return position
        }
        
        // 兜底：返回固定位置
        return SIMD3<Float>(0, 1.3, -1.0)
        #endif
    }

    
    // MARK: - 手势处理
    private func handleDragChanged(_ value: EntityTargetValue<DragGesture.Value>) {
        guard let questionBall = questionBallEntity,
              value.entity === questionBall else { return }
        
        if !isDragging {
            isDragging = true
            // ✅ 拖动时不需要停止动画了，因为没有动画
        }
        
        // 计算拖动偏移（相对于原始位置）
        let translation3D = value.convert(value.translation3D, from: .local, to: questionBall.parent!)
        dragOffset = translation3D
        
        print("🫳【Question3DSet】拖动问题球，偏移: \(dragOffset)")
    }

    
    private func handleDragEnded(_ value: EntityTargetValue<DragGesture.Value>) {
        guard let questionBall = questionBallEntity,
              value.entity === questionBall else { return }
        
        // 应用最终位置
        questionBallPosition = questionBall.position
        dragOffset = .zero
        isDragging = false
        
        // ✅ 不需要重新添加浮动动画 - 保持静态橙色球
        
        print("✅【Question3DSet】拖动结束,新位置: \(questionBallPosition)")
    }
    
    private func handleSpatialTap(_ value: EntityTargetValue<SpatialTapGesture.Value>) {
        guard let questionBall = questionBallEntity,
              value.entity === questionBall else { return }
        
        print("🎯【Question3DSet】点击问题球，确认位置")
        
        // ✅ 关键修改：只确认位置，不关闭ImmersiveView
        // ImmersiveView的关闭由QuestionView中的is3DViewOpen控制
        confirmQuestionPosition()
    }
    
    // ✅ 删除saveQuestionPosition方法（不再需要）

    
    // MARK: - 操作处理
    private func confirmQuestionPosition() {
        print("✅【Question3DSet】确认位置，位置: \(questionBallPosition)")
        
        // ✅ 只调用回调函数返回位置，不关闭ImmersiveView
        // ImmersiveView的关闭由QuestionView中的is3DViewOpen按钮控制
        onPositionSet(questionBallPosition)
        
        print("💡【Question3DSet】位置已确认，ImmersiveView保持打开状态")
    }
    
    private func handleCancel() {
        print("❌【Question3DSet】取消设置位置")
        
        // ✅ 只调用取消回调，不关闭ImmersiveView
        // ImmersiveView的关闭由QuestionView中的is3DViewOpen按钮控制
        onCancel()
        
        print("💡【Question3DSet】已取消位置设置，ImmersiveView保持打开状态")
    }
    
    // ✅ 新增：启动ARKit追踪
    @MainActor
    private func startARKitTracking() async {
        #if !targetEnvironment(simulator)
        do {
            print("🚀【Question3DSet】启动ARKit追踪...")
            
            // 请求手部追踪权限
            let handAuthStatus = await HandTrackingProvider.requestUserAuthorization()
            guard handAuthStatus == .allowed else {
                print("⚠️【Question3DSet】手部追踪权限被拒绝")
                return
            }
            
            // 启动ARKit session
            try await arSession.run([handTrackingProvider, worldTrackingProvider])
            print("✅【Question3DSet】ARKit追踪已启动")
            
        } catch {
            print("❌【Question3DSet】ARKit追踪启动失败: \(error)")
        }
        #endif
    }
}

// MARK: - 预览
#Preview(immersionStyle: .full) {
    Question3DSet(
        onPositionSet: { position in
            print("设置位置: \(position)")
        },
        onCancel: {
            print("取消设置")
        }
    )
    .environmentObject(VRSessionManager.shared)
}
