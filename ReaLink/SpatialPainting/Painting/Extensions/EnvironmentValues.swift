/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Custom environment values for painting configuration.
*/

import SwiftUI

// 自定义环境值键，用于传递绘画模式状态
private struct AutoPaintingEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

// 扩展EnvironmentValues以包含自动绘画状态
extension EnvironmentValues {
    var isAutoPaintingEnabled: Bool {
        get { self[AutoPaintingEnabledKey.self] }
        set { self[AutoPaintingEnabledKey.self] = newValue }
    }
}
