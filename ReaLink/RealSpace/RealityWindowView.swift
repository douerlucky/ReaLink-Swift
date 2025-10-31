//
//  RealityWindowView.swift
//  ReaLink
//
//  主Reality窗口视图 - 修复窗口状态bug版本
//

import ARKit
import RealityFoundation
import RealityKit
import SwiftUI

struct RealityWindowView: View
{
    @Environment(\.dismissWindow) public var dismissWindow
    @Environment(\.openWindow) public var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var targetQuestion: TargetQuesitonManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var targetQuestionManager: TargetQuesitonManager
    @EnvironmentObject var windowStateManager: WindowStateManager
    @State public var showQuestionDetail = false
    @State private var showModelsManagement = false
    
    // 🔥 新增:跟踪scenePhase变化
    @State private var previousScenePhase: ScenePhase = .active
    
    var body: some View
    {
        ZStack
        {
            if showQuestionDetail
            {
                QuestionDetailModalWithTabs.forReality(
                    question: targetQuestion.currentQuestion,
                    isPresented: $showQuestionDetail,
                    onClose: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85))
                        {
                            showQuestionDetail = false
                        }

                    },
                    onSendReply: { replyText in
                        handleSendReply(replyText)
                    },
                    onRefreshAnswers: {
                        print("刷新答案数据")
                    }
                )
                .zIndex(20)
                .frame(minWidth: 800, minHeight: 600)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.85)),
                        removal: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.9))
                    )
                )
            }
            else
            {
                VStack(alignment: .leading, spacing: 20)
                {
                    QuestionCard.detailed(
                        question: targetQuestion.currentQuestion,
                        onSelect: {
                            withAnimation(.spring(response: 0.7, dampingFraction: 0.8))
                            {
                                showQuestionDetail = true
                            }
                        },
                        onLike: {
                            print("点赞问题")
                        },
                        onAvatarTap: {
                            print("查看用户信息")
                        }
                    )
                }
                .frame(width: 450)
            }
        }
        .frame(
            minWidth: showQuestionDetail ? 800 : 450,
            minHeight: showQuestionDetail ? 600 : 240
        )
        .onChange(of: scenePhase)
        { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
        .onDisappear
        {
            handleWindowDisappear()
        }
    }

    private func performCleanup()
    {
        print("🧹【开始清理RealityWindow资源】")

        // 🔥 关键修复:无条件重置窗口状态
        // onDisappear只在窗口真正销毁时才会触发,所以这里应该无条件执行
        windowStateManager.isRealityWindowOpen = false
        
        // 发送通知
        NotificationCenter.default.post(
            name: NSNotification.Name("RealityWindowClosed"),
            object: nil
        )

        print("✅【RealityWindow清理完成】isRealityWindowOpen = false")
    }

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase)
    {
        print("🔄 RealityWindow 场景阶段变化: \(oldPhase) -> \(newPhase)")
        
        // 🔥 关键修复：检测用户点击关闭按钮的特征序列
        // inactive -> background 是点击关闭按钮的典型特征
        // visionOS 的系统关闭按钮不会触发 onDisappear，只会让窗口进入后台
        if newPhase == .background && oldPhase == .inactive {
            print("🚪【检测到关闭窗口操作】inactive -> background")
            print("   执行主动关闭流程...")
            
            // 先清理状态
            performCleanup()
            
            // 主动关闭窗口
            dismissWindow(id: "RealityWindow")
            
            previousScenePhase = newPhase
            return
        }
        
        // 真正的休眠：active -> background（跳过inactive）
        if newPhase == .background && oldPhase == .active {
            print("😴【Vision Pro进入休眠】active -> background")
            previousScenePhase = newPhase
            return
        }
        
        if newPhase == .inactive {
            print("💤【窗口失去焦点】等待下一个状态变化...")
        }
        
        if newPhase == .active {
            if previousScenePhase == .background {
                print("😊【从休眠恢复】background -> active")
            } else if previousScenePhase == .inactive {
                print("😊【重新获得焦点】inactive -> active")
            }
        }
        
        previousScenePhase = newPhase
    }

    private func handleWindowDisappear()
    {
        print("🔴 RealityWindow onDisappear 被触发")
        
        // 🔥 关键修复:onDisappear 只会在窗口真正被销毁时触发
        // 休眠不会触发 onDisappear,所以这里无条件执行清理是安全的
        performCleanup()
    }

    public func handleSendReply(_ replyText: String)
    {
        guard let currentUserId = userManager.getUserId()
        else
        {
            print("用户未登录")
            return
        }

        Task
        {
            do
            {
                let response = try await NetworkManager.shared.sendAnswer(
                    questionId: targetQuestion.currentQuestion.id,
                    userId: currentUserId,
                    content: replyText
                )

                if response.success
                {
                    print("回复发送成功")

                    NotificationCenter.default.post(
                        name: NSNotification.Name("ReplySuccessReloadAnswers"),
                        object: nil,
                        userInfo: ["questionId": targetQuestion.currentQuestion.id]
                    )
                }
            }
            catch
            {
                print("发送回复时出现错误: \(error)")
            }
        }
    }
}

#Preview(windowStyle: .automatic)
{
    RealityWindowView()
        .frame(width: 450)
        .environmentObject({
            let question_manager = TargetQuesitonManager.shared
            question_manager.updateQuestion(question: Question_1)
            return question_manager
        }())
}
