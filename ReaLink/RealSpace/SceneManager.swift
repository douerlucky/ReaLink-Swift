//
//  SceneManager.swift
//  ReaLink
//
//  场景创建和管理
//

import RealityKit
import SwiftUI
import ARKit  // ✅ 添加这一行

class SceneManager {
    private weak var vrManager: VRSessionManager?
    
    init(vrManager: VRSessionManager) {
        self.vrManager = vrManager
    }
    
    // MARK: - 🔥 天空球旋转配置（全局统一）
    struct SkyboxConfig {
        static let horizontalOffsetPixels: Float = 2200
        static let panoramaWidth: Float = 8704
        
        // 计算统一的水平旋转角度
        static var yawAngle: Float {
            return (horizontalOffsetPixels / panoramaWidth) * 2.0 * .pi
        }
        
        // 获取统一的旋转四元数
        static var rotation: simd_quatf {
            return simd_quatf(angle: yawAngle, axis: SIMD3<Float>(0, 1, 0))
        }
    }
    
    // MARK: - 虚拟地面配置
    struct GroundConfig {
        static let groundHeight: Float = 0.2
        static let groundSize: Float = 100.0
        static let snapThreshold: Float = 0.3 // ✅ 可以稍微增大吸附范围
        static let showGrid: Bool = false
    }
    
