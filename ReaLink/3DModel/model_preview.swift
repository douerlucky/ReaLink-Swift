//
//  model_preview.swift - 修复版本
//  ReaLink
//
//  修复Model3D预览中USDZ模型显示问题

import Foundation
import RealityKit
import SwiftUI

// MARK: - 模型类型选择视图
struct ModelTypeSelectionView: View {
    @Binding var selectedModelType: ModelType
    @State private var showModelPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模型类型")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: { showModelPicker = true }) {
                HStack {
                    Image(systemName: ModelRegistry.shared.getIcon(for: selectedModelType))
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text(ModelRegistry.shared.getDisplayName(for: selectedModelType))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showModelPicker) {
            ModelTypePickerView(selectedModelType: $selectedModelType)
        }
    }
}

//// MARK: - 模型类型选择弹窗
//struct ModelTypePickerView: View {
//    @Binding var selectedModelType: ModelType
//    @Environment(\.dismiss) var dismiss
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                LazyVGrid(
//                    columns: Array(repeating: GridItem(.fixed(150), spacing: 16), count: 3),
//                    spacing: 16
//                ) {
//                    // 使用ModelRegistry获取所有支持的模型类型
//                    ForEach(ModelRegistry.shared.getAllSupportedTypes(), id: \.self) { modelType in
//                        ModelTypeCard(
//                            type: modelType,
//                            name: ModelRegistry.shared.getDisplayName(for: modelType),
//                            icon: ModelRegistry.shared.getIcon(for: modelType),
//                            description: ModelRegistry.shared.getConfiguration(for: modelType)?.description ?? "",
//                            isSelected: selectedModelType == modelType,
//                            onSelect: {
//                                selectedModelType = modelType
//                                dismiss()
//                            }
//                        )
//                    }
//                }
//                .padding()
//            }
//            .navigationTitle("选择模型类型")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("取消") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}

// MARK: - 修复后的模型类型卡片
struct ModelTypeCard: View {
    let type: ModelType
    let name: String
    let icon: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // 🔧 核心修复：改进Model3D预览逻辑
                let fileName = ModelRegistry.shared.getUSDZFileName(for: type)
                
                if !fileName.isEmpty && fileName != ".usdz" {
                    // ✅ 修复方案1：移除可能冲突的变换，使用更安全的预览方式
                    Model3D(named: fileName) { model in
                        model
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            // 🚫 移除scaleEffect，避免与USDZ内部scale冲突
                            // .scaleEffect(0.7)
                            // 🚫 移除offset，可能导致渲染问题
                            // .offset(z: -25)
                    } placeholder: {
                        ModelPlaceholderView(icon: icon, name: name)
                    }
                    .frame(width: 120, height: 120) // 固定尺寸，确保一致性
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .opacity(0.5)
                    )
                    .clipped() // 确保内容不会溢出
                } else {
                    // 如果文件名无效，显示占位符
                    ModelPlaceholderView(icon: icon, name: name)
                        .frame(width: 120, height: 120)
                }
                
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
        .frame(width: 150, height: 170) // 调整高度以适应新布局
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0) // 减少缩放效果
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 改进的模型占位符视图
struct ModelPlaceholderView: View {
    let icon: String
    let name: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // 背景圆形
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 4) {
                Text("预览中...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 额外的调试预览组件
struct DebugModel3DView: View {
    let modelType: ModelType
    @State private var debugInfo: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Text("调试预览：\(ModelRegistry.shared.getDisplayName(for: modelType))")
                .font(.headline)
            
            let fileName = ModelRegistry.shared.getUSDZFileName(for: modelType)
            
            // 尝试不同的预览方式
            VStack(spacing: 16) {
                // 方式1：原始Model3D
                VStack {
                    Text("原始Model3D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Model3D(named: fileName) { model in
                        model
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView("加载中...")
                    }
                    .frame(width: 100, height: 100)
                    .border(.gray, width: 1)
                }
                
                // 方式2：带背景色的Model3D
                VStack {
                    Text("带背景Model3D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Model3D(named: fileName) { model in
                        model
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(.gray.opacity(0.3))
                            .overlay(
                                Text("加载中")
                                    .font(.caption)
                            )
                    }
                    .frame(width: 100, height: 100)
                    .background(.white)
                    .border(.blue, width: 1)
                }
                
                // 方式3：固定尺寸的Model3D
                VStack {
                    Text("固定尺寸Model3D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Model3D(named: fileName) { model in
                        model
                            .resizable()
                            .frame(width: 80, height: 80)
                    } placeholder: {
                        Cube()
                            .fill(.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                    }
                    .frame(width: 100, height: 100)
                    .border(.green, width: 1)
                }
            }
            
            // 调试信息
            VStack(alignment: .leading, spacing: 4) {
                Text("调试信息：")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("文件名：\(fileName)")
                    .font(.caption2)
                Text("类型：\(modelType.rawValue)")
                    .font(.caption2)
                Text(debugInfo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .padding()
        .onAppear {
            checkModelFile()
        }
    }
    
    private func checkModelFile() {
        let fileName = ModelRegistry.shared.getUSDZFileName(for: modelType)
        
        // 检查文件是否存在
        if let path = Bundle.main.path(forResource: fileName.replacingOccurrences(of: ".usdz", with: ""), ofType: "usdz") {
            debugInfo = "文件存在于: \(path)"
        } else {
            debugInfo = "文件不存在或路径错误"
        }
    }
}

// MARK: - 备用几何体组件（当USDZ无法加载时使用）
struct Cube: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfSize = size / 2
        
        // 绘制立方体的前面
        path.addRect(CGRect(
            x: center.x - halfSize,
            y: center.y - halfSize,
            width: size,
            height: size
        ))
        
        return path
    }
}

// MARK: - 预览用扩展
extension ModelTypeCard {
    static func preview(for type: ModelType) -> some View {
        ModelTypeCard(
            type: type,
            name: ModelRegistry.shared.getDisplayName(for: type),
            icon: ModelRegistry.shared.getIcon(for: type),
            description: "预览",
            isSelected: false,
            onSelect: {}
        )
    }
}

#if DEBUG
// MARK: - SwiftUI预览
struct ModelPreview_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 所有模型类型的预览
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(ModelType.allCases, id: \.self) { type in
                        ModelTypeCard.preview(for: type)
                    }
                }
                .padding()
            }
            
            // sign模型的调试预览
            DebugModel3DView(modelType: .sign)
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
