/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An extension of Float3, Float4, and Float4x4 that creates additional calculations.
*/

// 这是文件头注释，说明了这个文件的用途：
// 为 Float3、Float4 和 Float4x4 类型创建扩展，添加额外的计算功能

import RealityKit  // 导入 RealityKit 框架，用于 AR/VR 开发
import simd        // 导入 simd 框架，提供高性能的数学计算功能

// 类型别名定义 - 为复杂的类型创建简单的名称
/// The type alias to create a new name for SIMD3<Float>.
typealias Float3 = SIMD3<Float>    // Float3 = 3个浮点数组成的向量 (x, y, z)

/// The type alias to create a new name for SIMD4<Float>.
typealias Float4 = SIMD4<Float>    // Float4 = 4个浮点数组成的向量 (x, y, z, w)

/// The type alias to create a new name for simd_float4x4.
typealias Float4x4 = simd_float4x4 // Float4x4 = 4x4 浮点数矩阵，常用于3D变换

// 为 Float3 类型添加扩展功能
extension Float3 {
    // 从 Float4 创建 Float3 的初始化器
    // Initialize Float4 with Float3 inputs.
    init(_ float4: Float4) {
        self.init()  // 调用默认初始化器
        
        // 从 Float4 中提取前3个分量赋值给 Float3
        x = float4.x  // 复制 x 分量
        y = float4.y  // 复制 y 分量
        z = float4.z  // 复制 z 分量
        // 注意：忽略了 Float4 的 w 分量
    }
}

// 为 Float4 类型添加扩展功能
extension Float4 {
    /// Ignore the W value to convert Float4 into Float3.
    // 将 Float4 转换为 Float3 的便捷方法
    func toFloat3() -> Float3 {
        Float3(self)  // 调用上面定义的 Float3 初始化器
    }
}

// 为 Float4x4 矩阵类型添加扩展功能
extension Float4x4 {
    /// The value to access the identity of Float4x4.
    // 静态属性：获取 4x4 单位矩阵
    static var identity: Float4x4 {
        matrix_identity_float4x4  // 返回系统提供的单位矩阵
        // 单位矩阵的作用：不改变向量的变换矩阵
    }
    
    /// The translation component of Float4x4 and return as Float3.
    // 从变换矩阵中提取平移分量
    func translation() -> Float3 {
        columns.3.toFloat3()  // 矩阵的第4列包含平移信息，转换为 Float3
        // columns.3 表示矩阵的第4列（索引从0开始）
        // 在4x4变换矩阵中，第4列存储平移向量
    }
}

// 全局函数：数学夹紧函数
/// Create a mathematical clamp.
func clamp(_ valueX: Float, min minV: Float, max maxV: Float) -> Float {
    return min(maxV, max(minV, valueX))
    // 这个函数的作用是将 valueX 限制在 minV 和 maxV 之间
    // 如果 valueX < minV，返回 minV
    // 如果 valueX > maxV，返回 maxV
    // 否则返回 valueX 本身
}