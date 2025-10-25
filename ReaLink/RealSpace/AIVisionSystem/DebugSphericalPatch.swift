//
//  DebugSphericalPatch.swift
//  🎯 调试工具：在球面上创建可视化的目标区域
//
//  用途：显示全景图特定像素区域对应的3D球面位置
//  这样用户可以看到"正确答案"在哪里，然后调试投影算法
//

import RealityKit
import SwiftUI

class DebugSphericalPatch {
    
    // MARK: - 配置
    struct Config {
        static let sphereRadius: Float = 50.0  // 天空球半径
        static let patchColor: UIColor = .blue.withAlphaComponent(0.3)  // 半透明蓝色
        static let gridLineColor: UIColor = .white.withAlphaComponent(0.5)
    }
    
    // MARK: - 🎯 创建目标区域的球面片段
    /// - Parameters:
    ///   - expectedPixelRegion: 期望的2D像素坐标区域
    ///   - panoramaSize: 全景图尺寸
    /// - Returns: 可视化的球面片段实体
    static func createTargetPatch(
        expectedTopLeft: (x: Int, y: Int),
        expectedBottomRight: (x: Int, y: Int),
        panoramaWidth: Int = 8704,
        panoramaHeight: Int = 4352
    ) -> Entity {
        
        print("\n" + String(repeating: "=", count: 80))
        print("🎯【创建调试球面片段】")
        print(String(repeating: "=", count: 80))
        
        // 1. 像素坐标 → UV坐标
        let uvTopLeft = pixelToUV(
            x: expectedTopLeft.x,
            y: expectedTopLeft.y,
            width: panoramaWidth,
            height: panoramaHeight
        )
        let uvBottomRight = pixelToUV(
            x: expectedBottomRight.x,
            y: expectedBottomRight.y,
            width: panoramaWidth,
            height: panoramaHeight
        )
        
        print("📊【UV坐标范围】")
        print("   左上: U=\(String(format: "%.4f", uvTopLeft.u)), V=\(String(format: "%.4f", uvTopLeft.v))")
        print("   右下: U=\(String(format: "%.4f", uvBottomRight.u)), V=\(String(format: "%.4f", uvBottomRight.v))")
        
        // 2. UV坐标 → 球面坐标（方位角、仰角）
        let azimuthStart = (uvTopLeft.u - 0.5) * 2.0 * .pi  // U=0.5对应0度（正前方）
        let azimuthEnd = (uvBottomRight.u - 0.5) * 2.0 * .pi
        let elevationTop = (0.5 - uvTopLeft.v) * .pi  // V=0.5对应水平线
        let elevationBottom = (0.5 - uvBottomRight.v) * .pi
        
        print("📐【球面坐标范围】")
        print("   方位角: \(radToDeg(azimuthStart))° → \(radToDeg(azimuthEnd))°")
        print("   仰角: \(radToDeg(elevationTop))° → \(radToDeg(elevationBottom))°")
        
        // 3. 创建球面网格
        let patchContainer = Entity()
        patchContainer.name = "debug_spherical_patch"
        
        // 创建网格（用多个小四边形拼接成球面片段）
        let uSteps = 20  // U方向分段数
        let vSteps = 20  // V方向分段数
        
        let uStep = (azimuthEnd - azimuthStart) / Float(uSteps)
        let vStep = (elevationBottom - elevationTop) / Float(vSteps)
        
        var material = UnlitMaterial()
        material.color = .init(tint: Config.patchColor)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.3))
        
        // 创建网格面片
        for i in 0..<uSteps {
            for j in 0..<vSteps {
                let azimuth1 = azimuthStart + Float(i) * uStep
                let azimuth2 = azimuthStart + Float(i + 1) * uStep
                let elevation1 = elevationTop + Float(j) * vStep
                let elevation2 = elevationTop + Float(j + 1) * vStep
                
                // 计算四个顶点的3D位置
                let p1 = sphericalToCartesian(azimuth: azimuth1, elevation: elevation1, radius: Config.sphereRadius)
                let p2 = sphericalToCartesian(azimuth: azimuth2, elevation: elevation1, radius: Config.sphereRadius)
                let p3 = sphericalToCartesian(azimuth: azimuth2, elevation: elevation2, radius: Config.sphereRadius)
                let p4 = sphericalToCartesian(azimuth: azimuth1, elevation: elevation2, radius: Config.sphereRadius)
                
                // 创建四边形（用两个三角形）
                let quad = createQuadMesh(p1: p1, p2: p2, p3: p3, p4: p4, material: material)
                patchContainer.addChild(quad)
            }
        }
        
        // 4. 添加边界线（方便看清区域）
        addBoundaryLines(
            to: patchContainer,
            azimuthStart: azimuthStart,
            azimuthEnd: azimuthEnd,
            elevationTop: elevationTop,
            elevationBottom: elevationBottom
        )
        
        // 5. 添加标签
        addDebugLabels(
            to: patchContainer,
            azimuthCenter: (azimuthStart + azimuthEnd) / 2,
            elevationCenter: (elevationTop + elevationBottom) / 2,
            expectedTopLeft: expectedTopLeft,
            expectedBottomRight: expectedBottomRight
        )
        
        print("\n✅【球面片段创建完成】")
        print("   - 位置：方位角 \(radToDeg(azimuthStart))° - \(radToDeg(azimuthEnd))°")
        print("   - 仰角：\(radToDeg(elevationTop))° - \(radToDeg(elevationBottom))°")
        print("   - 网格：\(uSteps)×\(vSteps) 面片")
        print(String(repeating: "=", count: 80) + "\n")
        
        return patchContainer
    }
    
    // MARK: - 🌐 球面坐标转笛卡尔坐标
    /// Vision Pro坐标系：+X右，+Y上，+Z前（朝向用户）
    /// 全景图：U=0在正前方（-Z），U增加向右旋转（顺时针俯视）
    private static func sphericalToCartesian(
        azimuth: Float,  // 方位角（弧度），0=正前方，正值=向右转
        elevation: Float,  // 仰角（弧度），0=水平，正值=向上
        radius: Float
    ) -> SIMD3<Float> {
        
        // 🔥 关键：正确的球面坐标转换
        // azimuth=0应该对应-Z方向（正前方）
        // azimuth=π/2应该对应+X方向（右侧）
        
        let x = radius * cos(elevation) * sin(azimuth)
        let y = radius * sin(elevation)
        let z = -radius * cos(elevation) * cos(azimuth)  // 负号让azimuth=0对应-Z
        
        return SIMD3<Float>(x, y, z)
    }
    
    // MARK: - 📐 像素坐标 → UV坐标
    private static func pixelToUV(x: Int, y: Int, width: Int, height: Int) -> (u: Float, v: Float) {
        let u = Float(x) / Float(width)
        let v = Float(y) / Float(height)
        return (u: u, v: v)
    }
    
    // MARK: - 🔢 弧度转角度（方便阅读）
    private static func radToDeg(_ rad: Float) -> String {
        return String(format: "%.1f", rad * 180.0 / .pi)
    }
    
    // MARK: - 🔲 创建四边形网格
    private static func createQuadMesh(
        p1: SIMD3<Float>,
        p2: SIMD3<Float>,
        p3: SIMD3<Float>,
        p4: SIMD3<Float>,
        material: UnlitMaterial
    ) -> ModelEntity {
        
        // 计算中心点
        let center = (p1 + p2 + p3 + p4) / 4.0
        
        // 创建一个小平面（用于可视化）
        // 注意：这里用小平面近似球面，分段够密集就能看起来是弯曲的
        let quadSize: Float = 0.5
        let quad = ModelEntity(
            mesh: .generatePlane(width: quadSize, depth: quadSize),
            materials: [material]
        )
        
        quad.position = center
        
        // 让四边形面朝相机（法向量指向球心外）
        quad.look(at: SIMD3<Float>(0, center.y, 0), from: center, relativeTo: nil)
        
        return quad
    }
    
    // MARK: - 📏 添加边界线
    private static func addBoundaryLines(
        to container: Entity,
        azimuthStart: Float,
        azimuthEnd: Float,
        elevationTop: Float,
        elevationBottom: Float
    ) {
        
        var lineMaterial = UnlitMaterial()
        lineMaterial.color = .init(tint: Config.gridLineColor)
        
        let lineRadius = Config.sphereRadius + 0.1  // 稍微突出一点
        let lineWidth: Float = 0.05
        
        // 绘制四条边界
        let steps = 50  // 每条边的分段数
        
        // 上边界
        for i in 0..<steps {
            let t = Float(i) / Float(steps)
            let azimuth = azimuthStart + t * (azimuthEnd - azimuthStart)
            let p1 = sphericalToCartesian(azimuth: azimuth, elevation: elevationTop, radius: lineRadius)
            
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: lineWidth),
                materials: [lineMaterial]
            )
            sphere.position = p1
            container.addChild(sphere)
        }
        
        // 下边界
        for i in 0..<steps {
            let t = Float(i) / Float(steps)
            let azimuth = azimuthStart + t * (azimuthEnd - azimuthStart)
            let p1 = sphericalToCartesian(azimuth: azimuth, elevation: elevationBottom, radius: lineRadius)
            
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: lineWidth),
                materials: [lineMaterial]
            )
            sphere.position = p1
            container.addChild(sphere)
        }
        
        // 左边界
        for i in 0..<steps {
            let t = Float(i) / Float(steps)
            let elevation = elevationTop + t * (elevationBottom - elevationTop)
            let p1 = sphericalToCartesian(azimuth: azimuthStart, elevation: elevation, radius: lineRadius)
            
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: lineWidth),
                materials: [lineMaterial]
            )
            sphere.position = p1
            container.addChild(sphere)
        }
        
        // 右边界
        for i in 0..<steps {
            let t = Float(i) / Float(steps)
            let elevation = elevationTop + t * (elevationBottom - elevationTop)
            let p1 = sphericalToCartesian(azimuth: azimuthEnd, elevation: elevation, radius: lineRadius)
            
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: lineWidth),
                materials: [lineMaterial]
            )
            sphere.position = p1
            container.addChild(sphere)
        }
    }
    
    // MARK: - 🏷️ 添加调试标签
    private static func addDebugLabels(
        to container: Entity,
        azimuthCenter: Float,
        elevationCenter: Float,
        expectedTopLeft: (x: Int, y: Int),
        expectedBottomRight: (x: Int, y: Int)
    ) {
        // 在区域中心创建一个大一点的标记球
        let centerPos = sphericalToCartesian(
            azimuth: azimuthCenter,
            elevation: elevationCenter,
            radius: Config.sphereRadius + 1.0
        )
        
        var centerMaterial = UnlitMaterial()
        centerMaterial.color = .init(tint: .red)
        
        let centerMarker = ModelEntity(
            mesh: .generateSphere(radius: 0.2),
            materials: [centerMaterial]
        )
        centerMarker.position = centerPos
        centerMarker.name = "target_center_marker"
        container.addChild(centerMarker)
        
        print("🎯【目标区域中心标记】")
        print("   位置: (\(String(format: "%.2f", centerPos.x)), \(String(format: "%.2f", centerPos.y)), \(String(format: "%.2f", centerPos.z)))")
    }
    
    // MARK: - 🎯 快速创建预设区域
    static func createUserExpectedRegion() -> Entity {
        // 用户期望的区域：左上(2840, 1122)，右下(5631, 2494)
        return createTargetPatch(
            expectedTopLeft: (x: 2840, y: 1122),
            expectedBottomRight: (x: 5631, y: 2494),
            panoramaWidth: 8704,
            panoramaHeight: 4352
        )
    }
}

