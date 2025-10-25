//
//  DiagnosticTools_Enhanced.swift
//  ✅ 增强的诊断工具 - 支持期望结果验证
//

import Foundation
import RealityKit

// MARK: - 诊断扩展
extension PanoramaCoordinateConverter {
    
    /// 🔍 完整诊断报告（对比期望结果）
    func diagnoseWithExpectedResult(
        _ selection: SelectionRegion,
        expectedTopLeft: (x: Int, y: Int),
        expectedBottomRight: (x: Int, y: Int)
    ) {
        print("\n" + String(repeating: "=", count: 80))
        print("🔍【坐标转换诊断报告 - 带期望结果验证】")
        print(String(repeating: "=", count: 80))
        
        // 1. 显示期望结果
        print("\n📋【期望结果】")
        let expectedWidth = expectedBottomRight.x - expectedTopLeft.x
        let expectedHeight = expectedBottomRight.y - expectedTopLeft.y
        let expectedAspect = Float(expectedWidth) / Float(expectedHeight)
        
        print("   📍 左上角: (\(expectedTopLeft.x), \(expectedTopLeft.y))")
        print("   📍 右下角: (\(expectedBottomRight.x), \(expectedBottomRight.y))")
        print("   📏 尺寸: \(expectedWidth) × \(expectedHeight)")
        print("   📊 宽高比: \(String(format: "%.2f", expectedAspect))")
        
        // 2. 执行实际转换
        print("\n🔧【执行坐标转换】")
        let actualResult = convertSelectionToPanoramaRegion(selection)
        
        // 3. 对比结果
        print("\n📊【结果对比】")
        compareResults(
            expected: (expectedTopLeft, expectedBottomRight, expectedWidth, expectedHeight),
            actual: actualResult
        )
        
        // 4. 分析偏差原因
        print("\n🔍【偏差分析】")
        analyzeDifferences(selection, expected: (expectedTopLeft, expectedBottomRight))
        
        print("\n" + String(repeating: "=", count: 80))
        print("✅【诊断完成】")
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    // MARK: - 对比结果
    private func compareResults(
        expected: ((x: Int, y: Int), (x: Int, y: Int), Int, Int),
        actual: PanoramaRegion
    ) {
        let (expTL, expBR, expW, expH) = expected
        
        // 位置偏差
        let xOffsetTL = actual.topLeft.x - expTL.x
        let yOffsetTL = actual.topLeft.y - expTL.y
        let xOffsetBR = actual.bottomRight.x - expBR.x
        let yOffsetBR = actual.bottomRight.y - expBR.y
        
        print("   📍 左上角偏差: (\(xOffsetTL > 0 ? "+" : "")\(xOffsetTL), \(yOffsetTL > 0 ? "+" : "")\(yOffsetTL))")
        print("   📍 右下角偏差: (\(xOffsetBR > 0 ? "+" : "")\(xOffsetBR), \(yOffsetBR > 0 ? "+" : "")\(yOffsetBR))")
        
        // 尺寸偏差
        let widthDiff = actual.width - expW
        let heightDiff = actual.height - expH
        let widthPercent = Float(widthDiff) / Float(expW) * 100
        let heightPercent = Float(heightDiff) / Float(expH) * 100
        
        print("   📏 宽度偏差: \(widthDiff > 0 ? "+" : "")\(widthDiff) (\(String(format: "%+.1f", widthPercent))%)")
        print("   📏 高度偏差: \(heightDiff > 0 ? "+" : "")\(heightDiff) (\(String(format: "%+.1f", heightPercent))%)")
        
        // 宽高比对比
        let expAspect = Float(expW) / Float(expH)
        let actAspect = Float(actual.width) / Float(actual.height)
        let aspectDiff = actAspect - expAspect
        
        print("   📊 期望宽高比: \(String(format: "%.2f", expAspect))")
        print("   📊 实际宽高比: \(String(format: "%.2f", actAspect))")
        print("   📊 宽高比偏差: \(String(format: "%+.2f", aspectDiff))")
        
        // 判断精度
        let xAccuracy = Float(abs(xOffsetTL) + abs(xOffsetBR)) / Float(panoramaWidth)
        let yAccuracy = Float(abs(yOffsetTL) + abs(yOffsetBR)) / Float(panoramaHeight)
        
        if xAccuracy < 0.02 && yAccuracy < 0.02 && abs(widthPercent) < 10 && abs(heightPercent) < 10 {
            print("\n   ✅ 精度优秀（位置偏差<2%, 尺寸偏差<10%）")
        } else if xAccuracy < 0.05 && yAccuracy < 0.05 && abs(widthPercent) < 20 && abs(heightPercent) < 20 {
            print("\n   ⚠️ 精度一般（位置偏差<5%, 尺寸偏差<20%）")
        } else {
            print("\n   ❌ 精度较差（需要改进算法）")
        }
    }
    
    // MARK: - 分析偏差原因
    private func analyzeDifferences(
        _ selection: SelectionRegion,
        expected: ((x: Int, y: Int), (x: Int, y: Int))
    ) {
        let points = selection.trackedPoints
        
        // 分析Y轴变化
        var minY: Float = .infinity, maxY: Float = -.infinity
        for point in points {
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        let ySpan = maxY - minY
        
        if ySpan < 0.05 {
            print("   ℹ️ Y轴变化很小(\(String(format: "%.3f", ySpan))m) - 可能是水平圈选")
        } else if ySpan > 0.5 {
            print("   ℹ️ Y轴变化较大(\(String(format: "%.3f", ySpan))m) - 包含明显的高度")
        } else {
            print("   ℹ️ Y轴变化适中(\(String(format: "%.3f", ySpan))m)")
        }
        
        // 分析点的分布
        var sumX: Float = 0, sumY: Float = 0, sumZ: Float = 0
        for point in points {
            sumX += point.x; sumY += point.y; sumZ += point.z
        }
        let centroid = SIMD3<Float>(
            sumX / Float(points.count),
            sumY / Float(points.count),
            sumZ / Float(points.count)
        )
        
        let distToCamera = simd_distance(selection.cameraPosition, centroid)
        
        if distToCamera < 0.5 {
            print("   ⚠️ 相机距离过近(\(String(format: "%.2f", distToCamera))m) - 可能导致畸变")
        } else if distToCamera > 3.0 {
            print("   ⚠️ 相机距离过远(\(String(format: "%.2f", distToCamera))m) - 可能导致选区过小")
        } else {
            print("   ✅ 相机距离合适(\(String(format: "%.2f", distToCamera))m)")
        }
        
        // 分析手势稳定性
        var maxVariance: Float = 0
        for i in 0..<(points.count - 1) {
            let dist = simd_distance(points[i], points[i + 1])
            maxVariance = max(maxVariance, dist)
        }
        
        if maxVariance > 0.1 {
            print("   ⚠️ 手势波动较大(最大步长\(String(format: "%.3f", maxVariance))m) - 可能需要平滑处理")
        } else {
            print("   ✅ 手势相对稳定(最大步长\(String(format: "%.3f", maxVariance))m)")
        }
    }
    
    // MARK: - 🎯 快速验证（返回是否通过）
    func quickValidate(
        _ selection: SelectionRegion,
        expectedTopLeft: (x: Int, y: Int),
        expectedBottomRight: (x: Int, y: Int),
        tolerancePercent: Float = 10.0  // 容差百分比
    ) -> Bool {
        
        let result = convertSelectionToPanoramaRegion(selection)
        
        let expectedWidth = expectedBottomRight.x - expectedTopLeft.x
        let expectedHeight = expectedBottomRight.y - expectedTopLeft.y
        
        // 计算位置偏差
        let xOffsetTL = abs(result.topLeft.x - expectedTopLeft.x)
        let yOffsetTL = abs(result.topLeft.y - expectedTopLeft.y)
        
        let xTolerancePixels = Int(Float(panoramaWidth) * tolerancePercent / 100.0)
        let yTolerancePixels = Int(Float(panoramaHeight) * tolerancePercent / 100.0)
        
        let positionMatch = xOffsetTL < xTolerancePixels && yOffsetTL < yTolerancePixels
        
        // 计算尺寸偏差
        let widthDiffPercent = abs(Float(result.width - expectedWidth)) / Float(expectedWidth) * 100
        let heightDiffPercent = abs(Float(result.height - expectedHeight)) / Float(expectedHeight) * 100
        
        let sizeMatch = widthDiffPercent < tolerancePercent && heightDiffPercent < tolerancePercent
        
        let passed = positionMatch && sizeMatch
        
        print("\n🎯【快速验证结果】")
        print("   位置匹配: \(positionMatch ? "✅" : "❌") (偏差: \(xOffsetTL), \(yOffsetTL) 像素)")
        print("   尺寸匹配: \(sizeMatch ? "✅" : "❌") (偏差: \(String(format: "%.1f", widthDiffPercent))%, \(String(format: "%.1f", heightDiffPercent))%)")
        print("   总体结果: \(passed ? "✅ 通过" : "❌ 未通过")")
        
        return passed
    }
    
    // MARK: - 📊 生成详细的3D点云报告
    func generatePointCloudReport(_ selection: SelectionRegion) {
        print("\n📊【3D点云详细报告】")
        
        let points = selection.trackedPoints
        print("   📍 总点数: \(points.count)")
        
        // 统计各轴的范围
        var minX: Float = .infinity, maxX: Float = -.infinity
        var minY: Float = .infinity, maxY: Float = -.infinity
        var minZ: Float = .infinity, maxZ: Float = -.infinity
        
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
            minZ = min(minZ, point.z); maxZ = max(maxZ, point.z)
        }
        
        print("   📏 X: [\(String(format: "%.3f", minX)), \(String(format: "%.3f", maxX))] 跨度: \(String(format: "%.3f", maxX - minX))m")
        print("   📏 Y: [\(String(format: "%.3f", minY)), \(String(format: "%.3f", maxY))] 跨度: \(String(format: "%.3f", maxY - minY))m")
        print("   📏 Z: [\(String(format: "%.3f", minZ)), \(String(format: "%.3f", maxZ))] 跨度: \(String(format: "%.3f", maxZ - minZ))m")
        
        // 计算质心
        var sumX: Float = 0, sumY: Float = 0, sumZ: Float = 0
        for point in points {
            sumX += point.x; sumY += point.y; sumZ += point.z
        }
        let centroid = SIMD3<Float>(
            sumX / Float(points.count),
            sumY / Float(points.count),
            sumZ / Float(points.count)
        )
        print("   📍 质心: (\(String(format: "%.3f", centroid.x)), \(String(format: "%.3f", centroid.y)), \(String(format: "%.3f", centroid.z)))")
        
        // 相机信息
        print("   📷 相机位置: (\(String(format: "%.3f", selection.cameraPosition.x)), \(String(format: "%.3f", selection.cameraPosition.y)), \(String(format: "%.3f", selection.cameraPosition.z)))")
        print("   📏 相机到质心距离: \(String(format: "%.3f", simd_distance(selection.cameraPosition, centroid)))m")
    }
}

// MARK: - 使用示例
/*
使用方法：

1. 完整诊断（带期望结果）：
   converter.diagnoseWithExpectedResult(
       selection,
       expectedTopLeft: (2840, 1122),
       expectedBottomRight: (5631, 2494)
   )

2. 快速验证：
   let passed = converter.quickValidate(
       selection,
       expectedTopLeft: (2840, 1122),
       expectedBottomRight: (5631, 2494),
       tolerancePercent: 10.0  // 10%容差
   )

3. 点云报告：
   converter.generatePointCloudReport(selection)

4. 正常转换：
   let region = converter.convertSelectionToPanoramaRegion(selection)
*/
