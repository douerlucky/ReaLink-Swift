//
//  ModelGestureHandler.swift
//  ReaLink
//
//  Created by Assistant on 2025/8/20.
//

import SwiftUI
import RealityKit
import ARKit

// MARK: - 简化的手势处理类
class ModelGestureHandler: ObservableObject {
    @Published var selectedModel: PlacedModel?
    
    // 处理模型选择
    func selectModel(_ model: PlacedModel) {
        selectedModel = model
        print("选中模型: \(model.id)")
    }
    
    // 取消选择
    func deselectModel() {
        selectedModel = nil
        print("取消选中模型")
    }
}
