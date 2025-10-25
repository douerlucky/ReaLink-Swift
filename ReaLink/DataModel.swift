import Foundation

// MARK: - 基础数据模型（已移至 NetworkServices.swift）
// User, Question, LocationInfo 等模型已经在 NetworkServices.swift 中定义

// MARK: - 本地业务逻辑模型
struct Location: Codable, Identifiable {
    let id: Int64
    let name: String
    let longitude: Double // 经度
    let latitude: Double // 纬度
    let questionCount: Int
    
    var Questions: [Int] = []
}

struct Real3DViewSpace: Codable, Identifiable {
    let id: Int64
    let locationID: Int64
    let name: String
    let filename: String
}

// MARK: - 空间绘画相关数据模型（移除重复定义）
// SpatialPaintingData 已在 NetworkServices.swift 中定义，这里只定义本地特有的类型

struct PaintingStroke: Codable, Identifiable {
    let id = UUID()
    let points: [PaintingPoint]
    let color: PaintingColor
    let thickness: Float
    let timestamp: Date
    
    private enum CodingKeys: String, CodingKey {
        case points, color, thickness, timestamp
    }
}

struct PaintingPoint: Codable {
    let position: SIMD3<Float>
    let timestamp: TimeInterval
}

struct PaintingColor: Codable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
    
    init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

struct PaintingMetadata: Codable {
    let createdAt: Date
    let updatedAt: Date
    let authorId: Int64?
    let version: String
}


// MARK: - 3D模型相关数据模型（移除重复定义）
// ThreeDModelsData 已在 NetworkServices.swift 中定义，这里只定义本地特有的类型

struct ThreeDModel: Codable, Identifiable {
    let id: UUID
    let name: String
    let position: SIMD3<Float>
    let rotation: SIMD4<Float> // quaternion
    let scale: SIMD3<Float>
    let modelType: LocalModelType  // 改名避免冲突
    let color: LocalModelColor     // 改名避免冲突
    let timestamp: Date
    
    // 手动实现 Codable
    private enum CodingKeys: String, CodingKey {
        case id, name, position, rotation, scale, modelType, color, timestamp
    }
    
    init(id: UUID = UUID(), name: String, position: SIMD3<Float>, rotation: SIMD4<Float>, scale: SIMD3<Float>, modelType: LocalModelType, color: LocalModelColor, timestamp: Date) {
        self.id = id
        self.name = name
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.modelType = modelType
        self.color = color
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 处理可能缺失的 id
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = UUID(uuidString: idString) ?? UUID()
        } else {
            self.id = UUID()
        }
        
        self.name = try container.decode(String.self, forKey: .name)
        
        // 处理 SIMD3<Float> 类型
        if let posArray = try? container.decode([Float].self, forKey: .position), posArray.count >= 3 {
            self.position = SIMD3<Float>(posArray[0], posArray[1], posArray[2])
        } else {
            self.position = SIMD3<Float>(0, 0, 0)
        }
        
        if let rotArray = try? container.decode([Float].self, forKey: .rotation), rotArray.count >= 4 {
            self.rotation = SIMD4<Float>(rotArray[0], rotArray[1], rotArray[2], rotArray[3])
        } else {
            self.rotation = SIMD4<Float>(0, 0, 0, 1)
        }
        
        if let scaleArray = try? container.decode([Float].self, forKey: .scale), scaleArray.count >= 3 {
            self.scale = SIMD3<Float>(scaleArray[0], scaleArray[1], scaleArray[2])
        } else {
            self.scale = SIMD3<Float>(1, 1, 1)
        }
        
        self.modelType = try container.decode(LocalModelType.self, forKey: .modelType)
        self.color = try container.decode(LocalModelColor.self, forKey: .color)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode([position.x, position.y, position.z], forKey: .position)
        try container.encode([rotation.x, rotation.y, rotation.z, rotation.w], forKey: .rotation)
        try container.encode([scale.x, scale.y, scale.z], forKey: .scale)
        try container.encode(modelType, forKey: .modelType)
        try container.encode(color, forKey: .color)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

struct LocalModelColor: Codable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
    
    init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

enum LocalModelType: String, Codable, CaseIterable {
    case cube = "cube"
    case sphere = "sphere"
    case cylinder = "cylinder"
    case plane = "plane"
    case pyramid = "pyramid"
    
