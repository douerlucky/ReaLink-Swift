//
//  Models.swift
//  ReaLink
//
//  数据模型定义
//

import RealityKit
import SwiftUI

// MARK: - 放置的模型

struct PlacedModel: Identifiable
{
    let id: UUID
    let entity: Entity
    let originalScale: SIMD3<Float>
    let originalPosition: SIMD3<Float>
    let type: ModelType
    let color: Color
    let size: Float
    let opacity: Float
    let userId: Int64?
    let text: String?

    // ✅ 新增：用户信息
    var username: String?
    var avatarUrl: String?

    // 检查用户是否可以操作此模型
    func canUserManipulate(currentUserId: Int64?) -> Bool
    {
        guard let currentUserId = currentUserId,
              let modelUserId = userId
        else
        {
            return false
        }
        return currentUserId == modelUserId
    }

    // 检查是否支持文本输入
    func supportsTextInput() -> Bool
    {
        return ModelRegistry.shared.supportsTextInput(for: type)
    }

    // 检查是否允许颜色自定义
    func allowsColorCustomization() -> Bool
    {
        return ModelRegistry.shared.allowsColorCustomization(for: type)
    }

    // ✅ 新增：获取显示用的用户名
    func getDisplayUsername() -> String
       {
           if let username = username, !username.isEmpty
           {
               return username
           }
           return "用户 \(userId ?? 0)"
       }
}

// MARK: - 模型操作记录

struct ModelOperationRecord
{
    let id: UUID
    let operationType: OperationType
    let modelData: ModelSnapshot
    let timestamp: Date

    enum OperationType
    {
        case add
        case move(from: SIMD3<Float>, to: SIMD3<Float>)
        case scale(from: SIMD3<Float>, to: SIMD3<Float>)
        case remove
    }
}

extension ModelOperationRecord.OperationType
{
    var isMove: Bool
    {
        if case .move = self { return true }
        return false
    }

    var isScale: Bool
    {
        if case .scale = self { return true }
        return false
    }
}

// MARK: - 模型快照

struct ModelSnapshot
{
    let modelId: UUID
    let modelType: ModelType
    let position: SIMD3<Float>
    let scale: SIMD3<Float>
    let color: Color
    let userId: Int64?
}
