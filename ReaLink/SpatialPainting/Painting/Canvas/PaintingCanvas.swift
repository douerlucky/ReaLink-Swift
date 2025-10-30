import SwiftUI
import RealityKit

// 🔥 标注为 MainActor，确保对 RealityKit 实体的操作在主线程
@MainActor
class PaintingCanvas {
/// 绘画画布的主根实体（所有 3D 对象的容器）
let root = Entity()

/// 用户当前正在绘制的笔画
var currentStroke: AdvancedStroke?

/// 存储所有已完成的笔画实体，用于擦除功能
private var finishedStrokeEntities: [Entity] = []

/// 【新增】存储完整的笔画数据，用于云端保存
private var finishedStrokeData: [AdvancedStroke] = []

/// 碰撞盒在正方向上延伸的距离（一个很大的数）
let big: Float = 1E2

/// 碰撞盒在负方向上延伸的距离（一个很小的数）
let small: Float = 1E-2

// 初始化函数：设置绘画画布，创建6个相互堆叠的碰撞盒
init() {
    // 添加6个碰撞盒，形成一个 3D 空间的边界
    root.addChild(addBox(size: [big, big, small], position: [0, 0, -0.5 * big]))
    root.addChild(addBox(size: [big, big, small], position: [0, 0, +0.5 * big]))
    root.addChild(addBox(size: [big, small, big], position: [0, -0.5 * big, 0]))
    root.addChild(addBox(size: [big, small, big], position: [0, +0.5 * big, 0]))
    root.addChild(addBox(size: [small, big, big], position: [-0.5 * big, 0, 0]))
    root.addChild(addBox(size: [small, big, big], position: [+0.5 * big, 0, 0]))
}

/// 创建一个碰撞盒，用于接收用户的拖拽手势输入
private func addBox(size: SIMD3<Float>, position: SIMD3<Float>) -> Entity {
    let box = Entity()
    box.components.set(InputTargetComponent())
    box.components.set(CollisionComponent(shapes: [.generateBox(size: size)], isStatic: true))
    box.position = position
    return box
}

/// 🔥 添加点时传入用户ID
func addPoint(_ position: SIMD3<Float>, brushConfig: BrushConfig, userId: Int64? = nil) {
    let threshold: Float = 1E-9

    // 如果当前没有笔画，就开始新的笔画
    if currentStroke == nil {
        // 🔥 关键：创建笔画时传递用户ID
        currentStroke = AdvancedStroke(brushConfig: brushConfig, userId: userId)
        root.addChild(currentStroke!.entity)
        print("🎨 开始新笔画 - 用户ID: \(userId ?? -1)")
    }

    // 检查距离阈值
    if let previousPoint = currentStroke?.points.last,
       length(position - previousPoint) < threshold {
        return
    }

    // 将当前位置添加到笔画的点数组中
    currentStroke?.points.append(position)
    currentStroke?.updateMesh()
}

/// 当拖拽手势结束时清除笔画
func finishStroke() {
    if var stroke = currentStroke {
        // 触发最终的网格更新操作
        stroke.updateMesh()

        // 同时保存实体和完整数据
        finishedStrokeEntities.append(stroke.entity)
        finishedStrokeData.append(stroke)

        // 清除当前笔画（准备下一次绘制）
        currentStroke = nil
        
        print("🎨 完成笔画 - 用户ID: \(stroke.userId ?? -1), 当前总笔画数: \(finishedStrokeData.count)")
    }
}

/// 🔥 撤回功能 - 只删除当前用户的最后一个笔画；优先撤回“正在绘制”的当前笔画
func undoLastStroke(userId: Int64?) -> Bool {
    guard let userId = userId else {
        print("⚠️ 撤回失败：未提供用户ID")
        return false
    }
    
    // 先撤回当前正在绘制的笔画
    if let cs = currentStroke, cs.userId == userId {
        cs.entity.removeFromParent()
        currentStroke = nil
        print("📝 已撤回当前用户的正在绘制笔画")
        return true
    }
    
    // 🔥 从后往前找到当前用户的最后一个已完成笔画
    var foundIndex: Int? = nil
    for (index, stroke) in finishedStrokeData.enumerated().reversed() {
        if stroke.userId == userId {
            foundIndex = index
            break
        }
    }
    
    guard let indexToRemove = foundIndex else {
        print("📝 没有可撤回的笔画（用户ID: \(userId)）")
        return false
    }
    
    // 移除实体
    let entity = finishedStrokeEntities[indexToRemove]
    entity.removeFromParent()
    
    // 从数组中移除
    finishedStrokeEntities.remove(at: indexToRemove)
    finishedStrokeData.remove(at: indexToRemove)
    
    print("📝 已撤回用户 \(userId) 的最后一个笔画，剩余笔画数: \(finishedStrokeData.count)")

    return true
}

/// 🔥 清除功能 - 只清除当前用户的所有笔画
func clearUserStrokes(userId: Int64?) {
    guard let userId = userId else {
        print("⚠️ 清空失败：未提供用户ID")
        return
    }
    
    print("🎨 开始清空用户 \(userId) 的画布...")
    
    // 直接清理当前正在绘制的笔画（如果是当前用户的）
    if let cs = currentStroke, cs.userId == userId {
        cs.entity.removeFromParent()
        currentStroke = nil
    }
    
    // 🔥 找出并移除当前用户的所有已完成笔画
    var indicesToRemove: [Int] = []
    for (index, stroke) in finishedStrokeData.enumerated() {
        if stroke.userId == userId {
            indicesToRemove.append(index)
        }
    }
    
    // 从后往前删除，避免索引变化问题
    for index in indicesToRemove.reversed() {
        let entity = finishedStrokeEntities[index]
        entity.removeFromParent()
        finishedStrokeEntities.remove(at: index)
        finishedStrokeData.remove(at: index)
    }
    
    print("🎨 用户 \(userId) 的画布已清空，删除了 \(indicesToRemove.count) 个笔画")
    print("   - 剩余总笔画数: \(finishedStrokeData.count)")
}

/// 清除所有绘画内容（管理员功能）
func clearAllStrokes() {
    print("🎨 开始清空所有用户的画布...")
    
    // 安全地清除当前笔画
    if let cs = currentStroke {
        cs.entity.removeFromParent()
        currentStroke = nil
    }
    
    // 移除所有已完成的笔画
    for strokeEntity in finishedStrokeEntities {
        strokeEntity.removeFromParent()
    }
    finishedStrokeEntities.removeAll()
    finishedStrokeData.removeAll()
    
    // 移除所有子实体（除了碰撞盒子）
    let children = root.children
    for child in children {
        if child.components.has(ModelComponent.self) {
            child.removeFromParent()
        }
    }
    
    print("🎨 所有用户的画布已清空")
}

/// 获取当前已绘制的笔画数量
func getStrokeCount() -> Int {
    return finishedStrokeData.count + (currentStroke != nil ? 1 : 0)
}

/// 🔥 新增：获取当前用户的笔画数量
func getUserStrokeCount(userId: Int64?) -> Int {
    guard let userId = userId else { return 0 }
    let userStrokes = finishedStrokeData.filter { $0.userId == userId }.count
    let currentIsUser = (currentStroke?.userId == userId) ? 1 : 0
    return userStrokes + currentIsUser
}

/// 检查是否有笔画可以擦除
func hasStrokesToErase() -> Bool {
    return !finishedStrokeData.isEmpty
}

/// 🔥 新增：检查当前用户是否有笔画可以擦除
func userHasStrokesToErase(userId: Int64?) -> Bool {
    guard let userId = userId else { return false }
    return finishedStrokeData.contains { $0.userId == userId } || (currentStroke?.userId == userId)
}
}