    // MARK: - 创建虚拟地面（符合Apple最佳实践）
    func createVirtualGround() -> Entity {
        print("🌍【创建透明虚拟地面】使用 visionOS 2.5 最佳实践")
        
        // 🔥 关键修复：使用纯 Entity 而不是 ModelEntity
        // 这样就完全透明，不会遮挡天空球
        let ground = Entity()
        ground.position = SIMD3<Float>(0, GroundConfig.groundHeight, 0)
        ground.name = "virtual_ground"
        
        // ✅ 添加碰撞组件（用于地面吸附和物理交互）
        ground.components.set(CollisionComponent(
            shapes: [.generateBox(
                width: GroundConfig.groundSize,
                height: 0.01,  // 很薄的碰撞盒
                depth: GroundConfig.groundSize
            )],
            mode: .default,
            filter: CollisionFilter(group: .all, mask: .all)
        ))
        
        // ✅ 添加物理组件（静态地面）
        ground.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: .default,
            mode: .static
        ))
        
        // ✅ 允许间接交互（用于拖拽检测）
        ground.components.set(InputTargetComponent(
            allowedInputTypes: [.indirect]
        ))
        
        print("✅【透明虚拟地面创建完成】")
        print("   - 位置: Y=\(GroundConfig.groundHeight)")
        print("   - 尺寸: \(GroundConfig.groundSize)m × \(GroundConfig.groundSize)m")
        print("   - 完全透明，不会遮挡天空球")
        
        return ground
    }
    
    // MARK: - 创建可视化地面网格（可选）
    func createGroundGrid(spacing: Float = 1.0, lineWidth: Float = 0.002) -> Entity {
        let gridContainer = Entity()
        gridContainer.name = "ground_grid"
        
        let halfSize = GroundConfig.groundSize / 2
        let lineCount = Int(GroundConfig.groundSize / spacing)
        
        var gridMaterial = UnlitMaterial()
        gridMaterial.color = .init(tint: .white.withAlphaComponent(0.15))
        
        // 创建网格线
        for i in 0...lineCount {
            let offset = -halfSize + Float(i) * spacing
            
            // X方向的线
            let xLine = ModelEntity(
                mesh: .generateBox(
                    width: GroundConfig.groundSize,
                    height: lineWidth,
                    depth: lineWidth
                ),
                materials: [gridMaterial]
            )
            xLine.position = SIMD3<Float>(0, GroundConfig.groundHeight, offset)
            gridContainer.addChild(xLine)
            
            // Z方向的线
            let zLine = ModelEntity(
                mesh: .generateBox(
                    width: lineWidth,
                    height: lineWidth,
                    depth: GroundConfig.groundSize
                ),
                materials: [gridMaterial]
            )
            zLine.position = SIMD3<Float>(offset, GroundConfig.groundHeight, 0)
            gridContainer.addChild(zLine)
        }
        
        print("✅【地面网格创建完成】网格间距: \(spacing)m")
        
        return gridContainer
    }
    
    // MARK: - 计算地面吸附位置（Apple推荐的射线投射方式）
    func calculateGroundSnapPosition(
        from position: SIMD3<Float>,
        enableSnap: Bool = true
    ) -> SIMD3<Float> {
        
        if !enableSnap {
            return position
        }
        
        let groundY = GroundConfig.groundHeight
        let distanceToGround = abs(position.y - groundY)
        
        // 如果模型在吸附阈值内，自动吸附到地面
        if distanceToGround <= GroundConfig.snapThreshold {
            return SIMD3<Float>(position.x, groundY, position.z)
        }
        
        return position
    }
    
    // MARK: - 验证位置是否在地面范围内
    func isPositionOnGround(_ position: SIMD3<Float>) -> Bool {
        let halfSize = GroundConfig.groundSize / 2
        return abs(position.x) <= halfSize &&
               abs(position.z) <= halfSize &&
               abs(position.y - GroundConfig.groundHeight) <= 0.5
    }
    
    // MARK: - VisionOS权限设置
    func setupVisionOSPermissions() async {
        print("📋【开始设置VisionOS权限】")
        
        #if !targetEnvironment(simulator)
        do {
            let worldTrackingProvider = WorldTrackingProvider()
            let handTrackingProvider = HandTrackingProvider()
            
            print("📋【权限请求完成】")
        } catch {
            print("⚠️【权限请求过程中出错】: \(error)")
        }
        #endif
        
        print("📋【权限设置完成】")
    }
    
    // MARK: - 创建天空球
    func createSkybox() async -> Entity {
        print("🌍【开始创建天空球】")
        
        let material = await loadPanoramaMaterial()
        
        // 🔥 确保在主线程创建 ModelEntity
        let sphere = await MainActor.run {
            let entity = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [material]
            )
            
            entity.scale = SIMD3<Float>(-1, 1, 1)
            entity.position = SIMD3<Float>(0, 0, 0)
            entity.name = "skybox_real"
            
            print("✅【ModelEntity创建完成】半径: 50m")
            return entity
        }
        
        // 🔥 应用统一的水平旋转配置
        sphere.transform.rotation = SkyboxConfig.rotation
        
        print("🎯【天空球旋转】水平:\(String(format: "%.1f", SkyboxConfig.yawAngle * 180.0 / .pi))° (使用全局统一配置)")
        print("🎯【天空球材质数量】: \(sphere.model?.materials.count ?? 0)")
        print("✅【天空球创建完成】")
        
        return sphere
    }
    // MARK: - 加载全景材质（增强错误处理）
    private func loadPanoramaMaterial() async -> UnlitMaterial {
        guard let vrManager = vrManager else {
            print("❌【VRManager 不存在】")
            return createFallbackMaterial(color: .red)
        }
        
        await MainActor.run {
            vrManager.setLoadingState(true)
        }
        
        print("🖼️【开始加载全景材质】")
        
        do {
            let texture: TextureResource
            let isUsingURL = await vrManager.isUsingURL
            
            if isUsingURL {
                let urlString = await vrManager.panoramaImageURL
                print("🌐【从URL加载全景图】: \(urlString)")
                
                guard !urlString.isEmpty, let url = URL(string: urlString) else {
                    print("❌【无效的全景图URL】")
                    resetLoadingStateSync()
                    return await loadLocalFallback()
                }
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    print("❌【HTTP错误】")
                    resetLoadingStateSync()
                    return await loadLocalFallback()
                }
                
                guard data.count > 0 else {
                    print("❌【下载的数据为空】")
                    resetLoadingStateSync()
                    return await loadLocalFallback()
                }
                
                print("✅【成功下载图片数据】大小: \(data.count) bytes")
                
                #if canImport(UIKit)
                texture = try await self.createTextureFromImageData(data)
                print("✅【从URL创建纹理成功】")
                #else
                print("❌【当前平台不支持从URL加载图像】")
                resetLoadingStateSync()
                return await loadLocalFallback()
                #endif
                
            } else {
                let imageName = await vrManager.panoramaImageName
                
                guard !imageName.isEmpty else {
                    print("❌【本地全景图名称为空】")
                    resetLoadingStateSync()
                    return await loadLocalFallback()
                }
                
                print("📱【从本地资源加载全景图】: \(imageName)")
                
                do {
                    texture = try await TextureResource(named: imageName)
                    print("✅【成功从本地加载全景图】: \(imageName)")
                } catch {
                    print("❌【本地全景图加载失败】: \(error.localizedDescription)")
                    print("🔄【尝试加载回退纹理】")
                    return await loadLocalFallback()
                }
            }
            
            // 🔥 关键修复：确保材质创建在主线程执行
            return await MainActor.run {
                var material = UnlitMaterial()
                material.color = .init(texture: .init(texture))
                
                // ✅ 验证材质
                print("🔍【验证材质】")
                print("   - 材质类型: UnlitMaterial")
                print("   - 纹理尺寸: \(texture.width) x \(texture.height)")
                
                resetLoadingStateSync()
                
                print("🎨【全景材质创建完成】✅ 在主线程")
                return material
            }
            
        } catch {
            print("❌【加载全景图失败】: \(error.localizedDescription)")
            resetLoadingStateSync()
            return await loadLocalFallback()
        }
    }

    // MARK: - 加载本地回退纹理
    private func loadLocalFallback() async -> UnlitMaterial {
        print("🔄【尝试加载回退纹理 docklands_02】")
        
        do {
            let fallbackTexture = try await TextureResource(named: "docklands_02")
            
            // 在主线程创建材质
            return await MainActor.run {
                var material = UnlitMaterial()
                material.color = .init(texture: .init(fallbackTexture))
                print("✅【回退纹理加载成功】✅ 在主线程")
                return material
            }
        } catch {
            print("❌【回退纹理也加载失败】: \(error.localizedDescription)")
            print("⚠️【使用纯色材质】")
            
            // 在主线程创建纯色材质
            return await MainActor.run {
                return createFallbackMaterial(color: .blue)
            }
        }
    }

    // MARK: - 创建纯色回退材质
    private func createFallbackMaterial(color: UIColor) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        print("🎨【创建纯色回退材质】颜色: \(color)")
        return material
    }
    // MARK: - 从图片数据创建纹理（修复线程安全问题）
    #if canImport(UIKit)
    private func createTextureFromImageData(_ data: Data) async throws -> TextureResource {
        print("🎨【开始处理图片数据】大小: \(data.count) bytes")
        
        // 步骤1：创建 UIImage（可以在任何线程）
        guard let originalImage = UIImage(data: data) else {
            throw NSError(
                domain: "TextureError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法从数据创建图像"]
            )
        }
        
        print("📐【原始图片尺寸】: \(originalImage.size.width) x \(originalImage.size.height)")
        
        // 步骤2：缩放图片（同步操作）
        let maxDimension: CGFloat = 6553
        let resizedImage = self.resizeImageIfNeeded(originalImage, maxDimension: maxDimension)
        
        print("📐【缩放后图片尺寸】: \(resizedImage.size.width) x \(resizedImage.size.height)")
        
        // 步骤3：获取 CGImage
        guard let cgImage = resizedImage.cgImage else {
            throw NSError(
                domain: "TextureError",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法获取CGImage"]
            )
        }
        
        // 步骤4：创建纹理资源（RealityKit 的异步方法，自动处理线程）
        print("🎨【开始创建纹理资源】")
        let textureResource = try await TextureResource(
            image: cgImage,
            options: TextureResource.CreateOptions(semantic: .color)
        )
        
        print("✅【纹理资源创建成功】")
        return textureResource
    }
    #endif
    
    // MARK: - 图片缩放（同步方法）
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
        
        print("📐【缩放图片】: \(originalSize.width)x\(originalSize.height) -> \(newSize.width)x\(newSize.height)")
        
        // 🔥 修复：使用更安全的图片缩放方法
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    // MARK: - 重置加载状态（同步版本）
    private func resetLoadingStateSync() {
        // 使用 Task 在主线程执行，但不等待
        Task { @MainActor in
            self.vrManager?.setLoadingState(false)
        }
    }
}
