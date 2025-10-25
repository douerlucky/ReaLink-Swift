//
//  QuestionManager.swift
//  ReaLink
//
//  3D视图问题管理
//

import RealityKit
import SwiftUI

extension BasicPanoramaView {
    
    // MARK: - 加载3D视图问题
    func load3DViewQuestions() async {
        isLoadingQuestions = true
        
        do {
            let locationId: Int64 = getCurrentLocationId()
            
            let view3DResponse = try await NetworkManager.shared.get3DViewIdByLocation(locationId: locationId)
            
            if view3DResponse.success, let real3DViewId = view3DResponse.real3DViewId {
                current3DViewId = real3DViewId
                
                let questionsResponse = try await NetworkManager.shared.get3DViewQuestions(real3DViewId: real3DViewId)
                
                await MainActor.run {
                    questionsInSpace = questionsResponse.questions
                    isLoadingQuestions = false
                    print("🔥【加载问题数据完成】: \(questionsInSpace.count) 个3D视图问题")
                    
                    Task { @MainActor in
                        await self.addQuestionSpheresToScene()
                    }
                }
                
            } else {
                await MainActor.run {
                    questionsInSpace = []
                    isLoadingQuestions = false
                    current3DViewId = nil
                    print("🔭【当前位置没有3D视图数据】")
                }
            }
            
        } catch {
            await MainActor.run {
                questionsInSpace = []
                isLoadingQuestions = false
                current3DViewId = nil
                print("❌【加载3D视图问题失败】: \(error)")
            }
        }
    }
    
    func getCurrentLocationId() -> Int64 {
        let currentTitle = vrManager.currentLocationTitle
        
        switch currentTitle {
        case "华中农业大学博物馆":
            return 1
        case "华中农业大学梧桐广场", "华中农业大学梧桐步行街":
            return 2
        default:
            return 2
        }
    }
    
    // MARK: - 添加问题球体到场景
    @MainActor
    func addQuestionSpheresToScene() {
        guard isRootEntityInitialized else {
            print("⚠️【根实体未初始化，延迟添加问题圆球】")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task { @MainActor in
                    await self.addQuestionSpheresToScene()
                }
            }
            return
        }
        
        let existingQuestionSpheres = rootEntity.children.filter { $0.name.starts(with: "questionSphere_") }
        for sphere in existingQuestionSpheres {
            sphere.removeFromParent()
            print("🗑️【移除旧问题圆球】: \(sphere.name)")
        }
        
        for (index, question) in questionsInSpace.enumerated() {
            let questionSphere = createQuestionSphere(for: question, index: index)
            rootEntity.addChild(questionSphere)
            print("✅【添加问题圆球到场景】: \(questionSphere.name) at \(questionSphere.position)")
        }
        
