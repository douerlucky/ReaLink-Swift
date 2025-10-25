//
//  DebugCoordinateMapping.swift
//  🔧 完整的坐标映射调试流程
//
//  这个文件展示如何一步步调试和修正投影算法
//

import RealityKit
import SwiftUI

// MARK: - 调试协调器
class CoordinateMappingDebugger {
    
    private weak var rootEntity: Entity?
    private var debugPatch: Entity?
    
    init(rootEntity: Entity) {
        self.rootEntity = rootEntity
    }
    
    // MARK: - 🎯 步骤1：显示目标区域
    func step1_ShowTargetRegion() {
        print("\n" + String(repeating: "=", count: 80))
        print("📍【步骤1：显示目标区域】")
        print(String(repeating: "=", count: 80))
        
        debugPatch = DebugSphericalPatch.createUserExpectedRegion()
        rootEntity?.addChild(debugPatch!)
        
        print("\n✅ 你现在应该看到：")
        print("   🔵 半透明蓝色球面片段 → 这是全景图 (2840,1122)-(5631,2494) 对应的3D位置")
        print("   🔴 红色球 → 区域中心")
        print("   ⚪ 白色边框 → 区域边界")
        print("\n🎯 请用手慢慢画这个蓝色区域（从左上到右下）")
        print("   然后我们会比较算法输出的坐标\n")
    }
    
    // MARK: - 🔍 步骤2：对比算法输出
    func step2_CompareResults(
        actualRegion: PanoramaRegion,
        expectedTopLeft: (x: Int, y: Int) = (2840, 1122),
        expectedBottomRight: (x: Int, y: Int) = (5631, 2494)
    ) {
        print("\n" + String(repeating: "=", count: 80))
        print("📊【步骤2：对比算法输出】")
        print(String(repeating: "=", count: 80))
        
        print("\n期望的坐标：")
        print("   左上：(\(expectedTopLeft.x), \(expectedTopLeft.y))")
        print("   右下：(\(expectedBottomRight.x), \(expectedBottomRight.y))")
        print("   尺寸：\(expectedBottomRight.x - expectedTopLeft.x) × \(expectedBottomRight.y - expectedTopLeft.y)")
        
        print("\n实际输出的坐标：")
        print("   左上：(\(actualRegion.topLeft.x), \(actualRegion.topLeft.y))")
        print("   右下：(\(actualRegion.bottomRight.x), \(actualRegion.bottomRight.y))")
        print("   尺寸：\(actualRegion.width) × \(actualRegion.height)")
        
        print("\n偏差分析：")
        let xOffsetTL = actualRegion.topLeft.x - expectedTopLeft.x
        let yOffsetTL = actualRegion.topLeft.y - expectedTopLeft.y
        let xOffsetBR = actualRegion.bottomRight.x - expectedBottomRight.x
        let yOffsetBR = actualRegion.bottomRight.y - expectedBottomRight.y
        
        print("   左上角偏差：(\(xOffsetTL > 0 ? "+" : "")\(xOffsetTL), \(yOffsetTL > 0 ? "+" : "")\(yOffsetTL)) 像素")
        print("   右下角偏差：(\(xOffsetBR > 0 ? "+" : "")\(xOffsetBR), \(yOffsetBR > 0 ? "+" : "")\(yOffsetBR)) 像素")
        
        let xOffsetPercent = Float(abs(xOffsetTL + xOffsetBR) / 2) / 8704.0 * 100
        let yOffsetPercent = Float(abs(yOffsetTL + yOffsetBR) / 2) / 4352.0 * 100
        
        print("   平均偏差：X方向 \(String(format: "%.1f", xOffsetPercent))%, Y方向 \(String(format: "%.1f", yOffsetPercent))%")
        
        // 判断问题类型
        print("\n🔍 问题诊断：")
        if abs(xOffsetTL) > 1000 {
            print("   ❌ X坐标严重偏移 → 方位角(azimuth)计算有问题")
            print("      可能原因：")
            print("      1. 最佳相机位置计算错误（PCA法向量反向）")
            print("      2. atan2的参数顺序或符号错误")
            print("      3. 坐标系定义不一致")
        }
        
        if abs(yOffsetTL) > 200 {
            print("   ⚠️ Y坐标偏移较大 → 仰角(elevation)计算有问题")
            print("      可能原因：")
            print("      1. 相机高度计算不准")
            print("      2. asin的输入范围或符号问题")
        }
        
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    // MARK: - 🔧 步骤3：提供修正建议
    func step3_ProvideFixSuggestions(selectionRegion: SelectionRegion) {
        print("\n" + String(repeating: "=", count: 80))
        print("🔧【步骤3：修正建议】")
        print(String(repeating: "=", count: 80))
        
        // 分析3D点云
        let points = selectionRegion.trackedPoints
        var minX: Float = .infinity, maxX: Float = -.infinity
        var minZ: Float = .infinity, maxZ: Float = -.infinity
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minZ = min(minZ, point.z)
            maxZ = max(maxZ, point.z)
        }
        
        let centerX = (minX + maxX) / 2
        let centerZ = (minZ + maxZ) / 2
        
        print("\n📊 3D点云分析：")
        print("   X范围：[\(String(format: "%.2f", minX)), \(String(format: "%.2f", maxX))]")
        print("   Z范围：[\(String(format: "%.2f", minZ)), \(String(format: "%.2f", maxZ))]")
        print("   中心：(\(String(format: "%.2f", centerX)), _, \(String(format: "%.2f", centerZ)))")
        
        // 判断区域位置
        var regionDescription = ""
        if centerX > 0.3 && centerZ < -0.3 {
            regionDescription = "右前方"
        } else if centerX < -0.3 && centerZ < -0.3 {
            regionDescription = "左前方"
        } else if centerX > 0.3 && centerZ > 0.3 {
            regionDescription = "右后方"
        } else if centerX < -0.3 && centerZ > 0.3 {
            regionDescription = "左后方"
        } else if abs(centerX) <= 0.3 && centerZ < 0 {
            regionDescription = "正前方"
        } else {
            regionDescription = "未知位置"
        }
        
        print("   相对位置：\(regionDescription)")
        
        // 计算当前使用的相机位置
        let cameraPos = selectionRegion.cameraPosition
        print("\n📷 当前算法使用的相机位置：")
        print("   (\(String(format: "%.2f", cameraPos.x)), \(String(format: "%.2f", cameraPos.y)), \(String(format: "%.2f", cameraPos.z)))")
        
        // 计算从相机看向区域中心的方向
        let dirToRegion = SIMD3<Float>(centerX, 0, centerZ) - cameraPos
        let azimuthToRegion = atan2(dirToRegion.x, -dirToRegion.z)
        let azimuthDegrees = azimuthToRegion * 180.0 / .pi
        
        print("   从相机到区域中心的方位角：\(String(format: "%.1f", azimuthDegrees))°")
        
        // 提供修正建议
        print("\n🔧 修正建议：")
        
        if regionDescription == "右前方" {
            print("   ✅ 区域在右前方，期望方位角应该在 30° - 60° 左右")
            print("   ✅ 期望UV范围：U ≈ 0.326 - 0.647 (中间偏左)")
            
            if abs(azimuthDegrees - 45) > 30 {
                print("   ❌ 当前算法计算的方位角(\(String(format: "%.1f", azimuthDegrees))°)明显偏离！")
                print("      → 需要修正：最佳相机位置的计算逻辑")
            }
        }
        
        print("\n💡 建议的修正方向：")
        print("   1. 检查PCA计算的法向量方向是否正确")
        print("   2. 确认'朝向用户'的判断逻辑")
        print("   3. 验证 atan2(dir.x, -dir.z) 的坐标系一致性")
        print("   4. 考虑直接使用用户绘制时的实际相机位置，而不是计算'最佳位置'")
        
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    // MARK: - 🗑️ 清理调试对象
    func cleanup() {
        debugPatch?.removeFromParent()
        debugPatch = nil
        print("✅【调试对象已清理】")
    }
}

// MARK: - 在VisionAIView中集成调试流程

extension AIAssistantWindow {
    
