/*
画笔类型和配置管理 - 修复颜色区分度问题
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
    
    // 🔥 修复：更智能的发光颜色增强算法 - 保持原色不过度增强
    func glowEnhancedColor() -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // 🎨 关键修复：温和增强，保持颜色本质
        // 1. 轻微提升饱和度，让颜色更鲜艳但不失真
        let newSaturation = min(1.0, saturation * 1.15)
        
        // 2. 根据原始亮度智能调整 - 让深色变亮但保持色相差异
        let brightnessBoost: CGFloat
        if brightness < 0.2 {
            // 非常暗的颜色：需要较大提升才能看见（1.8倍）
            brightnessBoost = 1.8
        } else if brightness < 0.4 {
            // 较暗的颜色：适度提升（1.5倍）
            brightnessBoost = 1.5
        } else if brightness < 0.7 {
            // 中等亮度：轻微提升（1.3倍）
            brightnessBoost = 1.3
        } else {
            // 已经很亮的颜色：保持原样（1.1倍）
            brightnessBoost = 1.1
        }
        
        let newBrightness = min(1.0, brightness * brightnessBoost)
        
        return UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: alpha)
    }
    
    // 🔥 核心修复：发光倍增器从50降到2.5，保持真实颜色
    func applyGlowMultiplier() -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // 🎨 关键修复：倍增器从 50 降到 2.5，避免颜色过饱和
        // 2.5 倍足以产生发光效果，同时保持颜色区分度
        let multiplier: CGFloat = 2.5
        
        // 🎨 使用线性增强，保持颜色的相对关系
        // 例如：红色(1,0,0) -> (2.5,0,0) -> clamp到(1,0,0)仍是纯红
        //       深红(0.5,0,0) -> (1.25,0,0) -> clamp到(1,0,0)变亮但保持纯红
        //       粉红(1,0.5,0.5) -> (2.5,1.25,1.25) -> clamp到(1,1,1)会偏白
        // 所以需要更温和的处理
        let enhanceRed = min(1.0, red * multiplier)
        let enhanceGreen = min(1.0, green * multiplier)
        let enhanceBlue = min(1.0, blue * multiplier)
        
        return UIColor(
            red: enhanceRed,
            green: enhanceGreen,
            blue: enhanceBlue,
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
    
    // 🔥 修改：默认使用发光材质
    var shader: ShaderType = .emissive
    
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
            // 🔥 核心修复：保持原色，只做轻微增强
            // 不再使用复杂的HSB增强，避免颜色失真
            
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            // 🎨 轻微增强亮度（1.2倍），保持颜色差异
            let brightnessFactor: CGFloat = 1.2
            let enhancedRed = min(1.0, red * brightnessFactor)
            let enhancedGreen = min(1.0, green * brightnessFactor)
            let enhancedBlue = min(1.0, blue * brightnessFactor)
            
            let finalColor = UIColor(
                red: enhancedRed,
                green: enhancedGreen,
                blue: enhancedBlue,
                alpha: alpha
            )
            
            var material = UnlitMaterial(color: finalColor)
            
            print("🎨 发光颜色处理（保持原色）:")
            print("   原始RGB: (\(red), \(green), \(blue))")
            print("   增强RGB: (\(enhancedRed), \(enhancedGreen), \(enhancedBlue))")
            
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
