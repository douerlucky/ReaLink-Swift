import SwiftUI
import RealityKit
import RealityKitContent

struct Question3DSet: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @EnvironmentObject var vrManager: VRSessionManager
    @EnvironmentObject var userManager: UserManager
    
    // 问题设置相关状态
    @State private var questionBallEntity: ModelEntity?
    @State private var isQuestionBallPlaced = false
    @State private var questionBallPosition: SIMD3<Float> = SIMD3<Float>(0, 1.5, -2.0) // 初始位置在用户前方
    @State private var showConfirmDialog = false
    @State private var dragOffset: SIMD3<Float> = .zero
    @State private var isDragging = false
    
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
                        
                        Text("拖动橙色球体到合适的位置，然后点击确认")
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
            
            // 确认对话框
            if showConfirmDialog {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("确认位置")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("是否将问题球放置在当前位置？")
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        Button("取消") {
                            showConfirmDialog = false
                        }
                        .buttonStyle(.bordered)
                        
                        Button("确认") {
                            confirmQuestionPosition()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 10)
            }
        }
        .onAppear {
            print("🎯【Question3DSet】视图出现")
        }
        .onDisappear {
            print("🎯【Question3DSet】视图消失")
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
        
        print("🎯【Question3DSet】点击问题球，保存位置但不退出")
        
        // ✅ 修改：只保存位置，不退出实景
        saveQuestionPosition()
    }
    
    // ✅ 新增：保存位置但不退出
    private func saveQuestionPosition() {
        print("✅【Question3DSet】保存问题位置: \(questionBallPosition)")
        
        // 调用回调函数返回位置
        onPositionSet(questionBallPosition)
        
        // ✅ 不退出实景，让用户可以继续调整或查看
        // 用户需要点击"取消"按钮才能退出
        
        // 可选：给用户一个视觉反馈
        if let questionBall = questionBallEntity {
            // 添加一个短暂的颜色变化或缩放效果
            var greenMaterial = SimpleMaterial()
            greenMaterial.color = .init(tint: .green)
            
            if var modelComponent = questionBall.components[ModelComponent.self] {
                modelComponent.materials = [greenMaterial]
                questionBall.components.set(modelComponent)
            }
            
            // 0.5秒后恢复橙色
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                var orangeMaterial = SimpleMaterial()
                orangeMaterial.color = .init(tint: .orange)
                
                if var modelComponent = questionBall.components[ModelComponent.self] {
                    modelComponent.materials = [orangeMaterial]
                    questionBall.components.set(modelComponent)
                }
            }
        }
    }

    
    // MARK: - 操作处理
    private func confirmQuestionPosition() {
        print("✅【Question3DSet】最终确认并退出")
        
        // 调用回调函数返回位置
        onPositionSet(questionBallPosition)
        
        // 退出当前空间
        Task {
            await dismissImmersiveSpace()
        }
    }
    
    private func handleCancel() {
        print("❌【Question3DSet】取消设置位置并退出")
        
        // 调用取消回调
        onCancel()
        
        // 退出当前空间
        Task {
            await dismissImmersiveSpace()
        }
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
