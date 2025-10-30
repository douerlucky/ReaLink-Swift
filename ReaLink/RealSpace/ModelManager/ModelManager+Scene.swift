//
//  ModelManager+Scene.swift
//  ReaLink
//
//  模型在场景中的创建和操作
//

import RealityKit
import SwiftUI

extension BasicPanoramaView {
    
    // MARK: - 创建加载占位符
    func createLoadingPlaceholder(size: Float) -> ModelEntity {
        let ringMesh = MeshResource.generateSphere(radius: size * 0.5)
        
        var ringMaterial = SimpleMaterial()
        ringMaterial.color = .init(tint: UIColor.systemBlue.withAlphaComponent(0.8))
        ringMaterial.metallic = 0.3
        ringMaterial.roughness = 0.7
        
        let ringEntity = ModelEntity(mesh: ringMesh, materials: [ringMaterial])
        
        let rotationAnimation = FromToByAnimation<Transform>(
            name: "loading",
            from: ringEntity.transform,
            to: Transform(
                scale: ringEntity.transform.scale,
                rotation: simd_quatf(angle: .pi * 2, axis: SIMD3<Float>(0, 1, 0)),
                translation: ringEntity.transform.translation
            ),
            duration: 1.5,
            timing: .linear,
            bindTarget: .transform
        )
        
        if let animationResource = try? AnimationResource.generate(with: rotationAnimation) {
            ringEntity.playAnimation(animationResource.repeat())
        }
        
        return ringEntity
    }
    
    // MARK: - 创建模型（完整属性版本）
    func createModelWithFullAttributes(
        position: SIMD3<Float>,
        scale: SIMD3<Float>,
        rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        type: ModelType,
        color: Color,
        size: Float,
        opacity: Float,
        userId: Int64?,
        text: String? = nil,
        username: String? = nil,    // ✅ 新增
        avatarUrl: String? = nil    // ✅ 新增
    ) -> PlacedModel {
        let modelId = UUID()
        
        pendingModelAttributes[modelId] = (position: position, scale: scale)
        let adjustedSize = max(size, 0.05)
        let finalColor = ModelRegistry.shared.allowsColorCustomization(for: type) ? color : Color.brown
        
        let placeholderEntity = createLoadingPlaceholder(size: adjustedSize)
        placeholderEntity.position = position
        placeholderEntity.scale = scale
        placeholderEntity.name = "\(type.rawValue)_\(modelId.uuidString)"
        placeholderEntity.orientation = rotation
        
        placeholderEntity.setupAsModelEntity(
            modelType: type,
            modelId: modelId,
            userId: userId
        )
        
        if isRootEntityInitialized {
            rootEntity.addChild(placeholderEntity)
            print("✅【占位符已添加到场景】: \(placeholderEntity.name)")
        }
        
        // ✅ 创建PlacedModel时包含用户信息
        let model = PlacedModel(
            id: modelId,
            entity: placeholderEntity,
            originalScale: scale,
            originalPosition: position,
            type: type,
            color: finalColor,
            size: adjustedSize,
            opacity: opacity,
            userId: userId,
            text: text,
            username: username,      // ✅ 传递用户名
            avatarUrl: avatarUrl     // ✅ 传递头像
        )
        
        Task {
            await loadUSDZModelWithAttributes(
                for: model,
                targetPosition: position,
                targetScale: scale,
                targetRotation: rotation,
                type: type,
                size: adjustedSize,
                opacity: opacity,
                color: finalColor,
                text: text
            )
        }
        
        return model
    }
    // MARK: - 创建简单模型
    func createModelAt(
        position: SIMD3<Float>,
        type: ModelType,
        color: Color,
        size: Float,
        opacity: Float,
        userId: Int64?,
        text: String? = nil
    ) -> PlacedModel {
        print("【开始创建模型】类型: \(type.rawValue), 位置: \(position), 用户: \(userId ?? -1)")
        
        let adjustedSize = max(size, 0.05)
        let modelId = UUID()
        
        let finalColor = ModelRegistry.shared.allowsColorCustomization(for: type) ? color : Color.brown
        print("🎨 创建模型颜色: 原始=\(color), 最终=\(finalColor), 类型=\(type.rawValue)")
        
        let placeholderEntity = createLoadingPlaceholder(size: adjustedSize)
        
        placeholderEntity.position = position
        placeholderEntity.name = "\(type.rawValue)_\(modelId.uuidString)"
        
        placeholderEntity.setupAsModelEntity(
            modelType: type,
            modelId: modelId,
            userId: userId
        )
        
        if isRootEntityInitialized {
            rootEntity.addChild(placeholderEntity)
            print("✅【占位符已添加到场景】: \(placeholderEntity.name)")
        } else {
            print("⚠️【根实体未初始化，延迟添加占位符】")
        }
        
        let model = PlacedModel(
            id: modelId,
            entity: placeholderEntity,
            originalScale: SIMD3<Float>(repeating: 1.0),
            originalPosition: position,
            type: type,
            color: finalColor,
            size: adjustedSize,
            opacity: opacity,
            userId: userId,
            text: text
        )
        
        Task {
            await loadUSDZModelAsync(
                for: model,
                type: type,
                size: adjustedSize,
                opacity: opacity,
                color: finalColor,
                text: text
            )
        }
        
        return model
    }
    
