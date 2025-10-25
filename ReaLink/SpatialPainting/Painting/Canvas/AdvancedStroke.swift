/*
高级笔触类 - 支持多种画笔类型和模式（修复云端加载问题）
*/

import SwiftUI
import RealityKit

/// 高级笔触结构体，支持多种画笔类型
struct AdvancedStroke {
    /// 代表笔触的实体对象
    var entity = Entity()
    
    /// 3D空间中的点集合
    var points: [SIMD3<Float>] = []
    
    /// 画笔配置
    let brushConfig: BrushConfig
    
    var userId: Int64? // 新增：用户ID属性
    
    /// 用于断续模式的累积距离
    private var accumulatedDistance: Float = 0
    
    /// 是否应该绘制当前段（用于断续模式）
    private var shouldDraw: Bool = true
    
    /// 初始化
    init(brushConfig: BrushConfig,userId: Int64? = nil) {
        self.brushConfig = brushConfig
        // 确保实体正确初始化
        self.entity = Entity()
        self.userId = userId
    }
    
    /// 根据画笔配置更新网格
    mutating func updateMesh() {
        guard let center = points.first else {
            print("⚠️ 没有点数据，无法生成网格")
            return
        }
        
        // 🔧 修复：检查点数是否足够生成网格
        guard points.count >= 2 else {
            print("⚠️ 点数不足，无法生成网格 (需要至少2个点，当前有\(points.count)个)")
            return
        }
        
        // 🔧 修复：验证点数据的有效性
        let validPointsCount = points.filter { point in
            !point.x.isNaN && !point.y.isNaN && !point.z.isNaN &&
            point.x.isFinite && point.y.isFinite && point.z.isFinite
        }.count
        
        guard validPointsCount >= 2 else {
            print("⚠️ 有效点数不足，无法生成网格 (有效点数: \(validPointsCount))")
            return
        }
        
        let (positions, normals, triangles) = generateMeshData()
        
        // 🔧 修复：验证生成的网格数据有效性
        guard !positions.isEmpty && !triangles.isEmpty else {
            print("⚠️ 生成的网格数据为空")
            return
        }
        
        // 🔧 修复：验证三角形索引有效性
        let maxIndex = UInt32(positions.count - 1)
        for index in triangles {
            if index > maxIndex {
                print("❌ 三角形索引越界: \(index) > \(maxIndex)")
                return
            }
        }
        
        // 🔧 修复：安全地创建网格内容
        do {
            var contents = MeshResource.Contents()
            contents.instances = [MeshResource.Instance(id: "main", model: "model")]
            
            var part = MeshResource.Part(id: "part", materialIndex: 0)
            part.positions = MeshBuffer(positions)
            part.triangleIndices = MeshBuffer(triangles)
            part.normals = MeshBuffer(normals)
            
            contents.models = [MeshResource.Model(id: "model", parts: [part])]
            
            // 检查实体是否已有模型组件
            if let existingMesh = entity.model?.mesh {
                try existingMesh.replace(with: contents)
                print("✅ 成功更新现有网格")
            } else {
                // 创建新的网格
                guard let mesh = try? MeshResource.generate(from: contents) else {
                    print("❌ 生成网格失败")
                    return
                }
                
                let material = brushConfig.createMaterial()
                entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
                entity.setTransformMatrix(.identity, relativeTo: nil)
                entity.setPosition(center, relativeTo: nil)
                print("✅ 成功创建新网格")
            }
        } catch {
            print("❌ 更新网格时出错: \(error.localizedDescription)")
        }
    }
    
    /// 生成网格数据
    private func generateMeshData() -> ([SIMD3<Float>], [SIMD3<Float>], [UInt32]) {
        switch brushConfig.type {
        case .cylindrical:
            return generateCylindricalMesh()
        case .cubic:
            return generateCubicMesh()
        case .prismatic:
            return generatePrismaticMesh()
        }
    }
    
