/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main view.
*/

// 导入 SwiftUI 框架，这是 Apple 的现代 UI 框架
import SwiftUI

// 定义一个名为 MainView 的结构体，遵循 View 协议
// 在 SwiftUI 中，所有的 UI 组件都需要遵循 View 协议
struct MainView: View {
    
    // 使用 @Environment 属性包装器获取系统环境值
    // openImmersiveSpace 是用于打开沉浸式空间的操作
    // 这通常用于 visionOS 应用中创建 AR/VR 体验
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    
    // 获取绘画配置对象
    @EnvironmentObject var paintingConfig: PaintingConfig
    
    // 控制各种设置面板的显示
    @State private var showAdvancedSettings = false
    @State private var showColorPicker = false
    
    // body 是 View 协议的必需属性
    // 它定义了这个视图的内容和布局
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                titleSection
                paintingControlSection
                brushSettingsSection
                Spacer(minLength: 20)
            }
            .padding()
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                selectedColor: Binding(
                    get: { Color(paintingConfig.brushConfig.color) },
                    set: { paintingConfig.brushConfig.color = UIColor($0) }
                )
            )
        }
        .onAppear {
            Task {
                await openImmersiveSpace(id: "PaintingScene")
            }
        }
    }
    
    // MARK: - 视图组件
    
    private var titleSection: some View {
        Text("3D 绘画空间")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    private var paintingControlSection: some View {
        VStack(spacing: 16) {
            Text("绘画控制")
                .font(.title2)
                .fontWeight(.semibold)
            
            paintingModeToggle
            clearButton
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var paintingModeToggle: some View {
        HStack {
            Text("自动绘画模式")
                .font(.headline)
            Spacer()
            Button(action: {
                paintingConfig.isAutoPaintingEnabled.toggle()
            }) {
                HStack {
                    Image(systemName: paintingConfig.isAutoPaintingEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(paintingConfig.isAutoPaintingEnabled ? .green : .gray)
                    Text(paintingConfig.isAutoPaintingEnabled ? "开启" : "关闭")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(paintingConfig.isAutoPaintingEnabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var clearButton: some View {
        Button(action: {
            paintingConfig.triggerClear()
        }) {
            HStack {
                Image(systemName: "trash")
                Text("清除所有绘画")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.red)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var brushSettingsSection: some View {
        VStack(spacing: 16) {
            Text("画笔设置")
                .font(.title2)
                .fontWeight(.semibold)
            
            brushTypeSelection
            brushModeSelection
            shaderTypeSelection
            colorSelection
            advancedSettingsToggle
            
            if showAdvancedSettings {
                advancedSettings
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var brushTypeSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("画笔类型")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                ForEach(BrushType.allCases, id: \.self) { brushType in
                    brushTypeButton(for: brushType)
                }
            }
        }
    }
    
    private func brushTypeButton(for brushType: BrushType) -> some View {
        Button(action: {
            paintingConfig.brushConfig.type = brushType
        }) {
            VStack(spacing: 4) {
                Image(systemName: brushTypeIcon(for: brushType))
                    .font(.title2)
                Text(brushType.displayName)
                    .font(.caption)
            }
            .foregroundColor(paintingConfig.brushConfig.type == brushType ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                paintingConfig.brushConfig.type == brushType 
                ? Color.blue : Color.gray.opacity(0.2)
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func brushTypeIcon(for brushType: BrushType) -> String {
        switch brushType {
        case .cylindrical:
            return "cylinder"
        case .cubic:
            return "cube"
        case .prismatic:
            return "square.3.stack.3d"
        }
    }
    
    private var brushModeSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("绘画模式")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                ForEach(BrushMode.allCases, id: \.self) { mode in
                    brushModeButton(for: mode)
                }
            }
        }
    }
    
    private func brushModeButton(for mode: BrushMode) -> some View {
        Button(action: {
            paintingConfig.brushConfig.mode = mode
        }) {
            HStack(spacing: 6) {
                Image(systemName: mode == .continuous ? "minus" : "ellipsis")
                    .font(.caption)
                Text(mode.displayName)
                    .font(.subheadline)
            }
            .foregroundColor(paintingConfig.brushConfig.mode == mode ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                paintingConfig.brushConfig.mode == mode 
                ? Color.green : Color.gray.opacity(0.2)
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var shaderTypeSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("材质类型")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(ShaderType.allCases, id: \.self) { shader in
                    shaderButton(for: shader)
                }
            }
        }
    }
    
    private func shaderButton(for shader: ShaderType) -> some View {
        Button(action: {
            paintingConfig.brushConfig.shader = shader
        }) {
            Text(shader.displayName)
                .font(.subheadline)
                .foregroundColor(paintingConfig.brushConfig.shader == shader ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    paintingConfig.brushConfig.shader == shader 
                    ? Color.purple : Color.gray.opacity(0.2)
                )
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var colorSelection: some View {
        HStack {
            Text("画笔颜色")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Button(action: {
                showColorPicker.toggle()
            }) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(paintingConfig.brushConfig.color))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: 1)
                        )
                    Text("选择颜色")
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var advancedSettingsToggle: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showAdvancedSettings.toggle()
            }
        }) {
            HStack {
                Text("高级设置")
                Spacer()
                Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var advancedSettings: some View {
        VStack(spacing: 12) {
            brushSizeSlider
            
            if paintingConfig.brushConfig.mode == .dotted {
                dottedSpacingSlider
            }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .slide))
    }
    
    private var brushSizeSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("画笔大小: \(String(format: "%.3f", paintingConfig.brushConfig.size))")
                .font(.caption)
                .fontWeight(.medium)
            
            Slider(
                value: Binding(
                    get: { paintingConfig.brushConfig.size },
                    set: { paintingConfig.brushConfig.size = $0 }
                ),
                in: 0.005...0.05,
                step: 0.001
            )
            .accentColor(.blue)
        }
    }
    
    private var dottedSpacingSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("断续间距: \(String(format: "%.3f", paintingConfig.brushConfig.dottedSpacing))")
                .font(.caption)
                .fontWeight(.medium)
            
            Slider(
                value: Binding(
                    get: { paintingConfig.brushConfig.dottedSpacing },
                    set: { paintingConfig.brushConfig.dottedSpacing = $0 }
                ),
                in: 0.01...0.1,
                step: 0.005
            )
            .accentColor(.green)
        }
    }
}

// #Preview 是 SwiftUI 的预览功能
// 允许您在 Xcode 中实时预览视图的外观
// windowStyle: .automatic 表示使用系统默认的窗口样式
#Preview(windowStyle: .automatic) {
    MainView()
}