    // MARK: - 异步加载USDZ模型
    func loadUSDZModelAsync(
        for model: PlacedModel,
        type: ModelType,
        size: Float,
        opacity: Float,
        color: Color,
        text: String? = nil
    ) async {
        let currentRotation = model.entity.orientation
        
        await loadUSDZModelWithAttributes(
            for: model,
            targetPosition: model.entity.position,
            targetScale: model.entity.scale,
            targetRotation: currentRotation,
            type: type,
            size: size,
            opacity: opacity,
            color: color,
            text: text
        )
    }
    
    // MARK: - 加载USDZ模型并保持属性
    func loadUSDZModelWithAttributes(
        for model: PlacedModel,
        targetPosition: SIMD3<Float>,
        targetScale: SIMD3<Float>,
        targetRotation: simd_quatf,
        type: ModelType,
        size: Float,
        opacity: Float,
        color: Color,
        text: String? = nil
    ) async {
        let fileName = ModelRegistry.shared.getUSDZFileName(for: type)
        print("🔧【开始加载USDZ文件并保持属性】: \(fileName)")
        
        do {
            let loadedEntity = try await Entity(named: fileName)
            
            await MainActor.run {
                let originalName = model.entity.name
                
                print("🔥【应用完整的目标属性】位置: \(targetPosition), 缩放: \(targetScale), 旋转: \(targetRotation)")
                
                guard let originalModelComponent = model.entity.modelComponent else {
                    print("❌【无法获取原始模型组件】")
                    return
                }
                
                let originalParent: Entity? = model.entity.parent
                
                loadedEntity.name = originalName
                loadedEntity.position = targetPosition
                loadedEntity.scale = targetScale
                loadedEntity.orientation = targetRotation
                
                loadedEntity.setupAsModelEntity(
                    modelType: originalModelComponent.modelType,
                    modelId: originalModelComponent.modelId,
                    userId: originalModelComponent.userId
                )
                
                applyMaterialProperties(to: loadedEntity, opacity: opacity, color: color)
                
                if ModelRegistry.shared.supportsTextInput(for: type), let text = text {
                    addTextToSignModel(loadedEntity, text: text)
                }
                
                if let parent = originalParent {
                    model.entity.removeFromParent()
                    parent.addChild(loadedEntity)
                    print("✅【USDZ模型已替换占位符】: \(originalName)")
                } else {
                    print("⚠️【无父实体，无法替换占位符】")
                }
                
                if let index = placedModels.firstIndex(where: { $0.id == model.id }) {
                    let updatedModel = PlacedModel(
                        id: model.id,
                        entity: loadedEntity,
                        originalScale: model.originalScale,
                        originalPosition: model.originalPosition,
                        type: model.type,
                        color: model.color,
                        size: model.size,
                        opacity: model.opacity,
                        userId: model.userId,
                        text: model.text,
                        username: model.username,
                        avatarUrl: model.avatarUrl
                    )
                    
                    placedModels[index] = updatedModel
                }
            }
            
        } catch {
            print("❌【USDZ模型加载失败】: \(fileName) - \(error)")
            await MainActor.run {
                model.entity.position = targetPosition
                model.entity.scale = targetScale
                model.entity.orientation = targetRotation
            }
        }
    }
    
