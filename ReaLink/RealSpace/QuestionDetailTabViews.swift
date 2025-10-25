//
//  QuestionDetailTabViews.swift
//  ReaLink
//
//  问题详情的各个Tab内容视图 - 修复版
//

import RealityKit
import SwiftUI

// MARK: - 对话Tab（保持不变）

struct QuestionConversationTab: View
{
    let question: Question
    let isRealityEnvironment: Bool
    let contentOpacity: Double

    @EnvironmentObject var userManager: UserManager

    var body: some View
    {
        QuestionMessagesView(
            question: question,
            isRealityEnvironment: isRealityEnvironment
        )
        .environmentObject(userManager)
        .opacity(contentOpacity)
    }
}

// MARK: - 空间绘画Tab（保持不变）

struct SpatialPaintingTab: View
{
    let question: Question
    @ObservedObject var brushManager: BrushManager
    let contentOpacity: Double

    @Binding var isSavingPainting: Bool
    @Binding var paintingSaveStatus: String
    @Binding var isRefreshingPainting: Bool

    let onSave: () -> Void

    var body: some View
    {
        ScrollView
        {
            VStack(spacing: 20)
            {
                // Header状态显示
                HStack
                {
                    Text("空间批注(Beta)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()
                }

                // 绘画控制面板（只显示画笔设置，不显示操作按钮）
                VStack(alignment: .leading, spacing: 16)
                {
                    if brushManager.isPaintingEnabled
                    {
                        HStack(spacing: 30)
                        {
                            // 左侧:画笔颜色选择
                            VStack(alignment: .leading, spacing: 12)
                            {
                                Text("画笔颜色")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                ColorPicker("选择颜色", selection: $brushManager.brushColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 120, height: 120)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(brushManager.brushColor)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                                    )
                            }

                            // 右侧:画笔大小控制
                            VStack(alignment: .leading, spacing: 12)
                            {
                                Text("画笔大小")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("\(String(format: "%.1f", brushManager.brushSize)) mm")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(brushManager.brushColor)

                                Slider(value: $brushManager.brushSize, in: 0.5 ... 10.0, step: 0.1)
                                    .tint(brushManager.brushColor)
                                    .frame(width: 200)
                                    .onChange(of: brushManager.brushSize)
                                    { newValue in
                                        print("🎨 画笔大小调整为: \(newValue)mm")
                                    }
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)

                        // 保存状态显示
                        if !paintingSaveStatus.isEmpty
                        {
                            Text(paintingSaveStatus)
                                .font(.caption)
                                .foregroundColor(paintingSaveStatus.contains("成功") ? .green : .red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        // 使用提示信息
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Text("💡 操作提示")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)

                            Text("• 拇指和食指捏合:开始绘画\n• 保持捏合并移动:继续绘画\n• 放开手指:结束当前笔画")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                        }
                        .padding(16)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    else
                    {
                        // 未启用时的提示
                        VStack(spacing: 16)
                        {
                            Image(systemName: "paintbrush.pointed")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("点击右下方开关启用空间绘画功能")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .background(.gray.opacity(0.05))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(24)
        }
        .opacity(contentOpacity)
        // ✅ 使用 ornament 添加底部操作栏
        .ornament(
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .center
        )
        {
            paintingBottomBar
                .opacity(contentOpacity)
        }
    }
    
    // MARK: - 绘画底部操作栏
    private var paintingBottomBar: some View
    {
        HStack(spacing: 0)
        {
            // 左下角：撤回、清空
            HStack(spacing: 12)
            {
                // 撤回按钮
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("UndoLastStroke"), object: nil)
                    print("🎨 发送撤回指令")
                })
                {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!brushManager.isPaintingEnabled)
                
                // 清空画布按钮
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ClearCanvas"), object: nil)
                    print("🎨 发送清空画布指令")
                })
                {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!brushManager.isPaintingEnabled)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // 右下角：Toggle开关、刷新、保存
            HStack(spacing: 12)
            {
                // 绘画开关
                Button(action: {
                    brushManager.isPaintingEnabled.toggle()
                    print("🎨 绘画模式切换: \(brushManager.isPaintingEnabled)")
                })
                {
                    HStack(spacing: 8)
                    {
                        Image(systemName: brushManager.isPaintingEnabled ? "paintbrush.fill" : "paintbrush")
                            .font(.title3)
                        
                        Text(brushManager.isPaintingEnabled ? "已启用" : "已禁用")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(brushManager.isPaintingEnabled ? .green : .gray)
                
                // 刷新按钮
                Button(action: {
                    print("🎨 用户点击刷新绘画数据按钮")
                    isRefreshingPainting = true
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshPainting"), object: nil)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)
                    {
                        isRefreshingPainting = false
                    }
                })
                {
                    if isRefreshingPainting
                    {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 44, height: 44)
                    }
                    else
                    {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isRefreshingPainting)
                
                // 保存按钮
                Button(action: onSave)
                {
                    HStack(spacing: 8)
                    {
                        if isSavingPainting
                        {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        else
                        {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                        }
                        Text("保存")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSavingPainting || !brushManager.isPaintingEnabled)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 16)
        .glassBackgroundEffect()
    }
}


// MARK: - 模型放置Tab（修复版 - 移除默认颜色）

struct ModelPlacementTab: View
{
    let question: Question
    @ObservedObject var modelManager: ModelManager

    @Binding var selectedModelForEdit: PlacedModel?
    @Binding var isEditingModel: Bool
    @Binding var editModelColor: Color
    @Binding var modelRotationX: Double
    @Binding var modelRotationY: Double
    @Binding var modelRotationZ: Double
    @Binding var selectedModelText: String
    @Binding var showModelTypePicker: Bool

    let contentOpacity: Double

    @Binding var isSavingModels: Bool
    @Binding var modelsSaveStatus: String
    @Binding var isRefreshingModels: Bool
    @Binding var isAddingModel: Bool

    let onSave: () -> Void

    @EnvironmentObject var userManager: UserManager
    @Environment(\.openWindow) var openWindow

    var body: some View
    {
        ScrollView
        {
            VStack(spacing: 20)
            {
                // Header状态显示
                HStack
                {
                    Text("3D模型(Beta)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()
                }

                // 模型控制面板（只显示核心设置，不显示操作按钮）
                VStack(alignment: .leading, spacing: 16)
                {
                    if modelManager.isModelTestingEnabled
                    {
                        VStack
                        {
                            // 1:1分栏布局
                            HStack(alignment: .top, spacing: 20)
                            {
                                // 左侧:模型选择和默认设置
                                ModelSelectionSection(
                                    modelManager: modelManager,
                                    showModelTypePicker: $showModelTypePicker,
                                    isAddingModel: $isAddingModel
                                )
                                .frame(maxWidth: .infinity)

                                // 右侧:选中模型编辑区域
                                ModelEditSection(
                                    selectedModelForEdit: $selectedModelForEdit,
                                    editModelColor: $editModelColor,
                                    modelRotationX: $modelRotationX,
                                    modelRotationY: $modelRotationY,
                                    modelRotationZ: $modelRotationZ,
                                    selectedModelText: $selectedModelText,
                                    userManager: userManager
                                )
                                .frame(maxWidth: .infinity)
                            }

                            // 保存状态显示
                            if !modelsSaveStatus.isEmpty
                            {
                                Text(modelsSaveStatus)
                                    .font(.caption)
                                    .foregroundColor(modelsSaveStatus.contains("成功") ? .green : .red)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    else
                    {
                        // 禁用状态提示
                        VStack(spacing: 16)
                        {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("点击右下方开关启用3D模型测试功能")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .background(.gray.opacity(0.05))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(24)
        }
        .opacity(contentOpacity)
        // ✅ 使用 ornament 添加底部操作栏
        .ornament(
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .center
        )
        {
            modelBottomBar
                .opacity(contentOpacity)
        }
    }
    
    // MARK: - 模型底部操作栏
    private var modelBottomBar: some View
    {
        HStack(spacing: 0)
        {
            // 左下角：撤回、清空
            HStack(spacing: 12)
            {
                // 撤回按钮
                Button(action: {
                    print("🔄 用户点击撤回按钮")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ExecuteUndoOperation"),
                        object: nil
                    )
                })
                {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!modelManager.isModelTestingEnabled)

                // 清空按钮
                Button(action: {
                    print("🧊 清空所有模型")
                    NotificationCenter.default.post(name: NSNotification.Name("ClearAllModels"), object: nil)
                })
                {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!modelManager.isModelTestingEnabled)
            }
            .padding(.horizontal, 24)

            Spacer()

            // 右下角：模型开关、管理、刷新、保存
            HStack(spacing: 12)
            {
                // 模型测试开关
                Button(action: {
                    modelManager.isModelTestingEnabled.toggle()
                    print("🧊 模型测试模式切换: \(modelManager.isModelTestingEnabled)")
                })
                {
                    HStack(spacing: 8)
                    {
                        Image(systemName: modelManager.isModelTestingEnabled ? "cube.fill" : "cube")
                            .font(.title3)
                        
                        Text(modelManager.isModelTestingEnabled ? "已启用" : "已禁用")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(modelManager.isModelTestingEnabled ? .green : .gray)
                
                // 管理模型按钮
                Button(action: {
                    print("🪟 打开模型管理窗口")
                    openWindow(id: "ModelsListWindow")
                })
                {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(!modelManager.isModelTestingEnabled)
                
                // 刷新按钮
                Button(action: {
                    print("🧊 用户点击刷新模型数据按钮")
                    isRefreshingModels = true
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshModels"), object: nil)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)
                    {
                        isRefreshingModels = false
                    }
                })
                {
                    if isRefreshingModels
                    {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 44, height: 44)
                    }
                    else
                    {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isRefreshingModels || !modelManager.isModelTestingEnabled)

                // 保存按钮
                Button(action: onSave)
                {
                    HStack(spacing: 8)
                    {
                        if isSavingModels
                        {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        else
                        {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                        }
                        Text("保存")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSavingModels || !modelManager.isModelTestingEnabled)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 16)
        .glassBackgroundEffect()
    }
}
