//
//  PanoramaCoordinateConverter_Fixed.swift
//  ✅ 修复UV跨越边界的可视化问题 + 正确的交互逻辑
//

import Foundation
import RealityKit

// MARK: - 全景图区域结构
struct PanoramaRegion: Codable {
    let topLeft: PanoramaPixelCoordinate
    let topRight: PanoramaPixelCoordinate
    let bottomLeft: PanoramaPixelCoordinate
    let bottomRight: PanoramaPixelCoordinate
    let width: Int
    let height: Int
    
    var description: String {
        return """
        全景图区域:
        - 左上角: (\(topLeft.x), \(topLeft.y))
        - 右下角: (\(bottomRight.x), \(bottomRight.y))
        - 尺寸: \(width)x\(height)
        """
    }
}

struct PanoramaPixelCoordinate: Codable {
    let x: Int
    let y: Int
}

// MARK: - ✅ 基于原点的坐标转换器
class PanoramaCoordinateConverter {
    
    public let panoramaWidth: Int
    public let panoramaHeight: Int
    
    init(panoramaWidth: Int = 8704, panoramaHeight: Int = 4352) {
        self.panoramaWidth = panoramaWidth
        self.panoramaHeight = panoramaHeight
    }
    
    // MARK: - 🎯 核心转换方法（10m标准球面拟合 + Y坐标相对化）
    func convertSelectionToPanoramaRegion(
        _ selection: SelectionRegion
    ) -> PanoramaRegion {
        
        print("\n" + String(repeating: "=", count: 80))
        print("🎯【新方案：10m标准球面拟合 + Y坐标相对化】")
        print(String(repeating: "=", count: 80))
        
        guard selection.trackedPoints.count >= 3 else {
            print("❌ 点数不足")
            return fallbackRegion()
        }
        
        let points = selection.trackedPoints
        
        // ========== 步骤1：Y坐标相对化（关键修复！）==========
        print("\n📏【步骤1：Y坐标相对化】")
        
        var sumY: Float = 0
        for point in points {
            sumY += point.y
        }
        let averageY = sumY / Float(points.count)
        
        print("   原始点数: \(points.count)")
        print("   平均高度: \(String(format: "%.2f", averageY))m")
        print("   → 将此高度映射为水平线 (elevation=0°)")
        
        var adjustedPoints: [SIMD3<Float>] = []
        for point in points {
            let adjusted = SIMD3<Float>(
                point.x,
                point.y - averageY,
                point.z
            )
            adjustedPoints.append(adjusted)
        }
        
        // ========== 步骤2：拟合到10m标准球面 ==========
        print("\n🌐【步骤2：拟合到10m标准球面】")
        
        let targetRadius: Float = 10.0
        var fittedPoints: [SIMD3<Float>] = []
        
        for point in adjustedPoints {
            let distance = simd_length(point)
            if distance > 0.001 {
                let fitted = simd_normalize(point) * targetRadius
                fittedPoints.append(fitted)
            }
        }
        
        print("   拟合半径: \(targetRadius)m")
        print("   成功拟合: \(fittedPoints.count) 个点")
        
        // ========== 步骤3：计算球面坐标边界 ==========
        print("\n📐【步骤3：计算球面坐标边界】")
        
        var minAzimuth: Float = .infinity
        var maxAzimuth: Float = -.infinity
        var minElevation: Float = .infinity
        var maxElevation: Float = -.infinity
        
        var uvCoords: [(u: Float, v: Float)] = []
        
        let projectionCenter = SIMD3<Float>(0, 0, 0)
        
        for point in fittedPoints {
            let dir = simd_normalize(point - projectionCenter)
            
            let azimuth = atan2(dir.x, -dir.z)
            let elevation = asin(clamp(dir.y, min: -0.999, max: 0.999))
            
            minAzimuth = min(minAzimuth, azimuth)
            maxAzimuth = max(maxAzimuth, azimuth)
            minElevation = min(minElevation, elevation)
            maxElevation = max(maxElevation, elevation)
            
            var u = (azimuth / (2.0 * .pi)) + 0.5
            if u < 0.0 { u += 1.0 }
            if u >= 1.0 { u -= 1.0 }
            let v = 0.5 - (elevation / .pi)
            
            uvCoords.append((u: u, v: v))
        }
        
        print("   方位角范围: \(radToDeg(minAzimuth))° → \(radToDeg(maxAzimuth))°")
        print("   仰角范围: \(radToDeg(minElevation))° → \(radToDeg(maxElevation))°")
        print("   ✅ 成功投影 \(uvCoords.count) 个点")
        
        // ========== 步骤4：计算UV边界 ==========
        print("\n📊【步骤4：计算UV边界】")
        let uvBounds = calculateUVBounds(uvCoords)
        
        print("   📊 U范围: [\(String(format: "%.4f", uvBounds.minU)), \(String(format: "%.4f", uvBounds.maxU))]")
        print("   📊 V范围: [\(String(format: "%.4f", uvBounds.minV)), \(String(format: "%.4f", uvBounds.maxV))]")
        
        // ========== 步骤5：处理UV环绕 ==========
        let adjustedBounds = handleUVWrapping(uvBounds, uvCoords: uvCoords)
        
        // ========== 步骤6：转换为像素坐标 ==========
        print("\n🖼️【步骤6：转换为像素坐标】")
        let pixelRegion = uvToPixelRegion(adjustedBounds, margin: 0.02)
        
        print("   📊 像素范围: X[\(pixelRegion.topLeft.x), \(pixelRegion.bottomRight.x)]")
        print("   📊 像素范围: Y[\(pixelRegion.topLeft.y), \(pixelRegion.bottomRight.y)]")
        print("   📏 像素尺寸: \(pixelRegion.width) × \(pixelRegion.height)")
        
        // ========== 步骤7:准备可视化数据（修复版）==========
        print("\n🎨【步骤7:准备可视化数据（修复版）】")
        
        // 🔥 关键修复:检测UV是否跨越边界
        let uSpan = uvBounds.maxU - uvBounds.minU
        let isWrapping = uSpan > 0.8
        
        var visualizationData: [String: Any] = [
            "fittedPoints": fittedPoints,
            "radius": targetRadius,
            "averageY": averageY
        ]
        
        if isWrapping {
            print("   ⚠️ 检测到UV跨越0/1边界,将创建拼接的两段可视化")
            
            // 🔥 关键修复:将区域分成两段
            // 第一段:从最小方位角到π (正半轴)
            // 第二段:从-π到最大方位角 (负半轴)
            
            // 分析哪些点在正半轴,哪些在负半轴
            var positiveAzimuths: [Float] = []
            var negativeAzimuths: [Float] = []
            
            for point in fittedPoints {
                let dir = simd_normalize(point - projectionCenter)
                let azimuth = atan2(dir.x, -dir.z)
                
                if azimuth >= 0 {
                    positiveAzimuths.append(azimuth)
                } else {
                    negativeAzimuths.append(azimuth)
                }
            }
            
            let hasSegment1 = !positiveAzimuths.isEmpty
            let hasSegment2 = !negativeAzimuths.isEmpty
            
            var segment1Azimuth: (Float, Float) = (0, 0)
            var segment2Azimuth: (Float, Float) = (0, 0)
            
            if hasSegment1 {
                segment1Azimuth = (positiveAzimuths.min()!, positiveAzimuths.max()!)
                print("   📊 第一段（正半轴）: \(radToDeg(segment1Azimuth.0))° → \(radToDeg(segment1Azimuth.1))°")
            }
            
            if hasSegment2 {
                segment2Azimuth = (negativeAzimuths.min()!, negativeAzimuths.max()!)
                print("   📊 第二段（负半轴）: \(radToDeg(segment2Azimuth.0))° → \(radToDeg(segment2Azimuth.1))°")
            }
            
            visualizationData["isWrapping"] = true
            visualizationData["hasSegment1"] = hasSegment1
            visualizationData["hasSegment2"] = hasSegment2
            visualizationData["segment1Azimuth"] = [segment1Azimuth.0, segment1Azimuth.1]
            visualizationData["segment2Azimuth"] = [segment2Azimuth.0, segment2Azimuth.1]
            visualizationData["elevationRange"] = [minElevation, maxElevation]
            
        } else {
            print("   ✅ UV未跨越边界,使用单一区域")
            visualizationData["isWrapping"] = false
            visualizationData["azimuthRange"] = [minAzimuth, maxAzimuth]
            visualizationData["elevationRange"] = [minElevation, maxElevation]
        }
        
        // 🔥 重要:发送可视化通知(交给RegionSelectionManager处理)
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowFittedSphericalRegion"),
            object: nil,
            userInfo: visualizationData
        )
        