// MARK: - 云端操作扩展
extension PaintingCanvas {
/// 保存所有笔画到云端（只保存当前用户）

    func savePaintingToCloud(locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async throws {
        print("🎨 开始保存画作到云端...")
        print("   📍 locationId: \(locationId ?? -1), questionId: \(questionId ?? -1), userId: \(userId ?? -1)")
        
        // 🔥 检查userId是否有效
        guard let validUserId = userId, validUserId > 0 else {
            print("❌ 保存失败：无效的用户ID")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": false, "message": "保存失败：无效的用户ID"]
                )
            }
            return
        }
        
        // 🔥 只保存当前用户的笔画
        var strokesData: [SerializableStroke] = []
        
        // 从保存的笔画数据中筛选当前用户的笔画
        for stroke in finishedStrokeData {
            if stroke.userId == validUserId {
                let serializableStroke = SerializableStroke(from: stroke)
                strokesData.append(serializableStroke)
            }
        }
        
        // 如果当前还有正在绘制的笔画，且是当前用户的，也包含进去
        if let currentStroke = currentStroke, currentStroke.userId == validUserId {
            let serializableStroke = SerializableStroke(from: currentStroke)
            strokesData.append(serializableStroke)
        }
        
        print("   📦 找到 \(strokesData.count) 个笔画属于用户 \(validUserId)")
        print("   📊 总笔画数: \(finishedStrokeData.count + (currentStroke != nil ? 1 : 0))")
        
