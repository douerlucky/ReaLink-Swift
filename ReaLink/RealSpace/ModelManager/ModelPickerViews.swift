//
//  ModelPickerViews.swift
//  ReaLink
//
//  模型选择器相关的视图组件 - 修复版（添加关闭按钮和3D预览）
//

import RealityKit
import SwiftUI

// MARK: - 3D模型预览组件

struct Model3DPreview: View
{
    let modelType: ModelType

    var body: some View
    {
        Model3D(named: modelFileName(for: modelType))
        { model in
            model
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            VStack(spacing: 8)
            {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)

                Text("加载中...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 64, height: 64)
        }
        .frame(width: 64, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    public func modelFileName(for type: ModelType) -> String
    {
        let usdzFileName = ModelRegistry.shared.getUSDZFileName(for: type)
        return usdzFileName
    }
}

// MARK: - 模型颜色选择器Sheet

struct ModelColorPickerSheet: View
{
    @Binding var selectedColor: Color
    let onColorSelected: (Color) -> Void

    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .cyan,
        .blue, .indigo, .purple, .pink, .brown, .gray,
        .black, .white,
    ]

    var body: some View
    {
        NavigationView
        {
            VStack(spacing: 20)
            {
                Text("选择模型颜色")
                    .font(.title2)
                    .fontWeight(.semibold)

                // 预设颜色网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12)
                {
                    ForEach(presetColors, id: \.self)
                    { color in
                        Button(action: {
                            selectedColor = color
                            onColorSelected(color)
                        })
                        {
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? .blue : .gray.opacity(0.3), lineWidth: selectedColor == color ? 3 : 1)
                                )
                                .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()

                // 自定义颜色选择器
                VStack(spacing: 12)
                {
                    Text("或选择自定义颜色")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ColorPicker("自定义颜色", selection: $selectedColor, supportsOpacity: false)
                        .onChange(of: selectedColor)
                        { newColor in
                            onColorSelected(newColor)
                        }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 模型类型选择器视图（✅ 修复版 - 添加关闭按钮和3D预览）

struct ModelTypePickerView: View
{
    @Binding var selectedModelType: ModelType
    @Environment(\.dismiss) var dismiss  // ✅ 添加 dismiss 环境变量
    
    var body: some View
    {
        NavigationView
        {
            ScrollView  // ✅ 添加 ScrollView 以支持滚动
            {
                VStack(spacing: 24)
                {
                    Text("选择模型类型")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top, 20)
                    
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3),
                        spacing: 20
                    )
                    {
                        ForEach(ModelType.allCases, id: \.self)
                        { modelType in
                            Button(action: {
                                selectedModelType = modelType
                                dismiss()  // ✅ 选择后自动关闭
                            })
                            {
                                VStack(spacing: 12)
                                {
                                    // ✅ 使用 3D 模型预览而不是图标
                                    Model3DPreview(modelType: modelType)
                                        .frame(width: 100, height: 100)
                                    
                                    Text(getModelTypeName(modelType))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(width: 120, height: 150)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedModelType == modelType ?
                                            Color.blue.opacity(0.1) :
                                            Color.gray.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            selectedModelType == modelType ?
                                                Color.blue :
                                                Color.gray.opacity(0.2),
                                            lineWidth: selectedModelType == modelType ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(selectedModelType == modelType ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: selectedModelType)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                // ✅ 添加右上角关闭按钮
                ToolbarItem(placement: .navigationBarTrailing)
                {
                    Button(action: {
                        dismiss()
                    })
                    {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func getModelTypeName(_ type: ModelType) -> String
    {
        switch type
        {
        case .cube: return "立方体"
        case .sphere: return "球体"
        case .cylinder: return "圆柱体"
        case .cone: return "锥体"
        case .capsule: return "胶囊"
        case .sign: return "告示牌"
        }
    }
}

// MARK: - 颜色按钮组件(备用)

struct ColorButton_modle: View
{
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View
    {
        Button(action: action)
        {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(isSelected ? .blue : .clear, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 颜色选择器视图(备用)

struct ColorPickerView_modle: View
{
    @Binding var selectedColor: Color

    var body: some View
    {
        ColorPicker("选择颜色", selection: $selectedColor)
            .padding()
    }
}

// MARK: - 模型类型选择器视图(备用)

struct ModelTypePickerView_modle: View
{
    @Binding var selectedModelType: ModelType

    var body: some View
    {
        NavigationView
        {
            VStack
            {
                Text("选择模型类型")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16)
                {
                    ForEach(ModelType.allCases, id: \.self)
                    { modelType in
                        Button(action: {
                            selectedModelType = modelType
                        })
                        {
                            VStack(spacing: 8)
                            {
                                Image(systemName: getModelTypeIcon(modelType))
                                    .font(.system(size: 32))
                                    .foregroundColor(selectedModelType == modelType ? .blue : .primary)

                                Text(getModelTypeName(modelType))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedModelType == modelType ? .blue.opacity(0.1) : .gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedModelType == modelType ? .blue : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()

                Spacer()
            }
        }
    }

    private func getModelTypeIcon(_ type: ModelType) -> String
    {
        switch type
        {
        case .cube: return "cube.fill"
        case .sphere: return "circle.fill"
        case .cylinder: return "cylinder.fill"
        case .cone: return "cone.fill"
        case .capsule: return "capsule.fill"
        case .sign: return "signpost.right.fill"
        }
    }

    private func getModelTypeName(_ type: ModelType) -> String
    {
        switch type
        {
        case .cube: return "立方体"
        case .sphere: return "球体"
        case .cylinder: return "圆柱体"
        case .cone: return "锥体"
        case .capsule: return "胶囊"
        case .sign: return "告示牌"
        }
    }
}

// MARK: - 辅助函数

extension QuestionDetailModalWithTabs
{
    public func formatAnswerDate(_ dateString: String) -> String
    {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
}
