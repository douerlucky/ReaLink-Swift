/*
画笔类型和配置管理
*/

import SwiftUI
import RealityKit
import UIKit

// UIColor扩展，用于材质效果增强
extension UIColor {
    /// 增加颜色亮度
    func withBrightness(multiplier: Float) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return UIColor(
            red: min(1.0, red * CGFloat(multiplier)),
            green: min(1.0, green * CGFloat(multiplier)),
            blue: min(1.0, blue * CGFloat(multiplier)),
            alpha: alpha
        )
    }
}

// 画笔类型枚举
enum BrushType: String, CaseIterable {
    case cylindrical = "圆柱体"
    case cubic = "立方体"
    case prismatic = "四棱柱"
    
    var displayName: String {
        return self.rawValue
    }
}

// 画笔模式枚举
enum BrushMode: String, CaseIterable {
    case continuous = "连续"
    case dotted = "断续"
    
    var displayName: String {
        return self.rawValue
    }
}

// Shader类型枚举
enum ShaderType: String, CaseIterable {
    case simple = "简单材质"
    case metallic = "金属材质"
    case emissive = "发光材质"
    case glass = "玻璃材质"
    
    var displayName: String {
        return self.rawValue
    }
}

// 画笔配置结构体 - 管理3D绘画中画笔的所有属性和行为
struct BrushConfig {
    // MARK: - 画笔属性配置
    
    // 画笔类型：圆柱形或立方体形状
    var type: BrushType = .cylindrical
    
    // 绘制模式：连续绘制或断续绘制
    var mode: BrushMode = .continuous
    
    // 着色器类型：决定材质的视觉效果（简单/金属/发光/玻璃）
    var shader: ShaderType = .simple
    
    // 画笔大小：半径值，默认1厘米（1E-2 = 0.01米）
    var size: Float = 1E-2  // 默认大小
    
    // 断续模式下点之间的间距：2厘米间隔
    var dottedSpacing: Float = 0.02  // 断续模式的间距
    
    // 画笔颜色：默认白色
    var color: UIColor = .white
    
    // MARK: - 材质创建方法
    
    // 根据当前配置创建对应的RealityKit材质
    func createMaterial() -> RealityKit.Material {
        // 使用switch语句根据着色器类型创建不同的材质
        switch shader {
        case .simple:
            // 简单材质：不反光的基础材质，粗糙度为1.0（完全漫反射）
            return SimpleMaterial(color: color, roughness: .float(1.0), isMetallic: false)
            
        case .metallic:
            // 金属材质：低粗糙度（0.1）创造反光效果，启用金属属性
            return SimpleMaterial(color: color, roughness: .float(0.01), isMetallic: true)
            
        case .emissive:
            // 发光材质：使用UnlitMaterial创建自发光效果
            // 创建发光材质，增加炫光效果
            var material = UnlitMaterial(color: color)
            // 增加发光强度，让颜色更亮（亮度翻倍）
            let brighterColor = color.withBrightness(multiplier: 200.0)
            // 重新创建材质使用更亮的颜色
            material = UnlitMaterial(color: brighterColor)
            return material
            
        case .glass:
            // 玻璃材质：透明效果的材质
            // 创建透明玻璃材质，将alpha设为0.1（10%不透明度，90%透明）
            let glassColor = color.withAlphaComponent(0.1)
            // 粗糙度为0创造完全光滑的玻璃表面
            return SimpleMaterial(color: glassColor, roughness: .float(0.0), isMetallic: false)
        }
    }
}

// BrushConfig.swift 添加 Codable 支持
extension BrushConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case type, mode, shader, size, dottedSpacing, color
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(BrushType.self, forKey: .type)
        mode = try container.decode(BrushMode.self, forKey: .mode)
        shader = try container.decode(ShaderType.self, forKey: .shader)
        size = try container.decode(Float.self, forKey: .size)
        dottedSpacing = try container.decode(Float.self, forKey: .dottedSpacing)
        
        // UIColor 需要特殊处理
        let colorData = try container.decode(Data.self, forKey: .color)
        color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) ?? .white
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(mode, forKey: .mode)
        try container.encode(shader, forKey: .shader)
        try container.encode(size, forKey: .size)
        try container.encode(dottedSpacing, forKey: .dottedSpacing)
        
        // UIColor 序列化
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        try container.encode(colorData, forKey: .color)
    }
}