    /// 生成圆柱体网格（修复版本）
    private func generateCylindricalMesh() -> ([SIMD3<Float>], [SIMD3<Float>], [UInt32]) {
        let pointsPerRing = 8
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [UInt32] = []
        
        // 🔧 修复：过滤无效点
        let validPoints = points.filter { point in
            !point.x.isNaN && !point.y.isNaN && !point.z.isNaN &&
            point.x.isFinite && point.y.isFinite && point.z.isFinite
        }
        
        guard validPoints.count >= 2 else {
            print("⚠️ 圆柱体：有效点数不足")
            return ([], [], [])
        }
        
        print("🔧 圆柱体生成开始: \(validPoints.count) 个有效点")
        
        for pointIdx in 0..<validPoints.count {
            let (radius, direction) = calculateRadiusAndDirection(at: pointIdx, validPoints: validPoints)
            let (xAxis, yAxis) = calculateAxes(direction: direction)
            
            for point in 0..<pointsPerRing {
                let (position, normal) = calculateCylindricalPositionAndNormal(
                    pointI: pointIdx,
                    point: point,
                    radius: radius,
                    xAxis: xAxis,
                    yAxis: yAxis,
                    pointsPerRing: pointsPerRing,
                    validPoints: validPoints
                )
                
                positions.append(position)
                normals.append(normal)
                
                // 🔧 修复：安全地添加三角形，避免越界
                if pointIdx + 1 < validPoints.count {
                    appendTrianglesSafely(
                        pointIdx: pointIdx,
                        point: point,
                        triangles: &triangles,
                        pointsPerRing: pointsPerRing,
                        totalPoints: validPoints.count
                    )
                }
            }
        }
        
        print("🔧 圆柱体网格完成: \(positions.count) 个顶点, \(triangles.count) 个索引")
        return (positions, normals, triangles)
    }
    
    /// 生成立方体网格（修复版本）
    private func generateCubicMesh() -> ([SIMD3<Float>], [SIMD3<Float>], [UInt32]) {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [UInt32] = []
        
        let filteredPoints = filterPointsForMode()
        
        guard !filteredPoints.isEmpty else {
            print("⚠️ 立方体：过滤后的点为空")
            return ([], [], [])
        }
        
        guard let firstPoint = points.first else {
            print("⚠️ 立方体：原始点集为空")
            return ([], [], [])
        }
        
        for (index, point) in filteredPoints.enumerated() {
            let cubeSize = max(brushConfig.size, 0.001) // 🔧 确保最小尺寸
            let (cubePositions, cubeNormals, cubeTriangles) = generateCubeAt(
                position: point - firstPoint,
                size: cubeSize,
                indexOffset: UInt32(positions.count)
            )
            
            positions.append(contentsOf: cubePositions)
            normals.append(contentsOf: cubeNormals)
            triangles.append(contentsOf: cubeTriangles)
        }
        
        print("🔧 立方体网格: \(positions.count) 个顶点, \(triangles.count) 个索引")
        return (positions, normals, triangles)
    }
    
    /// 生成四棱柱网格（修复版本）
    private func generatePrismaticMesh() -> ([SIMD3<Float>], [SIMD3<Float>], [UInt32]) {
        let pointsPerRing = 4  // 四棱柱有4个角
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [UInt32] = []
        
        // 🔧 修复：过滤无效点
        let validPoints = points.filter { point in
            !point.x.isNaN && !point.y.isNaN && !point.z.isNaN &&
            point.x.isFinite && point.y.isFinite && point.z.isFinite
        }
        
        guard validPoints.count >= 2 else {
            print("⚠️ 四棱柱：有效点数不足")
            return ([], [], [])
        }
        
        for pointIdx in 0..<validPoints.count {
            let (radius, direction) = calculateRadiusAndDirection(at: pointIdx, validPoints: validPoints)
            let (xAxis, yAxis) = calculateAxes(direction: direction)
            
            for point in 0..<pointsPerRing {
                let (position, normal) = calculatePrismaticPositionAndNormal(
                    pointI: pointIdx,
                    point: point,
                    radius: radius,
                    xAxis: xAxis,
                    yAxis: yAxis,
                    pointsPerRing: pointsPerRing,
                    validPoints: validPoints
                )
                
                positions.append(position)
                normals.append(normal)
                
                // 🔧 修复：安全地添加三角形
                if pointIdx + 1 < validPoints.count {
                    appendTrianglesSafely(
                        pointIdx: pointIdx,
                        point: point,
                        triangles: &triangles,
                        pointsPerRing: pointsPerRing,
                        totalPoints: validPoints.count
                    )
                }
            }
        }
        
        print("🔧 四棱柱网格: \(positions.count) 个顶点, \(triangles.count) 个索引")
        return (positions, normals, triangles)
    }
    