        // 🔥 修复：改进空画布的处理逻辑
        guard !strokesData.isEmpty else {
            print("ℹ️ 当前画布为空，没有笔画数据")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: [
                        "success": true, // 🔥 改为 success: true，表示操作完成
                        "message": "画布为空，无需保存" // 🔥 更友好的提示
                    ]
                )
            }
            return
        }
        
        // 创建空间画作数据
        let paintingData = SpatialPaintingData(
            strokes: strokesData,
            locationId: locationId,
            questionId: questionId,
            userId: userId
        )
        
        do {
            let jsonData = try JSONEncoder().encode(paintingData)
            
            print("🎨 准备上传用户 \(userId ?? -1) 的 \(strokesData.count) 个笔画到云端")
            
            try await NetworkManager.shared.uploadPaintingData(jsonData, locationId: locationId, questionId: questionId, userId: userId)
            
            print("🎨 空间画作已保存到云端")
            
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": true, "message": "画作保存成功"]
                )
            }
            
        } catch {
            print("🎨 保存到云端失败: \(error.localizedDescription)")
            
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": false, "message": "保存失败: \(error.localizedDescription)"]
                )
            }
        }
    }
/// 从云端加载画作数据
func loadPaintingFromCloud(locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async throws {
    print("🎨 开始从云端加载画作...")
    
    do {
        let paintingData = try await NetworkManager.shared.downloadPaintingData(locationId: locationId, questionId: questionId, userId: userId)
        
        print("🎨 获取到 \(paintingData.strokes.count) 个笔画数据，开始恢复...")
        
        await MainActor.run {
            // 🔥 加载所有用户的笔画时，先清空画布，避免重复加载
            if userId == nil {
                print("🎨 加载所有用户的笔画，先清空画布")
                clearAllStrokes()
            }
            
            print("🎨 开始恢复笔画...")
            
            for (index, serializableStroke) in paintingData.strokes.enumerated() {
                print("🎨 恢复第 \(index + 1) 个笔画，包含 \(serializableStroke.points.count) 个点")
                
                var advancedStroke = serializableStroke.toAdvancedStroke()
                
                // 兜底：如果该条笔画没有 userId，而本次请求是“按某个 userId 加载”，则补上
                if advancedStroke.userId == nil, let reqUserId = userId {
                    advancedStroke.userId = reqUserId
                }
                
                guard !advancedStroke.points.isEmpty && advancedStroke.points.count >= 2 else {
                    print("⚠️ 跳过无效笔画：点数不足或为空")
                    continue
                }
                
                let validPoints = advancedStroke.points.filter { point in
                    !point.x.isNaN && !point.y.isNaN && !point.z.isNaN &&
                    point.x.isFinite && point.y.isFinite && point.z.isFinite
                }
                
                guard validPoints.count >= 2 else {
                    print("⚠️ 跳过笔画：有效点数不足 (\(validPoints.count)/\(advancedStroke.points.count))")
                    continue
                }
                
                if validPoints.count != advancedStroke.points.count {
                    print("🔧 过滤无效点：\(advancedStroke.points.count) -> \(validPoints.count)")
                    advancedStroke.points = validPoints
                }
                
                do {
                    print("🎨 为第 \(index + 1) 个笔画生成网格...")
                    advancedStroke.updateMesh()
                    
                    guard advancedStroke.entity.components.has(ModelComponent.self) else {
                        print("⚠️ 跳过笔画：网格生成失败")
                        continue
                    }
                    
                    root.addChild(advancedStroke.entity)
                    finishedStrokeEntities.append(advancedStroke.entity)
                    finishedStrokeData.append(advancedStroke)
                    
                    print("✅ 第 \(index + 1) 个笔画恢复成功 - 用户ID: \(advancedStroke.userId ?? -1)")
                    
                } catch {
                    print("❌ 恢复第 \(index + 1) 个笔画时出错: \(error.localizedDescription)")
                    continue
                }
            }
            
            print("🎨 已从云端恢复 \(finishedStrokeData.count) 个笔画")
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudOperationResult"),
                object: nil,
                userInfo: ["success": true, "message": "画作加载成功"]
            )
        }
        
    } catch {
        print("🎨 从云端加载失败: \(error.localizedDescription)")
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudOperationResult"),
                object: nil,
                userInfo: ["success": false, "message": "加载失败: \(error.localizedDescription)"]
            )
        }
    }
}

/// 检查云端画作是否存在
func checkCloudPaintingExists(locationId: Int64? = nil, questionId: Int64? = nil, userId: Int64? = nil) async -> Bool {
    print("🎨 检查云端画作存在性")
    
    do {
        let exists = try await NetworkManager.shared.checkPaintingExists(
            locationId: locationId,
            questionId: questionId,
            userId: userId
        )
        
        print("🎨 云端画作存在性检查结果: \(exists)")
        return exists
        
    } catch {
        print("🎨 检查云端画作存在性失败: \(error.localizedDescription)")
        return false
    }
}
}