// MARK: - 🔧 集成到BasicPanoramaView的扩展

extension BasicPanoramaView {
    
    /// 🎯 显示调试球面片段
    func showDebugSphericalPatch() {
        print("🎯【启动调试球面可视化】")
        
        // 创建期望区域的球面片段
        let debugPatch = DebugSphericalPatch.createUserExpectedRegion()
        
        // 添加到场景
        rootEntity.addChild(debugPatch)
        
        print("✅【调试球面已添加到场景】")
        print("   - 半透明蓝色区域 = 你期望的全景图区域")
        print("   - 红色球 = 区域中心")
        print("   - 白色边框 = 区域边界")
        print("\n🎯【下一步】：用手画这个蓝色区域，看看算法输出的坐标是否匹配！")
    }
    
    /// 🗑️ 隐藏调试球面片段
    func hideDebugSphericalPatch() {
        rootEntity.children.forEach { child in
            if child.name == "debug_spherical_patch" {
                child.removeFromParent()
            }
        }
        print("✅【调试球面已移除】")
    }
}

// MARK: - 使用说明
/*
 📖 使用方法：
 
 1. 在BasicPanoramaView加载完成后调用：
    view.showDebugSphericalPatch()
 
 2. 你会看到：
    - 半透明蓝色的球面片段 → 这就是像素(2840,1122)-(5631,2494)对应的3D位置
    - 红色标记球 → 区域中心
    - 白色边框线 → 区域边界
 
 3. 用手画这个蓝色区域，然后检查算法输出的坐标：
    - 如果输出接近(2840,1122)-(5631,2494) → 算法正确！
    - 如果偏差很大 → 说明投影算法有问题，需要修正
 
 4. 移除调试球面：
    view.hideDebugSphericalPatch()
 
 🎯 关键：这个可视化工具让你能"看到正确答案"，从而调试投影算法！
 */
