/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Shared painting configuration manager.
*/

import SwiftUI

// 绘画配置管理器，使用ObservableObject来在视图间共享状态
@MainActor
class PaintingConfig: ObservableObject {
    // 自动绘画模式开关状态
    @Published var isAutoPaintingEnabled: Bool = false
    
    // 清除绘画的触发器，通过改变这个值来触发清除操作
    @Published var clearTrigger: Bool = false
    
    // 画笔配置
    @Published var brushConfig: BrushConfig = BrushConfig()
    
    // 触发清除绘画的方法
    func triggerClear() {
        clearTrigger.toggle()
    }
}
