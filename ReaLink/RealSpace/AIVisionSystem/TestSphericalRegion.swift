//
//  TestSphericalRegion_Fixed.swift
//  ✅ 修复UV跨越边界时的可视化 - 支持两段拼接
//

import RealityKit
import SwiftUI

class TestSphericalRegion {
    
    struct Config {
        static let patchColor: UIColor = .cyan.withAlphaComponent(0.3)
        static let gridLineColor: UIColor = .yellow.withAlphaComponent(0.7)
        static let centerMarkerColor: UIColor = .red
    }
    
    // MARK: - 🎯 创建拟合后的球面区域可视化（修复版）
    /// 支持UV跨越边界时的两段拼接可视化
    static func createFittedRegionVisualizationFixed(
        azimuthRange: (Float, Float),
        elevationRange: (Float, Float),
        radius: Float,
        isWrapping: Bool = false,
        segment1Azimuth: (Float, Float)? = nil,
        segment2Azimuth: (Float, Float)? = nil
    ) -> Entity {
        
        print("\n" + String(repeating: "=", count: 80))
        print("🎨【创建拟合球面可视化（修复版）】")
        print(String(repeating: "=", count: 80))
        
        let container = Entity()
        container.name = "fitted_spherical_region_fixed"
        
        if isWrapping {
            print("   🔄 UV跨越边界，创建两段拼接可视化")
            
            // 创建第一段
            if let segment1 = segment1Azimuth {
                print("   📊 第一段: \(radToDeg(segment1.0))° → \(radToDeg(segment1.1))°")
                let segment1Entity = createSingleSegment(
                    azimuthRange: segment1,
                    elevationRange: elevationRange,
                    radius: radius,
                    name: "segment_1"
                )
                container.addChild(segment1Entity)
            }
            
            // 创建第二段
            if let segment2 = segment2Azimuth {
                print("   📊 第二段: \(radToDeg(segment2.0))° → \(radToDeg(segment2.1))°")
                let segment2Entity = createSingleSegment(
                    azimuthRange: segment2,
                    elevationRange: elevationRange,
                    radius: radius,
                    name: "segment_2"
                )
                container.addChild(segment2Entity)
            }
            
        } else {
            print("   ✅ UV未跨越边界，创建单一区域")
            print("   📊 方位角: \(radToDeg(azimuthRange.0))° → \(radToDeg(azimuthRange.1))°")
            
            let singleSegment = createSingleSegment(
                azimuthRange: azimuthRange,
                elevationRange: elevationRange,
                radius: radius,
                name: "single_segment"
            )
            container.addChild(singleSegment)
        }
        
        // 添加中心标记
        let centerAzimuth = (azimuthRange.0 + azimuthRange.1) / 2
        let centerElevation = (elevationRange.0 + elevationRange.1) / 2
        addCenterMarker(
            to: container,
            azimuth: centerAzimuth,
            elevation: centerElevation,
            radius: radius
        )
        
        print("\n✅【拟合球面可视化创建完成】")
        print("   青色半透明区域 = 拟合后的球面区域")
        print("   黄色边框 = 区域边界")
        print("   红色球 = 区域中心")
        print(String(repeating: "=", count: 80) + "\n")
        
        return container
    }
    