        print("🟡【问题圆球添加完成】: 总数 \(questionsInSpace.count)")
    }
    
    func createQuestionSphere(for question: QuestionWith3DPosition, index: Int) -> Entity {
        let brightOrange = UnlitMaterial(color: .systemOrange)
        
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.1),
            materials: [brightOrange]
        )
        
        sphere.position = question.position.simd3
        sphere.name = "questionSphere_\(question.id)"
        
        sphere.components.set(InputTargetComponent(allowedInputTypes: [.indirect, .direct]))
        sphere.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)]))
        
        let highlightStyle = HoverEffectComponent.HighlightHoverEffectStyle(color: .systemBlue, strength: 2)
        let hoverEffect = HoverEffectComponent(.highlight(highlightStyle))
        sphere.components.set(hoverEffect)
        
        print("✅【创建问题球体】: \(sphere.name)")
        
        return sphere
    }
    
    // MARK: - 问题球体点击处理
    func handleQuestionSphereTap(_ entityName: String) {
        print("🎯【开始处理问题球体点击】: \(entityName)")
        print("📋【当前窗口状态】isRealityWindowOpen = \(windowStateManager.isRealityWindowOpen)")
        
        if windowStateManager.isRealityWindowOpen {
            print("⚠️【RealityWindow 已打开，忽略所有问题球点击】")
            return
        }
        
        let questionIdString = entityName.replacingOccurrences(of: "questionSphere_", with: "")
        guard let questionId = Int64(questionIdString) else {
            print("❌【无法解析问题ID】: \(questionIdString)")
            return
        }
        
        guard let question = questionsInSpace.first(where: { $0.id == questionId }) else {
            print("❌【未找到对应的问题】: ID=\(questionId)")
            return
        }
        
        openQuestionWindow(question: question, questionId: questionId)
    }
    
    func openQuestionWindow(question: QuestionWith3DPosition, questionId: Int64) {
        print("✅【找到问题】: \(question.title)")
        
        selectedQuestionId = questionId
        hideOtherQuestionSpheres = true
        
        Task { @MainActor in
            await animateQuestionSpheresVisibility()
        }
        
        let convertedQuestion = Question(
            id: question.id,
            locationID: question.locationId,
            userID: question.userId,
            actualPlace: question.actualPlace,
            title: question.title,
            content: question.content,
            replyCount: question.replyCount,
            status: question.status,
            createdAt: question.createdAt,
            updatedAt: question.updatedAt,
            username: question.username,
            avatarUrl: question.avatarUrl
        )
        
        targetQuesionManager.updateQuestion(question: convertedQuestion)
        print("✅【已更新目标问题管理器】")
        
        windowStateManager.isRealityWindowOpen = true
        
        openWindow(id: "RealityWindow")
        print("✅【已发送打开 RealityWindow 指令】")
    }
    
    // MARK: - 问题球体可见性动画
    @MainActor
    func animateQuestionSpheresVisibility() async {
        let questionSpheres = rootEntity.children.filter { $0.name.starts(with: "questionSphere_") }
        
        print("🎬 开始问题球可见性动画,总数: \(questionSpheres.count)")
        print("🎬 hideOtherQuestionSpheres = \(hideOtherQuestionSpheres)")
        print("🎬 selectedQuestionId = \(selectedQuestionId ?? -1)")
        
        for sphere in questionSpheres {
            let sphereIdString = sphere.name.replacingOccurrences(of: "questionSphere_", with: "")
            guard let sphereId = Int64(sphereIdString) else { continue }
            
            let shouldBeVisible = hideOtherQuestionSpheres ? (sphereId == selectedQuestionId) : true
            
            if shouldBeVisible {
                sphere.isEnabled = true
                
                var transform = sphere.transform
                transform.scale = SIMD3<Float>(repeating: 1.0)
                sphere.transform = transform
                
                updateSphereOpacity(sphere, opacity: 1.0)
                
                sphere.components.set(InputTargetComponent(allowedInputTypes: [.indirect, .direct]))
                sphere.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)]))
                
                let highlightStyle = HoverEffectComponent.HighlightHoverEffectStyle(color: .systemBlue, strength: 2)
                let hoverEffect = HoverEffectComponent(.highlight(highlightStyle))
                sphere.components.set(hoverEffect)
                
                print("✅ 显示问题球并恢复交互: \(sphere.name)")
            } else {
                sphere.isEnabled = false
                updateSphereOpacity(sphere, opacity: 0.1)
                
                print("⚪️ 隐藏问题球: \(sphere.name)")
            }
        }
    }
    
    func updateSphereOpacity(_ entity: Entity, opacity: Float) {
        guard var modelComponent = entity.components[ModelComponent.self] else { return }
        
        var newMaterials: [RealityFoundation.Material] = []
        for material in modelComponent.materials {
            if var unlitMaterial = material as? UnlitMaterial {
                unlitMaterial.color.tint = unlitMaterial.color.tint.withAlphaComponent(CGFloat(opacity))
                newMaterials.append(unlitMaterial)
            } else if var simpleMaterial = material as? SimpleMaterial {
                simpleMaterial.color.tint = simpleMaterial.color.tint.withAlphaComponent(CGFloat(opacity))
                newMaterials.append(simpleMaterial)
            } else {
                newMaterials.append(material)
            }
        }
        
        modelComponent.materials = newMaterials
        entity.components.set(modelComponent)
    }
}