    // MARK: - 应用材质属性
    func applyMaterialProperties(to entity: Entity, opacity: Float, color: Color) {
        if let modelComponent = entity.modelComponent {
            let modelType = modelComponent.modelType
            
            // 🔥 ChatBubble特殊处理：强制蓝色+70%不透明度
            if modelType == .chatBubble {
                print("💬【ChatBubble强制蓝色材质】70%不透明度")
                let chatBubbleColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.7)
                applyMaterialRecursive(entity, color: chatBubbleColor)
                return
            }
            
            // ✅ 关键修复：检查模型是否允许颜色自定义
            if !ModelRegistry.shared.allowsColorCustomization(for: modelType) {
                print("🎨【\(modelType.displayName)保持原始材质】不允许颜色自定义")
                applyOpacityOnly(to: entity, opacity: opacity)
                return
            }
        }
        
        // 其他模型应用用户指定的颜色
        let targetUIColor = UIColor(color).withAlphaComponent(CGFloat(opacity))
        applyMaterialRecursive(entity, color: targetUIColor)
        print("🎨 应用颜色到模型: \(color)")
    }
    
    // MARK: - 仅应用透明度
    func applyOpacityOnly(to entity: Entity, opacity: Float) {
        if var modelComponent = entity.components[ModelComponent.self] {
            var newMaterials: [RealityFoundation.Material] = []
            
            for material in modelComponent.materials {
                if var unlitMaterial = material as? UnlitMaterial {
                    unlitMaterial.color.tint = unlitMaterial.color.tint.withAlphaComponent(CGFloat(opacity))
                    newMaterials.append(unlitMaterial)
                } else if var simpleMaterial = material as? SimpleMaterial {
                    simpleMaterial.color.tint = simpleMaterial.color.tint.withAlphaComponent(CGFloat(opacity))
                    newMaterials.append(simpleMaterial)
                } else if var pbrMaterial = material as? PhysicallyBasedMaterial {
                    pbrMaterial.baseColor.tint = pbrMaterial.baseColor.tint.withAlphaComponent(CGFloat(opacity))
                    newMaterials.append(pbrMaterial)
                } else {
                    newMaterials.append(material)
                }
            }
            
            modelComponent.materials = newMaterials
            entity.components.set(modelComponent)
        }
        
        for child in entity.children {
            applyOpacityOnly(to: child, opacity: opacity)
        }
    }
    
    // MARK: - 递归应用材质
    func applyMaterialRecursive(_ entity: Entity, color: UIColor) {
        if entity.name == "signText" {
            print("⭐️ 跳过文本实体的颜色更改")
            return
        }
        
        if var modelComponent = entity.components[ModelComponent.self] {
            var newMaterials: [RealityFoundation.Material] = []
            
            for material in modelComponent.materials {
                if var unlitMaterial = material as? UnlitMaterial {
                    unlitMaterial.color.tint = color
                    newMaterials.append(unlitMaterial)
                } else if var simpleMaterial = material as? SimpleMaterial {
                    simpleMaterial.color.tint = color
                    simpleMaterial.metallic = 0.2
                    simpleMaterial.roughness = 0.8
                    newMaterials.append(simpleMaterial)
                } else if var pbrMaterial = material as? PhysicallyBasedMaterial {
                    pbrMaterial.baseColor.tint = color
                    pbrMaterial.metallic = 0.2
                    pbrMaterial.roughness = 0.8
                    
                    newMaterials.append(pbrMaterial)
                } else {
                    var newMaterial = SimpleMaterial()
                    newMaterial.color.tint = color
                    newMaterial.metallic = 0.2
                    newMaterial.roughness = 0.8
                    newMaterials.append(newMaterial)
                }
            }
            
            modelComponent.materials = newMaterials
            entity.components.set(modelComponent)
        }
        
        for child in entity.children {
            applyMaterialRecursive(child, color: color)
        }
    }
    
    // MARK: - 为Sign模型添加文字
    func addTextToSignModel(_ signEntity: Entity, text: String) {
        // 🔥 检测模型类型
        let isChatBubble = signEntity.modelComponent?.modelType == .chatBubble
        let modelTypeName = isChatBubble ? "ChatBubble" : "Sign"
        
        print("📝 强制更新\(modelTypeName)模型文字: \(text)")
        
        let existingTextEntities = signEntity.children.filter { $0.name == "signText" }
        for textEntity in existingTextEntities {
            print("🗑️ 移除旧的文字实体")
            textEntity.removeFromParent()
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("📄 文字为空，不添加文字实体")
            return
        }
        
        // 🔥 根据模型类型创建不同大小的文字
        let textEntity = createTextEntity(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            isChatBubble: isChatBubble
        )
        textEntity.name = "signText"
        
        // 🔥 根据模型类型调整位置 - 往下调整
        if isChatBubble {
            textEntity.position = SIMD3<Float>(0, -0.05, 0.02)  // ChatBubble往下移动
            print("💬【ChatBubble文字位置】往下调整")
        } else {
            textEntity.position = SIMD3<Float>(0, -0.10, 0.02)  // Sign进一步往下
            print("🪧【Sign文字位置】往下调整")
        }
        
        textEntity.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        
        signEntity.addChild(textEntity)
        
        print("✅ 新的文字已添加到\(modelTypeName)模型")
        print("   - 文字内容: \(text)")
        print("   - 文字实体名称: \(textEntity.name)")
        print("   - 文字实体位置: \(textEntity.position)")
        print("   - 实体子项数量: \(signEntity.children.count)")
        
        for (index, child) in signEntity.children.enumerated() {
            print("   - 子项\(index): \(child.name) at \(child.position)")
        }
    }
    
    // MARK: - 创建文字实体
    func createTextEntity(text: String, isChatBubble: Bool = false) -> ModelEntity {
        let modelType = isChatBubble ? "ChatBubble" : "Sign"
        print("📝 创建\(modelType)文字实体: \(text)")
        
        guard !text.isEmpty else {
            print("⚠️ 文字为空，返回空实体")
            return ModelEntity()
        }
        
        // 🔥 字体减小两号：ChatBubble从0.08改为0.06，Sign从0.03改为0.02
        let fontSize: Float = isChatBubble ? 0.06 : 0.02
        print("📏 字体大小: \(fontSize)米 (\(Int(fontSize * 100))厘米)")
        
        let font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: isChatBubble ? .bold : .medium)
        
        // 🔥 ChatBubble使用更大的容器
        let containerWidth: CGFloat = isChatBubble ? 2.0 : 1.0
        let containerHeight: CGFloat = isChatBubble ? 0.6 : 0.3
        let containerFrame = CGRect(
            x: -containerWidth / 2,
            y: -containerHeight / 2,
            width: containerWidth,
            height: containerHeight
        )
        
        do {
            let textGeometry = MeshResource.generateText(
                text,
                extrusionDepth: isChatBubble ? 0.003 : 0.002,  // ChatBubble文字稍厚
                font: font,
                containerFrame: containerFrame,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            
            var textMaterial = SimpleMaterial()
            // 🔥 统一使用黑色字体，alpha为0.5
            textMaterial.color = .init(tint: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5))
            textMaterial.metallic = 0.0
            textMaterial.roughness = 0.9
            
            let textEntity = ModelEntity(mesh: textGeometry, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(0, isChatBubble ? 0 : -0.5, 0.001)
            
            print("✅ \(modelType)文字实体创建成功")
            print("   - 字体大小: \(fontSize)米")
            print("   - 容器尺寸: \(containerWidth) x \(containerHeight)")
            print("   - 文字颜色: 黑色 alpha 0.5")
            
            return textEntity
            
        } catch {
            print("❌ 创建文字几何体失败: \(error)")
            
            let placeholderEntity = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.03, 0.002]),
                materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
            )
            return placeholderEntity
        }
    }
}
