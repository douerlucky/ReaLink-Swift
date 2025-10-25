/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A class that represents the stroke mesh that the drag gesture creates.
*/

import SwiftUI      // 导入SwiftUI框架，用于UI界面
import RealityKit   // 导入RealityKit框架，用于3D图形和AR

/// 表示笔触的结构体
struct Stroke {
    /// 代表笔触的实体对象（3D场景中的对象）
    var entity = Entity()

    /// 在3D空间中代表笔触的点集合
    var points: [SIMD3<Float>] = []

    /// 笔触的最大半径（1E-2 = 0.01）
    let maxRadius: Float = 1E-2

    /// 网格每个环上的点数（8个点形成圆形截面）
    let pointsPerRing = 8

    /// 根据笔触的点更新网格，如果已存在则更新，否则创建新的网格
    func updateMesh() {
        /// 获取笔触开始的起始点
        guard let center = points.first else { return } // 如果没有点就返回

        /// 生成网格数据：位置、法向量和三角形索引
        let (positions, normals, triangles) = generateMeshData()

        /// 创建MeshResource.Contents实例（网格内容容器）
        var contents = MeshResource.Contents()

        // 创建并分配一个实例到contents
        // 实例定义了网格的一个副本，id为"main"，使用模型"model"
        contents.instances = [MeshResource.Instance(id: "main", model: "model")]

        // 创建网格的一部分，设置顶点位置、三角形索引和法向量
        var part = MeshResource.Part(id: "part", materialIndex: 0)
        part.positions = MeshBuffer(positions)        // 顶点位置缓冲区
        part.triangleIndices = MeshBuffer(triangles)  // 三角形索引缓冲区
        part.normals = MeshBuffer(normals)           // 法向量缓冲区

        // 创建并分配由part组成的模型
        contents.models = [MeshResource.Model(id: "model", parts: [part])]

        // 如果实体上已经有网格组件，则替换现有网格
        if let mesh = entity.model?.mesh {
            do {
                try mesh.replace(with: contents) // 尝试替换网格
            } catch {
                print("Error replacing mesh: \(error.localizedDescription)")
            }
        } else {
            /// 用contents生成新的网格
            guard let mesh = try? MeshResource.generate(from: contents) else {
                print("Error generating mesh")
                return
            }

            // 设置模型组件为新网格，并分配简单材质
            entity.components.set(ModelComponent(
                mesh: mesh,
                materials: [SimpleMaterial(color: .white, roughness: 1.0, isMetallic: false)]
                // 白色、粗糙度1.0（完全粗糙）、非金属材质
            ))

            // 设置实体的变换矩阵和位置
            entity.setTransformMatrix(.identity, relativeTo: nil) // 设置为单位矩阵
            entity.setPosition(center, relativeTo: nil)           // 设置位置为起始点
        }
    }

    // MARK: 辅助函数

    /// 用当前点生成网格数据
    private func generateMeshData() -> ([SIMD3<Float>], [SIMD3<Float>], [UInt32]) {
        /// 存储顶点位置的数组
        var positions: [SIMD3<Float>] = []

        /// 存储法向量的数组
        var normals: [SIMD3<Float>] = []

        /// 存储三角形索引的数组
        var triangles: [UInt32] = []

        // 遍历所有点来为网格创建路径
        for pointIdx in 0..<points.count {
            /// 计算当前点的半径和方向
            let (radius, direction) = calculateRadiusAndDirection(at: pointIdx)

            /// 计算当前点的x轴和y轴
            let (xAxis, yAxis) = calculateAxes(direction: direction)

            // 在当前笔触点周围生成点（形成圆形截面）
            for point in 0..<pointsPerRing {
                /// 计算环上当前点的位置和法向量
                let (position, normal) = calculatePositionAndNormal(
                    pointI: pointIdx, 
                    point: point, 
                    radius: radius, 
                    xAxis: xAxis, 
                    yAxis: yAxis
                )

                // 将位置添加到位置集合
                positions.append(position)

                // 将法向量添加到法向量集合
                normals.append(normal)

                // 在每个点之间生成网格三角形
                if pointIdx + 1 < points.count {
                    appendTriangles(pointIdx: pointIdx, point: point, triangles: &triangles)
                }
            }
        }

        return (positions, normals, triangles)
    }

    /// 从给定点索引计算半径和方向
    private func calculateRadiusAndDirection(at index: Int) -> (Float, SIMD3<Float>) {
        // 如果是第一个或最后一个点
        if index == 0 || (index + 1 == points.count) {
            // 对于第一个和最后一个点，使用零半径和默认方向
            return (0, SIMD3<Float>(1, 0, 0)) // 半径为0，方向为x轴正方向
        } else {
            /// 当前点和前一个点的差值
            let diff = points[index] - points[index - 1]

            /// 从差值计算半径
            // clamp函数限制值在0-1范围内，powf是幂函数，length是向量长度
            let radius = maxRadius * powf(clamp(Float(maxRadius / length(diff)), min: Float(0), max: Float(1)), 0.3)

            return (radius, normalize(diff)) // 返回半径和标准化的方向向量
        }
    }

    /// 用给定方向计算x轴和y轴
    private func calculateAxes(direction: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        /// 方向和y轴的叉积，然后标准化（创建垂直于方向的x轴）
        let xAxis = normalize(cross(direction, SIMD3<Float>(0, 1, 0)))

        /// 方向和xAxis的叉积，然后标准化（创建垂直于方向和x轴的y轴）
        let yAxis = normalize(cross(direction, xAxis))

        return (xAxis, yAxis) // 返回局部坐标系的x轴和y轴
    }

    /// 计算笔触点周围环上一个点的位置和法向量
    private func calculatePositionAndNormal(
        pointI: Int,           // 笔触点索引
        point: Int,            // 环上点的索引
        radius: Float,         // 半径
        xAxis: SIMD3<Float>,   // x轴方向
        yAxis: SIMD3<Float>    // y轴方向
    ) -> (SIMD3<Float>, SIMD3<Float>) {
        /// 角度是2π除以每环点数（将圆分成8等份）
        let angle = 2 * .pi * Float(point) / Float(pointsPerRing)

        /// 从角度计算当前法向量（在x-y平面上的圆形）
        let normal = cos(angle) * xAxis + sin(angle) * yAxis

        /// 当前点的位置：笔触点位置加上半径乘以法向量
        let position = (points[pointI] - points[0]) + radius * normal

        return (position, normal) // 返回位置和法向量
    }

    /// 为网格中的当前点添加三角形索引
    private func appendTriangles(pointIdx: Int, point: Int, triangles: inout [UInt32]) {
        /// 定义四边形的四个顶点索引
        let quadIndices: [UInt32] = [
            UInt32(pointsPerRing * (pointIdx + 0) + (point + 0) % pointsPerRing), // 当前环当前点
            UInt32(pointsPerRing * (pointIdx + 1) + (point + 0) % pointsPerRing), // 下一环当前点
            UInt32(pointsPerRing * (pointIdx + 0) + (point + 1) % pointsPerRing), // 当前环下一点
            UInt32(pointsPerRing * (pointIdx + 1) + (point + 1) % pointsPerRing)  // 下一环下一点
        ]

        // 将四边形分解为两个三角形
        // 第一个三角形：索引3、0、2
        triangles.append(contentsOf: [quadIndices[3], quadIndices[0], quadIndices[2]])

        // 第二个三角形：索引3、1、0  
        triangles.append(contentsOf: [quadIndices[3], quadIndices[1], quadIndices[0]])
    }
}