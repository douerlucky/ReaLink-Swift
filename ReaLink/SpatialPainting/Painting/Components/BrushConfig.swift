/*
画笔类型和配置管理 - 增强版（更亮、更粗的发光画笔）
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
    
    /// 增强颜色的饱和度和亮度 - 让画笔颜色更鲜艳明亮
    func enhancedColor(saturationBoost: CGFloat = 1.6, brightnessBoost: CGFloat = 1.5) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // 🎨 大幅增强饱和度和亮度
        let newSaturation = min(1.0, saturation * saturationBoost)
        let newBrightness = min(1.0, brightness * brightnessBoost)
        
        return UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: alpha)
    }
    
    // 🔥 新增：超级增强版 - 专为发光材质设计
    func superEnhancedColor(saturationBoost: CGFloat = 2.0, brightnessBoost: CGFloat = 2.0) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // 🔥 极致增强饱和度和亮度
        let newSaturation = min(1.0, saturation * saturationBoost)
        let newBrightness = min(1.0, brightness * brightnessBoost)
        
        return UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: alpha)
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
    
    // 🔥 修改：默认使用发光材质
    var shader: ShaderType = .emissive  // 改为发光材质
    
    // 🔥 修改：增加默认画笔大小到 3厘米（更粗）
    var size: Float = 0.03  // 从 0.01 (10mm) 增加到 0.03 (30mm)
    
    // 断续模式下点之间的间距
    var dottedSpacing: Float = 0.02
    
    // 🔥 修改：默认使用鲜艳的黄色（发光效果更明显）
    var color: UIColor = UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0)
    
    // MARK: - 材质创建方法
    
    // 根据当前配置创建对应的RealityKit材质
    func createMaterial() -> RealityKit.Material {
        switch shader {
        case .simple:
            let enhancedColor = color.enhancedColor()
            return SimpleMaterial(color: enhancedColor, roughness: .float(0.05), isMetallic: false)
            
        case .metallic:
            let enhancedColor = color.enhancedColor()
            return SimpleMaterial(color: enhancedColor, roughness: .float(0.01), isMetallic: true)
            
        case .emissive:
            // 🔥 大幅增强发光效果
            // 1. 先使用超级增强色彩
            let superEnhanced = color.superEnhancedColor(saturationBoost: 2.5, brightnessBoost: 2.5)
            
            // 2. 再应用超高亮度倍数（从200提升到800）
            let glowColor = superEnhanced.withBrightness(multiplier: 800.0)
            
            var material = UnlitMaterial(color: glowColor)
            return material
            
        case .glass:
            let enhancedColor = color.enhancedColor()
            let glassColor = enhancedColor.withAlphaComponent(0.15)
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
    let userId: Int64?
    
    init(from advancedStroke: AdvancedStroke) {
        self.points = advancedStroke.points.map(SerializablePoint3D.init)
        self.brushConfig = advancedStroke.brushConfig
        self.timestamp = Date()
        self.userId = advancedStroke.userId
    }
    
    func toAdvancedStroke() -> AdvancedStroke {
        print("🔧 从序列化数据创建AdvancedStroke，包含 \(points.count) 个点，用户ID: \(userId ?? -1)")
        
        var stroke = AdvancedStroke(brushConfig: brushConfig, userId: userId)
        
        let validPoints = points.compactMap { serializablePoint -> SIMD3<Float>? in
            let point = serializablePoint.toSIMD3()
            
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
        self.x = point.x.isNaN || !point.x.isFinite ? 0.0 : point.x
        self.y = point.y.isNaN || !point.y.isFinite ? 0.0 : point.y
        self.z = point.z.isNaN || !point.z.isFinite ? 0.0 : point.z
    }
    
    func toSIMD3() -> SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}

// 空间画作数据结构
struct SpatialPaintingData: Codable {
    let id: Int64?
    let locationId: Int64?
    let questionId: Int64?
    let userId: Int64?
    let strokes: [SerializableStroke]
    let createdAt: String
    let version: String
    
    init(strokes: [SerializableStroke], locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) {
        self.id = nil
        self.locationId = locationId
        self.questionId = questionId
        self.userId = userId
        self.strokes = strokes
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.version = "1.0"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        locationId = try container.decodeIfPresent(Int64.self, forKey: .locationId)
        questionId = try container.decodeIfPresent(Int64.self, forKey: .questionId)
        userId = try container.decodeIfPresent(Int64.self, forKey: .userId)
        strokes = try container.decode([SerializableStroke].self, forKey: .strokes)
        version = try container.decode(String.self, forKey: .version)
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            self.createdAt = createdAtString
        } else if let createdAtDouble = try? container.decode(Double.self, forKey: .createdAt) {
            let date = Date(timeIntervalSince1970: createdAtDouble)
            self.createdAt = ISO8601DateFormatter().string(from: date)
        } else if let createdAtTimestamp = try? container.decode(TimeInterval.self, forKey: .createdAt) {
            let date = Date(timeIntervalSince1970: createdAtTimestamp)
            self.createdAt = ISO8601DateFormatter().string(from: date)
        } else {
            self.createdAt = ISO8601DateFormatter().string(from: Date())
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, locationId, questionId, userId, strokes, createdAt, version
    }
}
