//
//  model_config.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/8/31.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

// MARK: - 统一模型配置管理器
struct ModelConfiguration {
    let type: ModelType
    let displayName: String
    let fileName: String
    let defaultSize: Float
    let icon: String
    let description: String
    let supportsTextInput: Bool  // 新增：是否支持文本输入
    let allowsColorCustomization: Bool  // 新增：是否允许颜色自定义
    
    init(type: ModelType, displayName: String, fileName: String? = nil, defaultSize: Float = 0.1, icon: String, description: String = "", supportsTextInput: Bool = false, allowsColorCustomization: Bool = true) {
        self.type = type
        self.displayName = displayName
        self.fileName = fileName ?? type.rawValue
        self.defaultSize = defaultSize
        self.icon = icon
        self.description = description
        self.supportsTextInput = supportsTextInput
        self.allowsColorCustomization = allowsColorCustomization
    }
}


class ModelRegistry {
    static let shared = ModelRegistry()
    
    // 统一的模型配置 - 在这里添加新模型
    private let modelConfigurations: [ModelType: ModelConfiguration] = [
        .cube: ModelConfiguration(
            type: .cube,
            displayName: "立方体",
            fileName: "cube",
            defaultSize: 0.1,
            icon: "cube.fill",
            description: "基础立方体模型"
        ),
        .sphere: ModelConfiguration(
            type: .sphere,
            displayName: "球体",
            fileName: "sphere",
            defaultSize: 0.1,
            icon: "circle.fill",
            description: "基础球体模型"
        ),
        .cylinder: ModelConfiguration(
            type: .cylinder,
            displayName: "圆柱体",
            fileName: "cylinder",
            defaultSize: 0.1,
            icon: "cylinder.fill",
            description: "基础圆柱体模型"
        ),
        .cone: ModelConfiguration(
            type: .cone,
            displayName: "锥体",
            fileName: "cone",
            defaultSize: 0.1,
            icon: "cone.fill",
            description: "基础锥体模型"
        ),
        .capsule: ModelConfiguration(
            type: .capsule,
            displayName: "胶囊",
            fileName: "capsule",
            defaultSize: 0.1,
            icon: "capsule.fill",
            description: "胶囊形状模型"
        ),
        .sign: ModelConfiguration(
               type: .sign,
               displayName: "告示牌",
               fileName: "sign",
               defaultSize: 0.1,
               icon: "signpost.right.fill",
               description: "自定义告示牌模型",
               supportsTextInput: true,      // 支持文本输入
               allowsColorCustomization: false  // 不允许颜色自定义
           ),
        
        .chatBubble: ModelConfiguration(
            type: .chatBubble,
            displayName: "聊天气泡",
            fileName: "chatBubble",           // 你的 USDZ 文件名
            defaultSize: 0.25,                // ✅ 增大默认尺寸到 25cm（原15cm）
            icon: "bubble.left.and.bubble.right.fill",
            description: "聊天气泡样式的半透明文本面板",
            supportsTextInput: true,          // ✅ 支持文字输入
            allowsColorCustomization: false   // ✅ 不允许改颜色（保持蓝色）
        ),
        
        // ✅ 新增：Emoji 模型配置（使用原本材质，不允许自定义颜色）
        .smileEmoji: ModelConfiguration(
            type: .smileEmoji,
            displayName: "微笑表情",
            fileName: "smile_emoji",
            defaultSize: 0.15,
            icon: "face.smiling",
            description: "微笑表情符号",
            supportsTextInput: false,
            allowsColorCustomization: false   // ✅ 不允许改颜色，使用原本材质
        ),
        
        .stareyesEmoji: ModelConfiguration(
            type: .stareyesEmoji,
            displayName: "星星眼表情",
            fileName: "stareyes_emoji",
            defaultSize: 0.15,
            icon: "star.fill",
            description: "星星眼表情符号",
            supportsTextInput: false,
            allowsColorCustomization: false   // ✅ 不允许改颜色，使用原本材质
        ),
        
        .sadEmoji: ModelConfiguration(
            type: .sadEmoji,
            displayName: "伤心表情",
            fileName: "sad_emoji",
            defaultSize: 0.15,
            icon: "face.dashed",
            description: "伤心表情符号",
            supportsTextInput: false,
            allowsColorCustomization: false   // ✅ 不允许改颜色，使用原本材质
        ),
        
        .questionEmoji: ModelConfiguration(
            type: .questionEmoji,
            displayName: "疑问表情",
            fileName: "question_emoji",
            defaultSize: 0.15,
            icon: "questionmark.circle",
            description: "疑问表情符号",
            supportsTextInput: false,
            allowsColorCustomization: false   // ✅ 不允许改颜色，使用原本材质
        ),
        
        .celebrateEmoji: ModelConfiguration(
            type: .celebrateEmoji,
            displayName: "庆祝表情",
            fileName: "celebrate_emoji",
            defaultSize: 0.15,
            icon: "party.popper",
            description: "庆祝表情符号",
            supportsTextInput: false,
            allowsColorCustomization: false   // ✅ 不允许改颜色，使用原本材质
        ),
        
        .poopEmoji: ModelConfiguration(
            type: .poopEmoji,
            displayName: "便便表情",
            fileName: "poop_emoji",
            defaultSize: 0.15,
            icon: "allergens",
            description: "便便表情符号",
            supportsTextInput: false,
            allowsColorCustomization: false   // ✅ 不允许改颜色，使用原本材质
        )
    ]
    
