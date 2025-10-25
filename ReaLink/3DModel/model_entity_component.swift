//
//  ModelEntityComponent.swift
//  ReaLink
//
//  苹果官方推荐方式：使用组件来标识实体类型
//

import RealityKit
import Foundation

// MARK: - 自定义组件来标识模型实体
struct ModelEntityComponent: Component {
    let modelType: ModelType
    let modelId: UUID
    let userId: Int64?
    
    init(modelType: ModelType, modelId: UUID, userId: Int64? = nil) {
        self.modelType = modelType
        self.modelId = modelId
        self.userId = userId
    }
}

// MARK: - 扩展Entity以支持模型操作
extension Entity {
    
    // 检查是否为模型实体（苹果官方推荐方式）
    var isModelEntity: Bool {
        return components.has(ModelEntityComponent.self) && 
               components.has(InputTargetComponent.self) && 
               components.has(CollisionComponent.self)
    }
    
    // 获取模型组件
    var modelComponent: ModelEntityComponent? {
        return components[ModelEntityComponent.self]
    }
    
    // 获取模型类型
    var modelType: ModelType? {
        return modelComponent?.modelType
    }
    
    // 获取模型ID
    var modelId: UUID? {
        return modelComponent?.modelId
    }
    
    // 获取模型所属用户ID
    var modelUserId: Int64? {
        return modelComponent?.userId
    }
    
    // 设置为可交互的模型实体
    func setupAsModelEntity(modelType: ModelType, modelId: UUID, userId: Int64? = nil) {
           print("🔧 开始设置实体为模型: \(name)")
           
           // 1. 添加模型组件
           let modelComponent = ModelEntityComponent(modelType: modelType, modelId: modelId, userId: userId)
           components.set(modelComponent)
           print("   ✅ 已添加 ModelEntityComponent")
           
           // 2. 确保有碰撞组件
           if !components.has(CollisionComponent.self) {
               // 生成碰撞形状
               generateCollisionShapes(recursive: true)
               print("   ✅ 已生成 CollisionComponent")
           }
           
           // 3. 添加输入目标组件
           let inputTarget = InputTargetComponent(allowedInputTypes: [.indirect, .direct])
           components.set(inputTarget)
           print("   ✅ 已添加 InputTargetComponent")
           
           // 4. 添加悬停效果
           let hoverEffect = HoverEffectComponent(.highlight(.init(color: .systemBlue, strength: 0.8)))
           components.set(hoverEffect)
           print("   ✅ 已添加 HoverEffectComponent")
           
           // 5. 验证所有组件
           print("🔍 最终组件验证:")
           print("   - ModelEntityComponent: \(components.has(ModelEntityComponent.self))")
           print("   - CollisionComponent: \(components.has(CollisionComponent.self))")
           print("   - InputTargetComponent: \(components.has(InputTargetComponent.self))")
           print("   - HoverEffectComponent: \(components.has(HoverEffectComponent.self))")
       }
    
    // 检查用户是否可以操作此模型
    func canUserManipulate(currentUserId: Int64?) -> Bool {
        guard let currentUserId = currentUserId,
              let modelUserId = self.modelUserId else {
            return false
        }
        return currentUserId == modelUserId
    }
}
