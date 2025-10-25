//
//  RealityWindowView.swift
//  ReaLink
//
//  主Reality窗口视图 - 已移除区域选择功能
//

import ARKit
import RealityFoundation
import RealityKit
import SwiftUI


struct RealityWindowView: View {
    @Environment(\.dismissWindow) public var dismissWindow
    @Environment(\.openWindow) public var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var targetQuestion: TargetQuesitonManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var targetQuestionManager: TargetQuesitonManager
    @EnvironmentObject var windowStateManager: WindowStateManager
    @State public var showQuestionDetail = false
    @State private var showModelsManagement = false
    var body: some View {
        ZStack {
            if showQuestionDetail {
                QuestionDetailModalWithTabs.forReality(
                    question: targetQuestion.currentQuestion,
                    isPresented: $showQuestionDetail,
                    onClose: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
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
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    QuestionCard.detailed(
                        question: targetQuestion.currentQuestion,
                        onSelect: {
                            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
        .onDisappear {
            handleWindowDisappear()
        }
    }

    private func performCleanup() {
        print("🧹【开始清理RealityWindow资源】")
        
        // 发送通知
        NotificationCenter.default.post(
            name: NSNotification.Name("RealityWindowClosed"),
            object: nil
        )
        
        windowStateManager.isRealityWindowOpen = false
        
        print("✅【RealityWindow清理完成】")
    }
    
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        print("🔄 RealityWindow 场景阶段变化: \(oldPhase) -> \(newPhase)")
        
        if newPhase == .background || newPhase == .inactive {
            print("🔴 检测到窗口被关闭")
            performCleanup()
        }
    }
    
    private func handleWindowDisappear() {
        print("🔴 RealityWindow onDisappear 被触发")
        performCleanup()
    }
    
    public func handleSendReply(_ replyText: String) {
        guard let currentUserId = userManager.getUserId() else {
            print("用户未登录")
            return
        }
        
        Task {
            do {
                let response = try await NetworkManager.shared.sendAnswer(
                    questionId: targetQuestion.currentQuestion.id,
                    userId: currentUserId,
                    content: replyText
                )
                
                if response.success {
                    print("回复发送成功")
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ReplySuccessReloadAnswers"),
                        object: nil,
                        userInfo: ["questionId": targetQuestion.currentQuestion.id]
                    )
                }
            } catch {
                print("发送回复时出现错误: \(error)")
            }
        }
    }
}
#Preview(windowStyle: .automatic) {
    RealityWindowView()
        .frame(width: 450)
        .environmentObject({
            let question_manager = TargetQuesitonManager.shared
            question_manager.updateQuestion(question: Question_1)
            return question_manager
        }())
}