// 枚举支持 Codable
extension BrushType: Codable {}
extension BrushMode: Codable {}
extension ShaderType: Codable {}

// 可序列化的笔画数据结构
struct SerializableStroke: Codable {
    let points: [SerializablePoint3D]
    let brushConfig: BrushConfig
    let timestamp: Date
    let userId: Int64?  // ✅ 添加用户ID字段
    
    init(from advancedStroke: AdvancedStroke) {
        self.points = advancedStroke.points.map(SerializablePoint3D.init)
        self.brushConfig = advancedStroke.brushConfig
        self.timestamp = Date()
        self.userId = advancedStroke.userId  // ✅ 保存用户ID
    }
    
    func toAdvancedStroke() -> AdvancedStroke {
        print("🔧 从序列化数据创建AdvancedStroke，包含 \(points.count) 个点，用户ID: \(userId ?? -1)")
        
        // ✅ 创建时传入userId
        var stroke = AdvancedStroke(brushConfig: brushConfig, userId: userId)
        
        // 🔧 修复：验证并过滤有效点
        let validPoints = points.compactMap { serializablePoint -> SIMD3<Float>? in
            let point = serializablePoint.toSIMD3()
            
            // 检查点是否有效
            guard !point.x.isNaN && !point.y.isNaN && !point.z.isNaN &&
                  point.x.isFinite && point.y.isFinite && point.z.isFinite else {
                print("⚠️ 跳过无效点: (\(point.x), \(point.y), \(point.z))")
                return nil
            }
            
            return point
        }
        
        stroke.points = validPoints
        
        print("🔧 有效点数: \(validPoints.count)/\(points.count)，用户ID: \(stroke.userId ?? -1)")
        
        return stroke
    }
}
struct SerializablePoint3D: Codable {
    let x: Float
    let y: Float
    let z: Float
    
    init(_ point: SIMD3<Float>) {
        // 🔧 修复：确保序列化的点数据有效
        self.x = point.x.isNaN || !point.x.isFinite ? 0.0 : point.x
        self.y = point.y.isNaN || !point.y.isFinite ? 0.0 : point.y
        self.z = point.z.isNaN || !point.z.isFinite ? 0.0 : point.z
    }
    
    func toSIMD3() -> SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}

// 空间画作数据结构 - 修复：移除answerId，添加userId
struct SpatialPaintingData: Codable {
    let id: Int64?
    let locationId: Int64?
    let questionId: Int64?
    let userId: Int64?
    let strokes: [SerializableStroke]
    let createdAt: String  // 🔧 修复：改为String类型
    let version: String
    
    init(strokes: [SerializableStroke], locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) {
        self.id = nil
        self.locationId = locationId
        self.questionId = questionId
        self.userId = userId
        self.strokes = strokes
        self.createdAt = ISO8601DateFormatter().string(from: Date())  // 🔧 修复：转换为字符串
        self.version = "1.0"
    }
    
    // 🔧 新增：自定义解码方法处理不同的时间格式
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        locationId = try container.decodeIfPresent(Int64.self, forKey: .locationId)
        questionId = try container.decodeIfPresent(Int64.self, forKey: .questionId)
        userId = try container.decodeIfPresent(Int64.self, forKey: .userId)
        strokes = try container.decode([SerializableStroke].self, forKey: .strokes)
        version = try container.decode(String.self, forKey: .version)
        
        // 🔧 修复：灵活处理createdAt字段
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            self.createdAt = createdAtString
        } else if let createdAtDouble = try? container.decode(Double.self, forKey: .createdAt) {
            // 如果是时间戳格式，转换为ISO8601字符串
            let date = Date(timeIntervalSince1970: createdAtDouble)
            self.createdAt = ISO8601DateFormatter().string(from: date)
        } else if let createdAtTimestamp = try? container.decode(TimeInterval.self, forKey: .createdAt) {
            let date = Date(timeIntervalSince1970: createdAtTimestamp)
            self.createdAt = ISO8601DateFormatter().string(from: date)
        } else {
            // 默认值
            self.createdAt = ISO8601DateFormatter().string(from: Date())
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, locationId, questionId, userId, strokes, createdAt, version
    }
}