    /// 根据模式过滤点
    private func filterPointsForMode() -> [SIMD3<Float>] {
        guard brushConfig.mode == .dotted else {
            return points
        }
        
        var filteredPoints: [SIMD3<Float>] = []
        var accumulatedDistance: Float = 0
        var shouldInclude = true
        
        for i in 0..<points.count {
            if i == 0 {
                filteredPoints.append(points[i])
            } else {
                let distance = length(points[i] - points[i-1])
                accumulatedDistance += distance
                
                if accumulatedDistance >= brushConfig.dottedSpacing {
                    shouldInclude.toggle()
                    accumulatedDistance = 0
                }
                
                if shouldInclude {
                    filteredPoints.append(points[i])
                }
            }
        }
        
        return filteredPoints
    }
    
    /// 在指定位置生成立方体
    private func generateCubeAt(position: SIMD3<Float>, size: Float, indexOffset: UInt32) -> ([SIMD3<Float>], [SIMD3<Float>], [UInt32]) {
        let halfSize = size * 0.5
        
        // 立方体8个顶点
        let vertices: [SIMD3<Float>] = [
            position + SIMD3<Float>(-halfSize, -halfSize, -halfSize), // 0
            position + SIMD3<Float>( halfSize, -halfSize, -halfSize), // 1
            position + SIMD3<Float>( halfSize,  halfSize, -halfSize), // 2
            position + SIMD3<Float>(-halfSize,  halfSize, -halfSize), // 3
            position + SIMD3<Float>(-halfSize, -halfSize,  halfSize), // 4
            position + SIMD3<Float>( halfSize, -halfSize,  halfSize), // 5
            position + SIMD3<Float>( halfSize,  halfSize,  halfSize), // 6
            position + SIMD3<Float>(-halfSize,  halfSize,  halfSize)  // 7
        ]
        
        // 立方体6个面的法向量
        let faceNormals: [SIMD3<Float>] = [
            SIMD3<Float>( 0,  0, -1), // 前面
            SIMD3<Float>( 0,  0,  1), // 后面
            SIMD3<Float>(-1,  0,  0), // 左面
            SIMD3<Float>( 1,  0,  0), // 右面
            SIMD3<Float>( 0, -1,  0), // 下面
            SIMD3<Float>( 0,  1,  0)  // 上面
        ]
        
        // 每个面的4个顶点
        let faceVertexIndices: [[Int]] = [
            [0, 1, 2, 3], // 前面
            [5, 4, 7, 6], // 后面
            [4, 0, 3, 7], // 左面
            [1, 5, 6, 2], // 右面
            [4, 5, 1, 0], // 下面
            [3, 2, 6, 7]  // 上面
        ]
        
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [UInt32] = []
        
        // 为每个面生成顶点和三角形
        for (faceIndex, vertexIndices) in faceVertexIndices.enumerated() {
            let normal = faceNormals[faceIndex]
            let baseIndex = UInt32(positions.count) + indexOffset
            
            // 添加4个顶点
            for vertexIndex in vertexIndices {
                positions.append(vertices[vertexIndex])
                normals.append(normal)
            }
            
            // 添加2个三角形组成面
            triangles.append(contentsOf: [
                baseIndex + 0, baseIndex + 1, baseIndex + 2,
                baseIndex + 0, baseIndex + 2, baseIndex + 3
            ])
        }
        
        return (positions, normals, triangles)
    }
    
    // MARK: - 辅助函数（修复版本）
    
    private func calculateRadiusAndDirection(at index: Int, validPoints: [SIMD3<Float>] = []) -> (Float, SIMD3<Float>) {
        let pointsToUse = validPoints.isEmpty ? points : validPoints
        
        if index == 0 || (index + 1 == pointsToUse.count) {
            return (max(brushConfig.size * 0.5, 0.001), SIMD3<Float>(1, 0, 0))
        } else {
            let diff = pointsToUse[index] - pointsToUse[index - 1]
            let diffLength = length(diff)
            
            // 🔧 修复：避免除零和无效值
            if diffLength < 0.0001 {
                return (max(brushConfig.size * 0.5, 0.001), SIMD3<Float>(1, 0, 0))
            }
            
            let radius = brushConfig.size * pow(clamp(brushConfig.size / diffLength, min: 0.1, max: 1.0), 0.3)
            let safeRadius = max(radius, 0.001) // 确保最小半径
            
            return (safeRadius, normalize(diff))
        }
    }
    
