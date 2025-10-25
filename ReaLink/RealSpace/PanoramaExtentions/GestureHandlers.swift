//
//  GestureHandlers.swift
//  ReaLink
//
//  手势交互处理
//

import RealityKit
import SwiftUI

extension BasicPanoramaView {
    
    // MARK: - 拖拽手势处理
    func handleDragChanged(_ value: EntityTargetValue<DragGesture.Value>) {
        var targetEntity = value.entity
        
        // 查找模型组件
        var checkEntity: Entity? = targetEntity
        var modelComponent: ModelEntityComponent? = nil
        
        while checkEntity != nil {
            if let comp = checkEntity!.components[ModelEntityComponent.self] {
                modelComponent = comp
                targetEntity = checkEntity!
                break
            }
            checkEntity = checkEntity!.parent
        }
        
        guard let modelComp = modelComponent else { return }
        
        // 权限检查
        let currentUserId = userManager.getUserId()
        guard targetEntity.canUserManipulate(currentUserId: currentUserId) else { return }
        
        // 🔥 关键修改：应用地面吸附
        let newPosition = value.convert(value.location3D, from: .local, to: targetEntity.parent!)
        
        // 使用 SceneManager 计算吸附后的位置
        let sceneManager = SceneManager(vrManager: vrManager)
        let snappedPosition = sceneManager.calculateGroundSnapPosition(
            from: newPosition,
            enableSnap: isGroundSnapEnabled
        )
        
        targetEntity.position = snappedPosition
        
        print("🫳【拖动模型】: \(modelComp.modelType.rawValue)")
        print("   原始位置: \(newPosition)")
        print("   吸附位置: \(snappedPosition)")
    }
    
    func handleDragEnded(_ value: EntityTargetValue<DragGesture.Value>) {
        var targetEntity = value.entity
        
        var checkEntity: Entity? = targetEntity
        var modelComponent: ModelEntityComponent? = nil
        
        while checkEntity != nil {
            if let comp = checkEntity!.components[ModelEntityComponent.self] {
                modelComponent = comp
                targetEntity = checkEntity!
                break
            }
            checkEntity = checkEntity!.parent
        }
        
        guard let modelComp = modelComponent else { return }
        
        if let model = findModelByEntity(targetEntity) {
            let fromPosition = model.originalPosition
            let toPosition = targetEntity.position  // 这已经是吸附后的位置
            
            let snapshot = ModelSnapshot(
                modelId: modelComp.modelId,
                modelType: modelComp.modelType,
                position: toPosition,
                scale: targetEntity.scale,
                color: model.color,
                userId: modelComp.userId
            )
            
            recordOperation(.move(from: fromPosition, to: toPosition), snapshot: snapshot)
            
            // 更新模型记录
            if let index = placedModels.firstIndex(where: { $0.id == model.id }) {
                let updatedModel = PlacedModel(
                    id: model.id,
                    entity: model.entity,
                    originalScale: model.originalScale,
                    originalPosition: toPosition,  // 保存吸附后的位置
                    type: model.type,
                    color: model.color,
                    size: model.size,
                    opacity: model.opacity,
                    userId: model.userId,
                    text: model.text,
                    username: model.username,      // ✅ 保留用户名
                    avatarUrl: model.avatarUrl     // ✅ 保留头像
                )
                placedModels[index] = updatedModel
            }
        }
        
        print("✅【拖动完成并记录历史】位置已吸附到地面")
    }
    // MARK: - 缩放手势处理
    func handleMagnifyChanged(_ value: EntityTargetValue<MagnifyGesture.Value>) {
        var targetEntity = value.entity
        
        var checkEntity: Entity? = targetEntity
        var modelComponent: ModelEntityComponent? = nil
        
        while checkEntity != nil {
            if let comp = checkEntity!.components[ModelEntityComponent.self] {
                modelComponent = comp
                targetEntity = checkEntity!
                break
            }
            checkEntity = checkEntity!.parent
        }
        
        guard let modelComp = modelComponent else { return }
        
        let currentUserId = userManager.getUserId()
        guard targetEntity.canUserManipulate(currentUserId: currentUserId) else { return }
        
        let scale = Float(value.magnification)
        targetEntity.scale = SIMD3<Float>(repeating: scale)
        
        print("📏【缩放模型】: \(modelComp.modelType.rawValue) 到: \(scale)")
    }
    
    func handleMagnifyEnded(_ value: EntityTargetValue<MagnifyGesture.Value>) {
        var targetEntity = value.entity
        
        var checkEntity: Entity? = targetEntity
        var modelComponent: ModelEntityComponent? = nil
        
        while checkEntity != nil {
            if let comp = checkEntity!.components[ModelEntityComponent.self] {
                modelComponent = comp
                targetEntity = checkEntity!
                break
            }
            checkEntity = checkEntity!.parent
        }
        
        guard let modelComp = modelComponent else { return }
        
        if let model = findModelByEntity(targetEntity) {
            let fromScale = model.originalScale
            let toScale = targetEntity.scale
            
            let snapshot = ModelSnapshot(
                modelId: modelComp.modelId,
                modelType: modelComp.modelType,
                position: targetEntity.position,
                scale: toScale,
                color: model.color,
                userId: modelComp.userId
            )
            
            recordOperation(.scale(from: fromScale, to: toScale), snapshot: snapshot)
            
            if let index = placedModels.firstIndex(where: { $0.id == model.id }) {
                let updatedModel = PlacedModel(
                    id: model.id,
                    entity: model.entity,
                    originalScale: toScale,
                    originalPosition: model.originalPosition,
                    type: model.type,
                    color: model.color,
                    size: model.size,
                    opacity: model.opacity,
                    userId: model.userId,
                    text: model.text,
                    username: model.username,      // ✅ 保留用户名
                    avatarUrl: model.avatarUrl     // ✅ 保留头像
                )
                placedModels[index] = updatedModel
            }
        }
        
        print("✅【缩放完成并记录历史】")
    }
    