    var displayName: String {
        switch self {
        case .cube: return "立方体"
        case .sphere: return "球体"
        case .cylinder: return "圆柱体"
        case .plane: return "平面"
        case .pyramid: return "锥体"
        }
    }
}

struct ModelMetadata: Codable {
    let createdAt: Date
    let updatedAt: Date
    let authorId: Int64?
    let version: String
    let totalModels: Int
}



// MARK: - 测试初始化数据
let user_1 = User(id: 1, username: "douer_lucky", avatarUrl: "momo_test", createdAt: "1", updatedAt: "1")
let user_2 = User(id: 2, username: "nijika", avatarUrl: "momo_test", createdAt: "1", updatedAt: "1")
let user_3 = User(id: 3, username: "Akie", avatarUrl: "momo_test", createdAt: "1", updatedAt: "1")

let Question_1 = Question(id: 1, locationID: 1, userID: 1, actualPlace: "华中农业大学博物馆", title: "华农博物馆开了吗", content: "我要去华农博物馆，不知道现在开了吗", replyCount: 0, status: "待解决", createdAt: "2025-01-15T10:30:00Z", updatedAt: "2025-01-15T10:30:00Z", username: "douer_lucky", avatarUrl: "momo_test")
let Question_2 = Question(id: 2, locationID: 2, userID: 1, actualPlace: "华中农业大学梧桐步行街", title: "华农步行街开了吗", content: "我要去步行街，不知道现在开了吗", replyCount: 0, status: "待解决", createdAt: "2025-01-15T10:30:00Z", updatedAt: "2025-01-15T10:30:00Z", username: "douer_lucky", avatarUrl: "momo_test")
let Question_3 = Question(id: 3, locationID: 2, userID: 2, actualPlace: "华中农业大学梧桐步行街醉得意", title: "醉得意好吃吗", content: "我想请别人吃饭，这家店好吃吗", replyCount: 0, status: "待解决", createdAt: "2025-01-15T10:30:00Z", updatedAt: "2025-01-15T10:30:00Z", username: "nijika", avatarUrl: "momo_test")

let hzau_musuem = Location(id: 1, name: "华中农业大学博物馆", longitude: 114.357236, latitude: 30.475595, questionCount: 0, Questions: [1])
let wutongSteet = Location(id: 2, name: "华中农业大学梧桐步行街", longitude: 114.349995, latitude: 30.474459, questionCount: 0, Questions: [2,3])

let hzau_musuem_3D = Real3DViewSpace(id: 1, locationID: 1, name: "华中农业大学博物馆实景", filename: "modern_buildings_night")
let wutongStreet_3D = Real3DViewSpace(id: 2, locationID: 2, name: "华中农业大学梧桐广场实景", filename: "docklands_02")

// MARK: - 便捷方法
extension Location {
    func toLocationInfo() -> LocationInfo {
        return LocationInfo(
            id: self.id,
            name: self.name,
            latitude: self.latitude,
            longitude: self.longitude
        )
    }
}

// MARK: - AI聊天消息模型
struct AIChatMessage: Identifiable, Codable {
    var id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

func formatDate(_ dateString: String) -> String {
    let formatter = ISO8601DateFormatter()
    
    // 如果直接解析失败，尝试其他格式
    guard let date = formatter.date(from: dateString) else {
        // 尝试其他可能的格式
        let alternativeFormatter = DateFormatter()
        alternativeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        alternativeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        if let parsedDate = alternativeFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat =  "yyyy年MM月dd日 HH:mm"
            displayFormatter.timeZone = TimeZone.current // 使用本地时区
            return displayFormatter.string(from: parsedDate)
        }
        
        return dateString
    }
    
    let displayFormatter = DateFormatter()
    displayFormatter.dateFormat = "yyyy年MM月dd日 HH:mm" 
    displayFormatter.timeZone = TimeZone.current // 使用本地时区
    return displayFormatter.string(from: date)
}

func formatAnswerDate(_ dateString: String) -> String {
    let formatter = ISO8601DateFormatter()
    
    guard let date = formatter.date(from: dateString) else {
        // 尝试其他可能的格式
        let alternativeFormatter = DateFormatter()
        alternativeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        alternativeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        if let parsedDate = alternativeFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM月dd日 HH:mm"
            displayFormatter.timeZone = TimeZone.current // 使用本地时区
            return displayFormatter.string(from: parsedDate)
        }
        
        return dateString
    }
    
    let displayFormatter = DateFormatter()
    displayFormatter.dateFormat = "MM月dd日 HH:mm"
    displayFormatter.timeZone = TimeZone.current // 使用本地时区
    return displayFormatter.string(from: date)
}

func formatTimestamp(_ dateString: String, format: String = "MM月dd日 HH:mm") -> String {
    // 先尝试 ISO8601 格式
    let iso8601Formatter = ISO8601DateFormatter()
    if let date = iso8601Formatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = format
        displayFormatter.timeZone = TimeZone.current
        return displayFormatter.string(from: date)
    }
    
    // 尝试带毫秒的格式
    let alternativeFormatter = DateFormatter()
    alternativeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    alternativeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    
    if let date = alternativeFormatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = format
        displayFormatter.timeZone = TimeZone.current
        return displayFormatter.string(from: date)
    }
    
    // 尝试不带毫秒的格式
    alternativeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    if let date = alternativeFormatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = format
        displayFormatter.timeZone = TimeZone.current
        return displayFormatter.string(from: date)
    }
    
    return dateString
}
