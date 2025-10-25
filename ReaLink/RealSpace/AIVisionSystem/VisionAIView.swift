//
//  VisionAIView_Fixed.swift
//  ✅ 修复场景识别面板的关闭逻辑
//
//  修复内容：
//  1. 点击×键时清除可视化 + 禁用手势
//  2. 点击"取消选择区域"时清除可视化 + 禁用手势
//  3. 关闭AIAssistantWindow时清除所有可视化
//  4. 发送识别请求后保留可视化（用户可能继续提问）
//

import SwiftUI

// MARK: - 🎯 场景识别入口按钮（保持不变）
struct SceneRecognitionEntryButton: View {
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .cyan.opacity(0.8),
                                    .blue.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vision AI 场景识别")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("智能识别全景场景内容")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(isHovered ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 🔥 场景识别面板（修复版）
struct SceneRecognitionPanel: View {
    @Binding var state: SceneRecognitionState
    @Binding var selectedRegion: SelectionRegion?
    @Binding var recognitionResult: String?
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            VStack(spacing: 16) {
                // 头部
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "viewfinder.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cyan)
                        
                        Text("Vision AI 场景识别")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    // 🔥 关键修复：×按钮清除所有可视化
                    Button(action: {
                        handlePanelClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // 操作提示
                InstructionCard(state: state)
                    .padding(.horizontal, 16)
                
                // 🔥 核心：简化的三态按钮
                RegionSelectionButton(
                    state: $state,
                    selectedRegion: $selectedRegion
                )
                .padding(.horizontal, 16)
                
                // 识别结果显示
                if let result = recognitionResult {
                    RecognitionResultView(result: result)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial)
    }
    
    // 🔥 关键修复：面板关闭清理逻辑
    private func handlePanelClose() {
        print("❌【点击×按钮】清除所有可视化并重置状态")
        
        // 1. 清除所有可视化（用户圈选 + 拟合球面）
        NotificationCenter.default.post(
            name: NSNotification.Name("CancelRegionSelection"),
            object: nil
        )
        
        // 2. 禁用区域选择手势
        NotificationCenter.default.post(
            name: NSNotification.Name("DisableRegionSelection"),
            object: nil
        )
        
        // 3. 重置所有状态
        state = .idle
        selectedRegion = nil
        recognitionResult = nil
        
        // 4. 关闭面板UI
        onClose()
        
        print("✅【面板关闭清理完成】")
    }
}

struct RegionSelectionButton: View {
    @Binding var state: SceneRecognitionState
    @Binding var selectedRegion: SelectionRegion?
    
    var body: some View {
        HStack(spacing: 0) {
            switch state {
            case .idle:
                // 蓝色：开始绘制选择区域
                ActionButton(
                    title: "开始绘制选择区域",
                    icon: "hand.draw.fill",
                    color: .blue,
                    action: startDrawing
                )
                
            case .drawing, .waitingConfirm:
                // 灰色：正在选择区域...（不可点击）
                if state == .drawing {
                    StatusButton(
                        title: "正在选择区域...",
                        icon: "hand.draw",
                        color: .gray
                    )
                } else {
                    // 红色：删除绘制的区域
                    ActionButton(
                        title: "删除绘制的区域",
                        icon: "trash.circle.fill",
                        color: .red,
                        action: deleteDrawing
                    )
                }
                
            case .recognizing:
                // AI识别中（不可点击）
                StatusButton(
                    title: "AI 正在识别中...",
                    icon: "sparkles",
                    color: .purple,
                    showProgress: true
                )
                
            case .completed:
                // 识别完成，显示删除按钮
                ActionButton(
                    title: "删除绘制的区域",
                    icon: "trash.circle.fill",
                    color: .red,
                    action: deleteDrawing
                )
            }
        }
    }
    
    // MARK: - 🎯 开始绘画
    private func startDrawing() {
        print("🎯【开始绘画】启用区域选择")
        state = .drawing
        
        // 发送通知启用区域选择手势
        NotificationCenter.default.post(
            name: NSNotification.Name("EnableRegionSelection"),
            object: nil
        )
    }
    
    // MARK: - 🗑️ 删除绘制区域（清除所有可视化）
    private func deleteDrawing() {
        print("🗑️【删除绘制区域】清除所有可视化")
        
        // 1. 清除所有可视化（用户圈选 + 拟合球面）
        NotificationCenter.default.post(
            name: NSNotification.Name("CancelRegionSelection"),
            object: nil
        )
        
        // 2. 禁用区域选择手势
        NotificationCenter.default.post(
            name: NSNotification.Name("DisableRegionSelection"),
            object: nil
        )
        
        // 3. 重置状态
        state = .idle
        selectedRegion = nil
        
        print("✅【删除完成】用户需要重新点击\"开始绘制\"才能画")
    }
}


// MARK: - 🔥 控制按钮组（修复版）
struct ControlButtonsFixed: View {
    @Binding var state: SceneRecognitionState
    @Binding var selectedRegion: SelectionRegion?
    @Binding var recognitionResult: String?
    
    var body: some View {
        HStack(spacing: 12) {
            switch state {
            case .idle:
                // 🔥 开始绘画按钮
                ActionButton(
                    title: "开始绘画选择区域",
                    icon: "pencil.circle.fill",
                    color: .blue,
                    action: startDrawing
                )
                
            case .drawing:
                // 正在绘画状态
                StatusButton(
                    title: "正在绘画选择区域...",
                    icon: "pencil.and.outline",
                    color: .cyan
                )
                
            case .waitingConfirm:
                // 🔥 只显示"取消选择区域"按钮
                ActionButton(
                    title: "取消选择区域",
                    icon: "xmark.circle.fill",
                    color: .red,
                    action: cancelSelection
                )
                
            case .recognizing:
                // 识别中状态
                StatusButton(
                    title: "AI 正在识别中...",
                    icon: "sparkles",
                    color: .purple,
                    showProgress: true
                )
                
            case .completed:
                // 重新识别按钮
                ActionButton(
                    title: "重新识别",
                    icon: "arrow.counterclockwise.circle.fill",
                    color: .blue,
                    action: resetToIdle
                )
            }
        }
    }
    
    // MARK: - 🎯 开始绘画
    private func startDrawing() {
        print("🎯【开始绘画】启用区域选择")
        state = .drawing
        
        // 🔥 发送通知启用区域选择手势
        NotificationCenter.default.post(
            name: NSNotification.Name("EnableRegionSelection"),
            object: nil
        )
    }
    
    // MARK: - ❌ 取消选择（清除可视化 + 禁用手势）
    private func cancelSelection() {
        print("❌【取消选择】清除所有可视化 + 禁用手势")
        
        // 重置状态
        selectedRegion = nil
        recognitionResult = nil
        state = .idle
        
        // 🔥 关键：发送取消选择通知（会清除可视化 + 禁用手势）
        NotificationCenter.default.post(
            name: NSNotification.Name("CancelRegionSelection"),
            object: nil
        )
        
        print("✅【取消完成】用户需要再次点击\"开始画\"才能画")
    }
    
    // MARK: - 🔄 重置到初始状态
    private func resetToIdle() {
        print("🔄【重置】返回初始状态")
        
        // 清除状态
        state = .idle
        selectedRegion = nil
        recognitionResult = nil
        
        // 🔥 清除可视化（因为要重新识别）
        NotificationCenter.default.post(
            name: NSNotification.Name("CancelRegionSelection"),
            object: nil
        )
    }
}

// MARK: - 📝 操作提示卡片（保持不变）
struct InstructionCard: View {
    let state: SceneRecognitionState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: instructionIcon)
                    .foregroundColor(instructionColor)
                Text(instructionTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(instructionColor)
            }
            
            Text(instructionText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(instructionColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(instructionColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var instructionIcon: String {
        switch state {
        case .idle: return "hand.point.up.left.fill"
        case .drawing: return "pencil.and.outline"
        case .waitingConfirm: return "checkmark.circle.fill"
        case .recognizing: return "sparkles"
        case .completed: return "checkmark.seal.fill"
        }
    }
    
    private var instructionColor: Color {
        switch state {
        case .idle: return .blue
        case .drawing: return .gray
        case .waitingConfirm: return .orange
        case .recognizing: return .purple
        case .completed: return .green
        }
    }
    
    private var instructionTitle: String {
        switch state {
        case .idle: return "开始前准备"
        case .drawing: return "正在绘画选择"
        case .waitingConfirm: return "区域已选择"
        case .recognizing: return "AI识别中"
        case .completed: return "识别完成"
        }
    }
    
    private var instructionText: String {
        switch state {
        case .idle:
            return "点击下方按钮开始绘画。使用双指捏合手势在全景图中圈选您感兴趣的区域。"
        case .drawing:
            return "请使用双指捏合并移动来绘制选择区域。绘制完成后松开手指，系统会自动闭合选区。"
        case .waitingConfirm:
            return "区域已选择完成。在下方输入框输入问题后点击发送，AI会基于选中区域进行识别分析。"
        case .recognizing:
            return "正在使用Vision AI分析选中的场景区域，识别其中的物体、文字和场景信息..."
        case .completed:
            return "AI识别已完成！查看下方的识别结果。可继续提问或点击删除按钮清除选区。"
        }
    }
}
// MARK: - 🔘 操作按钮（保持不变）
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: color.opacity(0.3), radius: isPressed ? 2 : 4, y: isPressed ? 1 : 2)
        }
        .buttonStyle(.plain)
    }
}
// MARK: - 📊 状态按钮（保持不变）
struct StatusButton: View {
    let title: String
    let icon: String
    let color: Color
    var showProgress: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            if showProgress {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(color)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
            }
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - 📄 识别结果视图（保持不变）
struct RecognitionResultView: View {
    let result: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                Text("识别结果")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            ScrollView {
                Text(result)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
        .padding(12)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
    }
}
// MARK: - 🔥 AIAssistantWindow扩展（修复版）
extension AIAssistantWindow {
    
    /// 🚪 当窗口即将关闭时调用
    func onWindowWillCloseFixed() {
        print("🚪【AI助手窗口即将关闭】")
        
        // 🔥 发送窗口关闭通知（会清除所有可视化）
        NotificationCenter.default.post(
            name: NSNotification.Name("AIAssistantWindowWillClose"),
            object: nil
        )
        
        // 🔥 确保禁用区域选择手势
        NotificationCenter.default.post(
            name: NSNotification.Name("DisableRegionSelection"),
            object: nil
        )
        
        print("✅【窗口关闭清理通知已发送】")
    }
}