    func supportsTextInput(for type: ModelType) -> Bool {
        return modelConfigurations[type]?.supportsTextInput ?? false
    }

    func allowsColorCustomization(for type: ModelType) -> Bool {
        return modelConfigurations[type]?.allowsColorCustomization ?? true
    }
    
    private init() {}
    
    // 获取模型配置
    func getConfiguration(for type: ModelType) -> ModelConfiguration? {
        return modelConfigurations[type]
    }
    
    // 获取所有支持的模型类型
    func getAllSupportedTypes() -> [ModelType] {
        return Array(modelConfigurations.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    // 获取USDZ文件名
    func getUSDZFileName(for type: ModelType) -> String {
        let fileName = (modelConfigurations[type]?.fileName ?? type.rawValue) + ".usdz"
        print("🔍 获取模型文件名: type=\(type.rawValue), fileName=\(fileName)")
        
        // 确保文件名不为空
        if fileName.isEmpty || fileName == ".usdz" {
            print("⚠️ 警告：模型文件名为空，type=\(type.rawValue)")
            return "cube.usdz" // 返回默认文件名
        }
        
        return fileName
    }
    
    // 获取默认大小
    func getDefaultSize(for type: ModelType) -> Float {
        return modelConfigurations[type]?.defaultSize ?? 0.1
    }
    
    // 获取显示名称
    func getDisplayName(for type: ModelType) -> String {
        return modelConfigurations[type]?.displayName ?? type.rawValue
    }
    
    // 获取图标
    func getIcon(for type: ModelType) -> String {
        return modelConfigurations[type]?.icon ?? "cube.fill"
    }
}

enum ModelType: String, CaseIterable {
    case cube = "cube"
    case sphere = "sphere"
    case cylinder = "cylinder"
    case cone = "cone"
    case capsule = "capsule"
    case sign = "sign"
    case chatBubble = "chatBubble"
    // ✅ 新增：6个 Emoji 模型
    case smileEmoji = "smileEmoji"
    case stareyesEmoji = "stareyesEmoji"
    case sadEmoji = "sadEmoji"
    case questionEmoji = "questionEmoji"
    case celebrateEmoji = "celebrateEmoji"
    case poopEmoji = "poopEmoji"
    
    // 现在所有模型都使用USDZ文件
    var isCustomUSDZ: Bool {
        return true
    }
    
    // 使用ModelRegistry获取配置信息
    var displayName: String {
        return ModelRegistry.shared.getDisplayName(for: self)
    }
    
    var icon: String {
        return ModelRegistry.shared.getIcon(for: self)
    }
    
    var defaultSize: Float {
        return ModelRegistry.shared.getDefaultSize(for: self)
    }
}


// MARK: - 数据模型定义

struct ThreeDModelsData: Codable {
    let version: String
    let timestamp: TimeInterval
    let models: [SerializedModel]
    let totalCount: Int
}

struct SerializedModel: Codable {
    let id: String
    let type: String
    let position: ModelPosition
    let scale: ModelScale
    let rotation: ModelRotation
    let color: ModelColor
    let opacity: Float
    let size: Float
    let userId: Int64?
    let text: String?
    
    // ✅ 关键字段：用户信息
    let username: String?
    let avatarUrl: String?
    
    // 安全的旋转获取
    var safeRotation: ModelRotation {
        // 验证四元数是否有效
        let length = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z + rotation.w * rotation.w)
        
        if length > 0.0001 { // 有效的四元数
            return rotation
        } else {
            // 无效的四元数,返回单位四元数
            return ModelRotation(x: 0, y: 0, z: 0, w: 1)
        }
    }
}


struct ModelRotation: Codable {
    let x: Float
    let y: Float
    let z: Float
    let w: Float
    
    // 🔥 添加单位四元数静态属性
    static let identity = ModelRotation(x: 0, y: 0, z: 0, w: 1)
    