    private func calculateAxes(direction: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        // 🔧 修复：处理零向量和无效向量
        let safeDirection = length(direction) < 0.0001 ? SIMD3<Float>(1, 0, 0) : normalize(direction)
        
        var xAxis = cross(safeDirection, SIMD3<Float>(0, 1, 0))
        if length(xAxis) < 0.0001 {
            // 如果方向向量与Y轴平行，使用X轴
            xAxis = cross(safeDirection, SIMD3<Float>(1, 0, 0))
        }
        xAxis = normalize(xAxis)
        
        let yAxis = normalize(cross(safeDirection, xAxis))
        return (xAxis, yAxis)
    }
    
    private func calculateCylindricalPositionAndNormal(
        pointI: Int,
        point: Int,
        radius: Float,
        xAxis: SIMD3<Float>,
        yAxis: SIMD3<Float>,
        pointsPerRing: Int,
        validPoints: [SIMD3<Float>] = []
    ) -> (SIMD3<Float>, SIMD3<Float>) {
        let pointsToUse = validPoints.isEmpty ? points : validPoints
        
        let angle = 2 * .pi * Float(point) / Float(pointsPerRing)
        let normal = cos(angle) * xAxis + sin(angle) * yAxis
        
        guard let firstPoint = pointsToUse.first,
              pointI < pointsToUse.count else {
            return (SIMD3<Float>(), normal)
        }
        
        let position = (pointsToUse[pointI] - firstPoint) + radius * normal
        return (position, normal)
    }
    
    private func calculatePrismaticPositionAndNormal(
        pointI: Int,
        point: Int,
        radius: Float,
        xAxis: SIMD3<Float>,
        yAxis: SIMD3<Float>,
        pointsPerRing: Int,
        validPoints: [SIMD3<Float>] = []
    ) -> (SIMD3<Float>, SIMD3<Float>) {
        let pointsToUse = validPoints.isEmpty ? points : validPoints
        
        // 四棱柱的4个角 - 创建方形截面
        let corners: [SIMD2<Float>] = [
            SIMD2<Float>(-1, -1), // 左下
            SIMD2<Float>( 1, -1), // 右下
            SIMD2<Float>( 1,  1), // 右上
            SIMD2<Float>(-1,  1)  // 左上
        ]
        
        // 每个面的纯正交法向量（真正的直角边缘）
        let faceNormals: [SIMD3<Float>] = [
            -yAxis, // 下面 (垂直向下)
             xAxis, // 右面 (垂直向右)
             yAxis, // 上面 (垂直向上)
            -xAxis  // 左面 (垂直向左)
        ]
        
        let corner = corners[point]
        let localPos = corner.x * xAxis + corner.y * yAxis
        let normal = faceNormals[point] // 使用纯正交面法向量
        
        guard let firstPoint = pointsToUse.first,
              pointI < pointsToUse.count else {
            return (SIMD3<Float>(), normal)
        }
        
        let position = (pointsToUse[pointI] - firstPoint) + radius * localPos
        
        return (position, normal)
    }
    
    // 🔧 修复：安全的三角形添加方法（使用正确的三角形顶点顺序）
    private func appendTrianglesSafely(pointIdx: Int, point: Int, triangles: inout [UInt32], pointsPerRing: Int, totalPoints: Int) {
        // 确保索引在有效范围内
        guard pointIdx + 1 < totalPoints else {
            return
        }
        
        let currentRingStart = UInt32(pointsPerRing * pointIdx)
        let nextRingStart = UInt32(pointsPerRing * (pointIdx + 1))
        
        // 🔧 修复：使用与原始Stroke.swift相同的索引计算方式
        let quadIndices: [UInt32] = [
            currentRingStart + UInt32((point + 0) % pointsPerRing), // 当前环当前点
            nextRingStart + UInt32((point + 0) % pointsPerRing),    // 下一环当前点
            currentRingStart + UInt32((point + 1) % pointsPerRing), // 当前环下一点
            nextRingStart + UInt32((point + 1) % pointsPerRing)     // 下一环下一点
        ]
        
        // 验证所有索引都有效
        let expectedVertexCount = UInt32(totalPoints * pointsPerRing)
        
        for index in quadIndices {
            if index >= expectedVertexCount {
                print("⚠️ 跳过无效三角形索引: \(index) >= \(expectedVertexCount)")
                return
            }
        }
        
        // 🔧 修复：使用正确的三角形顶点顺序（与原始Stroke.swift保持一致）
        triangles.append(contentsOf: [quadIndices[3], quadIndices[0], quadIndices[2]])
        triangles.append(contentsOf: [quadIndices[3], quadIndices[1], quadIndices[0]])
    }
}
