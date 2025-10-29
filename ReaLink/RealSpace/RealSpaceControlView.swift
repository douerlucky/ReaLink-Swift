//
//  RealSpaceControlView.swift
//  ReaLink
//
//  ✅ 修复版本：
//  1. 防止重复打开 MainWindow
//  2. OK手势只在所有窗口关闭后才检测
//

import ARKit
import RealityKit
import RealityKitContent
import SwiftUI

struct ControlMenuWindow: View
{
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @EnvironmentObject var vrManager: VRSessionManager
    
    // ✅ 新增：跟踪退出流程状态，防止重复执行
    @State private var isExitingImmersive = false

    var body: some View
    {
        VStack(spacing: 0)
        {
            // 标题区域
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 24)

            // 控制内容区域
            controlsContent
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
        .frame(width: 450)
        .glassBackgroundEffect(
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
    }

    // MARK: - 标题区域

    private var headerView: some View
    {
        HStack(spacing: 12)
        {
            // 位置指示器
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.orange, .orange.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 12, height: 12)
                .shadow(color: .orange.opacity(0.5), radius: 4, x: 0, y: 0)

            // 位置标题
            Text(vrManager.currentLocationTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            // 关闭按钮
            Button(action: {
                dismissWindow(id: "ControlMenuWindow")
            })
            {
                Image(systemName: "xmark")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 64,height:64)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .buttonBorderShape(.circle)
            .hoverEffect(.highlight)
        }
    }

    // MARK: - 控制内容

    private var controlsContent: some View
    {
        VStack(spacing: 20)
        {
            // 退出实景模式按钮
            exitButton

            Divider()

            // 操作指南卡片
            operationGuideCard
        }
    }

    // MARK: - 退出按钮

    private var exitButton: some View
    {
        Button(action: {
            // ✅ 防止重复执行退出流程
            guard !isExitingImmersive else {
                print("⚠️ 退出流程已在进行中，忽略重复点击")
                return
            }
            
            isExitingImmersive = true
            print("🚪【开始退出全景模式流程】")
            
            // ✅ 1️⃣ 先发送重置所有VR状态的通知（包括场景重置）
            NotificationCenter.default.post(
                name: NSNotification.Name("ResetAllVRStates"),
                object: nil
            )
            print("📢 已发送重置所有VR状态通知")


            // ✅ 3️⃣ 等待通知处理完成，然后关闭所有窗口
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task {
                    print("🪟【开始销毁所有窗口】")
                    
                    // ✅ 销毁所有关联窗口（完整列表）
                    self.dismissWindow(id: "ModelsListWindow")
                    print("  🗑️ 已销毁 ModelsListWindow")
                    
                    self.dismissWindow(id: "AIAssistantWindow")
                    print("  🗑️ 已销毁 AIAssistantWindow")
                    
                    self.dismissWindow(id: "ControlMenuWindow")
                    print("  🗑️ 已销毁 ControlMenuWindow")
                    
                    self.dismissWindow(id: "RealityWindow")
                    print("  🗑️ 已销毁 RealityWindow")
                    
                    self.dismissWindow(id: "BrushControlWindow")
                    print("  🗑️ 已销毁 BrushControlWindow")
                    
                    self.dismissWindow(id: "ModelControlWindow")
                    print("  🗑️ 已销毁 ModelControlWindow")
                    
                    print("✅【所有窗口销毁完成】")
                    
                    // ✅ 4️⃣ 等待窗口销毁完成后，退出沉浸式空间
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                    
                    await self.dismissImmersiveSpace()
                    print("✅【沉浸式空间已退出】")
                    
                    // ✅ 5️⃣ 确保沉浸式空间完全关闭后，再打开主窗口
                    // 这里延迟更长时间，确保所有清理工作完成
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    
                    // ✅ 关键修复：只打开一次 MainWindow
                    // 使用 async/await 确保在主线程执行
                    await MainActor.run {
                        self.openWindow(id: "MainWindow")
                        print("✅【主窗口已打开】")
                    }
                    
                    // ✅ 重置退出状态标志
                    await MainActor.run {
                        self.isExitingImmersive = false
                    }
                    
                    print("🎉【退出全景模式完成，所有状态已重置】")
                }
            }
        })
        {
            HStack(spacing: 16)
            {
                // 图标容器
                ZStack
                {
                    Circle()
                        .fill(.blue.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: "arrow.backward.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .cyan]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                }

                // 文本
                VStack(alignment: .leading, spacing: 2)
                {
                    Text("退出实景模式")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("返回主界面")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .disabled(isExitingImmersive) // ✅ 退出过程中禁用按钮
    }

    // MARK: - 操作指南卡片

    private var operationGuideCard: some View
    {
        VStack(alignment: .leading, spacing: 16)
        {
            // 卡片标题
            HStack(spacing: 8)
            {
                Image(systemName: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)

                Text("操作指南")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // 操作提示列表
            VStack(alignment: .leading, spacing: 12)
            {
                #if targetEnvironment(simulator)
                    // 模拟器提示
                    OperationGuideRow(
                        icon: "keyboard.fill",
                        iconColor: .purple,
                        title: "键盘控制",
                        description: "L/R/F 键模拟手势"
                    )
                #else
                    // 真机提示
                    OperationGuideRow(
                        icon: "hand.point.up.left.fill",
                        iconColor: .purple,
                        title: "OK 手势",
                        description: "打开控制菜单"
                    )
                #endif

                OperationGuideRow(
                    icon: "location.circle.fill",
                    iconColor: .orange,
                    title: "橙色标记",
                    description: "点击查看问答详情"
                )

                OperationGuideRow(
                    icon: "hand.draw.fill",
                    iconColor: .cyan,
                    title: "手势交互",
                    description: "双手捏合旋转视角"
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - 操作指南行组件

struct OperationGuideRow: View
{
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View
    {
        HStack(spacing: 12)
        {
            // 图标
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)

            // 文本
            VStack(alignment: .leading, spacing: 2)
            {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - 预览

#Preview(windowStyle: .automatic)
{
    ControlMenuWindow()
        .environmentObject({
            let manager = VRSessionManager.shared
            manager.updateLocationInfo(
                title: "华中农业大学梧桐广场", locationId: 2,
                panoramaImage: "docklands_02"
            )
            return manager
        }())
}