    init(x: Float, y: Float, z: Float, w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    init(from quaternion: simd_quatf) {
        self.x = quaternion.vector.x
        self.y = quaternion.vector.y
        self.z = quaternion.vector.z
        self.w = quaternion.vector.w
    }
    
    var quaternion: simd_quatf {
        return simd_quatf(ix: x, iy: y, iz: z, r: w)
    }
    
    // 🔥 添加从欧拉角创建的便捷初始化器（使用RealityKit的YZX顺序）
    init(eulerAngles: SIMD3<Float>) {
        // RealityKit 使用 YZX 旋转顺序
        let pitch = eulerAngles.x  // 绕X轴
        let yaw = eulerAngles.y    // 绕Y轴
        let roll = eulerAngles.z   // 绕Z轴
        
        let cy = cos(yaw * 0.5)
        let sy = sin(yaw * 0.5)
        let cp = cos(pitch * 0.5)
        let sp = sin(pitch * 0.5)
        let cr = cos(roll * 0.5)
        let sr = sin(roll * 0.5)
        
        self.w = cr * cp * cy + sr * sp * sy
        self.x = sr * cp * cy - cr * sp * sy
        self.y = cr * sp * cy + sr * cp * sy
        self.z = cr * cp * sy - sr * sp * cy
    }
    
    // 🔥 转换为欧拉角（使用RealityKit的YZX顺序）
    var eulerAngles: SIMD3<Float> {
        let sinr_cosp = 2 * (w * x + y * z)
        let cosr_cosp = 1 - 2 * (x * x + y * y)
        let roll = atan2(sinr_cosp, cosr_cosp)
        
        let sinp = 2 * (w * y - z * x)
        let pitch = abs(sinp) >= 1 ? copysign(.pi / 2, sinp) : asin(sinp)
        
        let siny_cosp = 2 * (w * z + x * y)
        let cosy_cosp = 1 - 2 * (y * y + z * z)
        let yaw = atan2(siny_cosp, cosy_cosp)
        
        return SIMD3<Float>(pitch, yaw, roll)
    }
}

struct ModelPosition: Codable {
    let x: Float
    let y: Float
    let z: Float
}

struct ModelScale: Codable {
    let x: Float
    let y: Float
    let z: Float
}

struct ModelColor: Codable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
}


// MARK: - 模型管理器
class ModelManager: ObservableObject {
    @Published var isModelTestingEnabled: Bool = false
    @Published var cubeSize: Float = 0.1  // 立方体大小（米）
    @Published var cubeColor: Color = .blue
    @Published var modelOpacity: Float = 1.0
    @Published var selectedModelType: ModelType = .cube  // ✅ 移到主类定义中
    
    static let shared = ModelManager()
    private init() {}
    
    // 预设颜色
    let presetColors: [Color] = [
        .red, .blue, .green, .yellow,
        .orange, .purple, .pink, .cyan,
        .black, .white, .gray, .brown
    ]
    
    func reset() {
        isModelTestingEnabled = false
        cubeSize = 0.1
        cubeColor = .blue
        modelOpacity = 1.0
        selectedModelType = .cube  // 重置时也要重置选中的模型类型
    }
}

// MARK: - ✅ ChatBubble 特殊处理扩展
extension Entity {
    
    /// 为ChatBubble气泡设置蓝色材质和合适的透明度
    func setupChatBubbleMaterial() {
        print("🎨 开始设置ChatBubble材质...")
        
        guard let modelEntity = self as? ModelEntity else {
            print("⚠️ 不是ModelEntity，跳过材质设置")
            return
        }
        
        // ✅ 创建蓝色半透明材质（透明度30%，即opacity=0.7）
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.7))  // 蓝色 + 70%不透明度
        
        // 应用到所有网格
        if var modelComponent = modelEntity.model {
            modelComponent.materials = [material]
            modelEntity.model = modelComponent
            print("✅ 已应用蓝色半透明材质（70%不透明度）")
        }
    }
    
    /// 为ChatBubble添加大号文本
    /// - Parameters:
    ///   - text: 要显示的文本
    ///   - fontSize: 字体大小（默认0.05米=5厘米）
    func addChatBubbleText(_ text: String, fontSize: Float = 0.05) {
        print("📝 开始为ChatBubble添加文本: \(text)")
        
        // 创建文本网格
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.002,  // 2mm厚度
            font: .systemFont(ofSize: CGFloat(fontSize * 1000)),  // ✅ 更大的字体
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        // 创建深蓝色文本材质（不透明）
        var textMaterial = UnlitMaterial()
        textMaterial.color = .init(tint: UIColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1.0))  // 深蓝色，完全不透明
        
        // 创建文本实体
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.name = "ChatBubbleText"
        
        // ✅ 调整文本位置（居中显示）
        textEntity.position = SIMD3<Float>(0, 0, 0.01)  // 稍微向前，避免Z-fighting
        
        // 添加到当前实体
        self.addChild(textEntity)
        print("✅ 已添加大号文本实体")
    }
    
    /// 更新ChatBubble的文本内容
    func updateChatBubbleText(_ newText: String, fontSize: Float = 0.05) {
        print("🔄 更新ChatBubble文本: \(newText)")
        
        // 移除旧文本
        children.first(where: { $0.name == "ChatBubbleText" })?.removeFromParent()
        
        // 添加新文本
        addChatBubbleText(newText, fontSize: fontSize)
    }
}

// MARK: - ✅ 颜色辅助方法
extension ModelColor {
    
    /// 创建蓝色（用于ChatBubble）
    static var chatBubbleBlue: ModelColor {
        return ModelColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.7)  // 蓝色 + 70%不透明
    }
    
    /// 转换为UIColor
    var uiColor: UIColor {
        return UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
    
    /// 转换为SwiftUI Color
    var color: Color {
        return Color(uiColor: uiColor)
    }
}