    // MARK: - 🔨 创建单个球面段
    private static func createSingleSegment(
        azimuthRange: (Float, Float),
        elevationRange: (Float, Float),
        radius: Float,
        name: String
    ) -> Entity {
        
        let segment = Entity()
        segment.name = name
        
        // 创建球面网格
        let uSteps = 20
        let vSteps = 20
        
        let azimuthStep = (azimuthRange.1 - azimuthRange.0) / Float(uSteps)
        let elevationStep = (elevationRange.1 - elevationRange.0) / Float(vSteps)
        
        var material = UnlitMaterial()
        material.color = .init(tint: Config.patchColor)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.3))
        
        // 创建网格面片
        for i in 0..<uSteps {
            for j in 0..<vSteps {
                let azimuth1 = azimuthRange.0 + Float(i) * azimuthStep
                let azimuth2 = azimuthRange.0 + Float(i + 1) * azimuthStep
                let elevation1 = elevationRange.0 + Float(j) * elevationStep
                let elevation2 = elevationRange.0 + Float(j + 1) * elevationStep
                
                let p1 = sphericalToCartesian(azimuth: azimuth1, elevation: elevation1, radius: radius)
                let p2 = sphericalToCartesian(azimuth: azimuth2, elevation: elevation1, radius: radius)
                let p3 = sphericalToCartesian(azimuth: azimuth2, elevation: elevation2, radius: radius)
                let p4 = sphericalToCartesian(azimuth: azimuth1, elevation: elevation2, radius: radius)
                
                let quad = createQuadMesh(p1: p1, p2: p2, p3: p3, p4: p4, material: material)
                segment.addChild(quad)
            }
        }
        
        // 添加边界线
        addBoundaryLines(
            to: segment,
            azimuthRange: azimuthRange,
            elevationRange: elevationRange,
            radius: radius
        )
        
        return segment
    }
    
    // MARK: - 🌐 球面坐标转笛卡尔坐标
    private static func sphericalToCartesian(
        azimuth: Float,
        elevation: Float,
        radius: Float
    ) -> SIMD3<Float> {
        let x = radius * cos(elevation) * sin(azimuth)
        let y = radius * sin(elevation)
        let z = -radius * cos(elevation) * cos(azimuth)
        return SIMD3<Float>(x, y, z)
    }
    
    // MARK: - 🔲 创建四边形网格
    private static func createQuadMesh(
        p1: SIMD3<Float>,
        p2: SIMD3<Float>,
        p3: SIMD3<Float>,
        p4: SIMD3<Float>,
        material: UnlitMaterial
    ) -> ModelEntity {
        let center = (p1 + p2 + p3 + p4) / 4.0
        let quadSize: Float = 0.5
        let quad = ModelEntity(
            mesh: .generatePlane(width: quadSize, depth: quadSize),
            materials: [material]
        )
        quad.position = center
        quad.look(at: SIMD3<Float>(0, center.y, 0), from: center, relativeTo: nil)
        return quad
    }
    
    // MARK: - 📏 添加边界线
    private static func addBoundaryLines(
        to container: Entity,
        azimuthRange: (Float, Float),
        elevationRange: (Float, Float),
        radius: Float
    ) {
        var lineMaterial = UnlitMaterial()
        lineMaterial.color = .init(tint: Config.gridLineColor)
        
        let lineRadius = radius + 0.1
        let lineWidth: Float = 0.05
        let steps = 50
        
        // 上边界
        for i in 0..<steps {
            let t = Float(i) / Float(steps)
            let azimuth = azimuthRange.0 + t * (azimuthRange.1 - azimuthRange.0)
            let p1 = sphericalToCartesian(azimuth: azimuth, elevation: elevationRange.0, radius: lineRadius)
            let sphere = ModelEntity(mesh: .generateSphere(radius: lineWidth), materials: [lineMaterial])
            sphere.position = p1
            container.addChild(sphere)
        }
        
        // 下边界
        for i in 0..<steps {
            let t = Float(i) / Float(steps)
            let azimuth = azimuthRange.0 + t * (azimuthRange.1 - azimuthRange.0)
            let p1 = sphericalToCartesian(azimuth: azimuth, elevation: elevationRange.1, radius: lineRadius)
            let sphere = ModelEntity(mesh: .generateSphere(radius: lineWidth), materials: [lineMaterial])
            sphere.position = p1
            container.addChild(sphere)
        }
        
        // 左边界
        for i in 0..<steps {
            let t = Float(i) / Float(steps)
            let elevation = elevationRange.0 + t * (elevationRange.1 - elevationRange.0)
            let p1 = sphericalToCartesian(azimuth: azimuthRange.0, elevation: elevation, radius: lineRadius)
            let sphere = ModelEntity(mesh: .generateSphere(radius: lineWidth), materials: [lineMaterial])
            sphere.position = p1
            container.addChild(sphere)
        }
        
        // 右边界
        for i in 0..<steps {
            let t = Float(i) / Float(steps)
            let elevation = elevationRange.0 + t * (elevationRange.1 - elevationRange.0)
            let p1 = sphericalToCartesian(azimuth: azimuthRange.1, elevation: elevation, radius: lineRadius)
            let sphere = ModelEntity(mesh: .generateSphere(radius: lineWidth), materials: [lineMaterial])
            sphere.position = p1
            container.addChild(sphere)
        }
    }
    
    // MARK: - 🏷️ 添加中心标记
    private static func addCenterMarker(
        to container: Entity,
        azimuth: Float,
        elevation: Float,
        radius: Float
    ) {
        let centerPos = sphericalToCartesian(azimuth: azimuth, elevation: elevation, radius: radius + 1.0)
        var centerMaterial = UnlitMaterial()
        centerMaterial.color = .init(tint: Config.centerMarkerColor)
        let centerMarker = ModelEntity(mesh: .generateSphere(radius: 0.2), materials: [centerMaterial])
        centerMarker.position = centerPos
        centerMarker.name = "center_marker"
        container.addChild(centerMarker)
        print("   🎯 中心标记位置: 方位角\(radToDeg(azimuth))°, 仰角\(radToDeg(elevation))°")
    }
    
    // MARK: - 🔢 弧度转角度
    private static func radToDeg(_ rad: Float) -> String {
        return String(format: "%.1f", rad * 180.0 / .pi)
    }
    
    // MARK: - 🎯 兼容旧版本的创建方法
    static func createFittedRegionVisualization(
        azimuthRange: (Float, Float),
        elevationRange: (Float, Float),
        radius: Float
    ) -> Entity {
        return createFittedRegionVisualizationFixed(
            azimuthRange: azimuthRange,
            elevationRange: elevationRange,
            radius: radius,
            isWrapping: false
        )
    }
    
    // MARK: - 🧪 生成模拟轨迹点(用于测试)
    /// 在指定的球面区域内生成模拟的手部轨迹点
    static func generateMockTrajectoryPoints(
        azimuthRange: (Float, Float),
        elevationRange: (Float, Float),
        radius: Float,
        numPoints: Int = 50
    ) -> [SIMD3<Float>] {
        
        print("\n🧪【生成模拟轨迹点】")
        print("   方位角: \(radToDeg(azimuthRange.0))° → \(radToDeg(azimuthRange.1))°")
        print("   仰角: \(radToDeg(elevationRange.0))° → \(radToDeg(elevationRange.1))°")
        print("   半径: \(radius)m")
        print("   点数: \(numPoints)")
        
        var points: [SIMD3<Float>] = []
        
        // 按矩形轨迹生成点(左上→右上→右下→左下→左上)
        let stepsPerSide = numPoints / 4
        
        // 顶边(左→右)
        for i in 0...stepsPerSide {
            let t = Float(i) / Float(stepsPerSide)
            let azimuth = azimuthRange.0 + t * (azimuthRange.1 - azimuthRange.0)
            let elevation = elevationRange.0
            let point = sphericalToCartesian(
                azimuth: azimuth,
                elevation: elevation,
                radius: radius
            )
            points.append(point)
        }
        
        // 右边(上→下)
        for i in 1...stepsPerSide {
            let t = Float(i) / Float(stepsPerSide)
            let azimuth = azimuthRange.1
            let elevation = elevationRange.0 + t * (elevationRange.1 - elevationRange.0)
            let point = sphericalToCartesian(
                azimuth: azimuth,
                elevation: elevation,
                radius: radius
            )
            points.append(point)
        }
        
        // 底边(右→左)
        for i in 1...stepsPerSide {
            let t = Float(i) / Float(stepsPerSide)
            let azimuth = azimuthRange.1 - t * (azimuthRange.1 - azimuthRange.0)
            let elevation = elevationRange.1
            let point = sphericalToCartesian(
                azimuth: azimuth,
                elevation: elevation,
                radius: radius
            )
            points.append(point)
        }
        
        // 左边(下→上)
        for i in 1..<stepsPerSide {
            let t = Float(i) / Float(stepsPerSide)
            let azimuth = azimuthRange.0
            let elevation = elevationRange.1 - t * (elevationRange.1 - elevationRange.0)
            let point = sphericalToCartesian(
                azimuth: azimuth,
                elevation: elevation,
                radius: radius
            )
            points.append(point)
        }
        
        print("✅【模拟轨迹生成完成】实际点数: \(points.count)")
        
        return points
    }
}