    // MARK: - 点击手势处理
    func handleSpatialTap(_ value: EntityTargetValue<SpatialTapGesture.Value>) {
        var targetEntity = value.entity
        print("🎯【检测到实体点击】: \(targetEntity.name)")
        
        var checkEntity: Entity? = targetEntity
        var modelComponent: ModelEntityComponent? = nil
        
        while checkEntity != nil {
            if let comp = checkEntity!.components[ModelEntityComponent.self] {
                modelComponent = comp
                targetEntity = checkEntity!
                print("✅【在父级找到模型组件】: \(targetEntity.name)")
                break
            }
            checkEntity = checkEntity!.parent
        }
        
        if let modelComp = modelComponent {
            print("📦【处理模型实体点击】: \(targetEntity.name)")
            handleModelTap(targetEntity)
        } else if targetEntity.name.starts(with: "questionSphere_") {
            print("🟡【处理问题球体点击】")
            handleQuestionSphereTap(targetEntity.name)
        } else {
            print("ℹ️【未知实体类型】: \(targetEntity.name)")
        }
    }
    
    // MARK: - 模型点击处理
    func handleModelTap(_ entity: Entity) {
        guard let modelComponent = entity.modelComponent else { return }
        
        print("📦【模型被点击】:")
        print("   - 类型: \(modelComponent.modelType.rawValue)")
        print("   - ID: \(modelComponent.modelId)")
        print("   - 用户ID: \(modelComponent.userId ?? -1)")
        
        let currentUserId = userManager.getUserId()
        
        if let model = findModelByEntity(entity) {
            NotificationCenter.default.post(
                name: NSNotification.Name("ModelSelected"),
                object: nil,
                userInfo: ["model": model]
            )
        }
        
        if entity.canUserManipulate(currentUserId: currentUserId) {
            print("✅【用户有权限操作此模型】")
        } else {
            print("🚫【用户无权限操作此模型】")
        }
    }
    
    // MARK: - 辅助方法
    func findModelByEntity(_ entity: Entity) -> PlacedModel? {
        guard let modelId = entity.modelId else {
            print("❌【实体没有模型ID】: \(entity.name)")
            return nil
        }
        
        let foundModel = placedModels.first { model in
            model.id == modelId
        }
        
        if let model = foundModel {
            print("🎯【找到对应模型】: \(model.id)")
        } else {
            print("❌【未找到对应模型】: modelId=\(modelId)")
        }
        
        return foundModel
    }
    
    // MARK: - 操作记录
    func recordOperation(_ operationType: ModelOperationRecord.OperationType, snapshot: ModelSnapshot) {
        let record = ModelOperationRecord(
            id: UUID(),
            operationType: operationType,
            modelData: snapshot,
            timestamp: Date()
        )
        
        modelOperationHistory.append(record)
        
        if modelOperationHistory.count > 50 {
            modelOperationHistory.removeFirst()
        }
        
        print("📝【记录操作】: \(operationType)")
    }
    
    func undoLastOperation() {
        guard let lastOperation = modelOperationHistory.popLast() else {
            print("❌【没有可撤回的操作】")
            return
        }
        
        switch lastOperation.operationType {
        case .add:
            if let modelIndex = placedModels.firstIndex(where: { $0.id == lastOperation.modelData.modelId }) {
                let model = placedModels[modelIndex]
                model.entity.removeFromParent()
                placedModels.remove(at: modelIndex)
                print("↩️【撤回添加操作，删除模型】: \(model.id)")
            }
            
        case .move(let fromPosition, _):
            if let modelIndex = placedModels.firstIndex(where: { $0.id == lastOperation.modelData.modelId }) {
                placedModels[modelIndex].entity.position = fromPosition
                print("↩️【撤回移动操作，恢复到位置】: \(fromPosition)")
            }
            
        case .scale(let fromScale, _):
            if let modelIndex = placedModels.firstIndex(where: { $0.id == lastOperation.modelData.modelId }) {
                placedModels[modelIndex].entity.scale = fromScale
                print("↩️【撤回缩放操作，恢复到尺寸】: \(fromScale)")
            }
            
        case .remove:
            let restoredModel = createModelFromSnapshot(lastOperation.modelData)
            placedModels.append(restoredModel)
            rootEntity.addChild(restoredModel.entity)
            print("↩️【撤回删除操作，恢复模型】: \(restoredModel.id)")
        }
    }
    
    func createModelFromSnapshot(_ snapshot: ModelSnapshot) -> PlacedModel {
        return createModelAt(
            position: snapshot.position,
            type: snapshot.modelType,
            color: snapshot.color,
            size: 0.1,
            opacity: 1.0,
            userId: snapshot.userId
        )
    }
}