        print("   ✅【可视化通知已发送】")
        
        print("\n" + String(repeating: "=", count: 80))
        print("✅【转换完成 - 10m球面拟合】")
        print("   拟合半径: \(targetRadius)m")
        print("   方位角跨度: \(String(format: "%.1f", (maxAzimuth - minAzimuth) * 180.0 / .pi))°")
        print("   仰角跨度: \(String(format: "%.1f", (maxElevation - minElevation) * 180.0 / .pi))°")
        print(String(repeating: "=", count: 80) + "\n")
        
        return pixelRegion
    }
    
    // MARK: - 🔢 弧度转角度（辅助方法）
    private func radToDeg(_ rad: Float) -> String {
        return String(format: "%.1f", rad * 180.0 / .pi)
    }
    
    // MARK: - 📐 计算UV边界
    struct UVBounds {
        var minU: Float
        var maxU: Float
        var minV: Float
        var maxV: Float
    }
    
    private func calculateUVBounds(_ uvCoords: [(u: Float, v: Float)]) -> UVBounds {
        var minU: Float = 1.0, maxU: Float = 0.0
        var minV: Float = 1.0, maxV: Float = 0.0
        
        for coord in uvCoords {
            minU = min(minU, coord.u)
            maxU = max(maxU, coord.u)
            minV = min(minV, coord.v)
            maxV = max(maxV, coord.v)
        }
        
        return UVBounds(minU: minU, maxU: maxU, minV: minV, maxV: maxV)
    }
    
    // MARK: - 🔄 处理UV环绕
    private func handleUVWrapping(_ bounds: UVBounds, uvCoords: [(u: Float, v: Float)]) -> UVBounds {
        var adjustedBounds = bounds
        
        let uSpan = bounds.maxU - bounds.minU
        
        if uSpan > 0.8 {
            print("   ⚠️ 检测到UV跨越0/1边界 (uSpan = \(uSpan))")
            
            var newMinU: Float = 1.0
            var newMaxU: Float = 0.0
            
            for coord in uvCoords {
                var u = coord.u
                if u < 0.5 {
                    u += 1.0
                }
                newMinU = min(newMinU, u)
                newMaxU = max(newMaxU, u)
            }
            
            adjustedBounds.minU = newMinU
            adjustedBounds.maxU = newMaxU
            
            print("   🔄 修正后: U[\(String(format: "%.4f", adjustedBounds.minU)), \(String(format: "%.4f", adjustedBounds.maxU))]")
            
            if (adjustedBounds.maxU - adjustedBounds.minU) > 0.8 {
                print("   ⚠️ 修正后范围仍然很广，可能选区超过180度，保留原始值")
                return bounds
            }
        }
        
        return adjustedBounds
    }
    
    // MARK: - 🖼️ UV → 像素坐标
    private func uvToPixelRegion(_ bounds: UVBounds, margin: Float) -> PanoramaRegion {
        let uSpan = (bounds.maxU - bounds.minU)
        let vSpan = (bounds.maxV - bounds.minV)
        
        let marginU = uSpan * margin
        let marginV = vSpan * margin
        
        let expandedMinU = bounds.minU - marginU
        let expandedMaxU = bounds.maxU + marginU
        let expandedMinV = max(0.0, bounds.minV - marginV)
        let expandedMaxV = min(1.0, bounds.maxV + marginV)
        
        let minX = Int((expandedMinU.truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0) * Float(panoramaWidth))
        let maxX = Int((expandedMaxU.truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0) * Float(panoramaWidth))
        let minY = Int(expandedMinV * Float(panoramaHeight))
        let maxY = Int(expandedMaxV * Float(panoramaHeight))
        
        let finalMinX: Int
        let finalMaxX: Int
        let width: Int
        
        if minX > maxX {
            finalMinX = minX
            finalMaxX = maxX
            width = (panoramaWidth - minX) + maxX
        } else {
            finalMinX = minX
            finalMaxX = maxX
            width = maxX - minX
        }
        
        let finalMinY = max(0, minY)
        let finalMaxY = min(panoramaHeight - 1, maxY)
        let height = finalMaxY - finalMinY
        
        return PanoramaRegion(
            topLeft: PanoramaPixelCoordinate(x: finalMinX, y: finalMinY),
            topRight: PanoramaPixelCoordinate(x: finalMaxX, y: finalMinY),
            bottomLeft: PanoramaPixelCoordinate(x: finalMinX, y: finalMaxY),
            bottomRight: PanoramaPixelCoordinate(x: finalMaxX, y: finalMaxY),
            width: width,
            height: height
        )
    }
    
    // MARK: - 辅助函数
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.min(Swift.max(value, min), max)
    }
    
    private func fallbackRegion() -> PanoramaRegion {
        let centerX = panoramaWidth / 2
        let centerY = panoramaHeight / 2
        return PanoramaRegion(
            topLeft: PanoramaPixelCoordinate(x: centerX - 200, y: centerY - 200),
            topRight: PanoramaPixelCoordinate(x: centerX + 200, y: centerY - 200),
            bottomLeft: PanoramaPixelCoordinate(x: centerX - 200, y: centerY + 200),
            bottomRight: PanoramaPixelCoordinate(x: centerX + 200, y: centerY + 200),
            width: 400,
            height: 400
        )
    }
}