    /// 🎯 开始坐标映射调试
    func startCoordinateMappingDebug(rootEntity: Entity) {
        print("\n🚀【启动坐标映射调试流程】")
        
        let debugger = CoordinateMappingDebugger(rootEntity: rootEntity)
        
        // 步骤1：显示目标区域
        debugger.step1_ShowTargetRegion()
        
        // 监听圈选完成事件
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RegionSelectionCompleted"),
            object: nil,
            queue: .main
        ) { [ ] notification in
            guard self != nil else { return }
            guard let region = notification.userInfo?["region"] as? SelectionRegion else { return }
            
            // 执行坐标转换
            let converter = PanoramaCoordinateConverter(
                panoramaWidth: 8704,
                panoramaHeight: 4352
            )
            let actualRegion = converter.convertSelectionToPanoramaRegion(region)
            
            // 步骤2：对比结果
            debugger.step2_CompareResults(actualRegion: actualRegion)
            
            // 步骤3：提供修正建议
            debugger.step3_ProvideFixSuggestions(selectionRegion: region)
        }
        
        print("✅【调试流程已启动】请用手画蓝色区域")
    }
}

// MARK: - 使用示例
/*
 📖 完整调试流程：
 
 1. 在ImmersiveView加载完成后：
    aiWindow.startCoordinateMappingDebug(rootEntity: panoramaView.rootEntity)
 
 2. 你会看到半透明蓝色的目标区域
 
 3. 用手慢慢画这个蓝色区域（从左上到右下）
 
 4. 圈选完成后，控制台会输出：
    - 期望坐标 vs 实际坐标
    - 偏差分析
    - 问题诊断
    - 修正建议
 
 5. 根据诊断结果修正算法：
    - 如果X坐标偏差大 → 修正方位角计算
    - 如果Y坐标偏差大 → 修正仰角计算
    - 如果整体位置错误 → 修正最佳相机位置的计算
 
 🎯 核心思路：
    通过可视化"正确答案"，让你能直观地看到算法哪里出了问题！
 */
