//
//  QuestionDetailModal.swift
//  ReaLink
//
//  Created by Assistant on 2025.08.18.
//

import ARKit
import MapKit
import RealityFoundation
import RealityKit
import SwiftUI

// MARK: - 统一的问题详情模态框

struct QuestionDetailModal: View
{
    let question: Question
    @Binding var isPresented: Bool
    let onClose: () -> Void

    @EnvironmentObject var userManager: UserManager

    // 添加环境变量来打开窗口
    @Environment(\.openWindow) private var openWindow

    // 回调
    let onSendReply: ((String) -> Void)?
    let onAttachFile: (() -> Void)?

    // 新增：Reality环境适配参数
    let isRealityEnvironment: Bool

    @State private var animationOffset: CGFloat = 400
    @State private var animationOpacity: Double = 0
    @State private var replyText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    // Reality环境专用动画状态
    @State private var contentOpacity: Double = 0
    @State private var headerScale: CGFloat = 0.8
    @State private var scrollViewOffset: CGFloat = 30

    @State private var questionAnswers: getQuestionAnswerResponse?
    @State private var isLoadingAnswers: Bool = false
    @State private var loadingError: String?
    @State private var isSendingReply = false
    @State private var replyError: String?
    @State private var showAIAssistant = false
    @State private var showQuickActions = false
    @State private var pendingAIMessage: String?

    // 主构造器
    init(
        question: Question,
        isPresented: Binding<Bool>,
        onClose: @escaping () -> Void,
        onSendReply: ((String) -> Void)? = nil,
        onAttachFile: (() -> Void)? = nil,
        isRealityEnvironment: Bool = false
    )
    {
        self.question = question
        _isPresented = isPresented
        self.onClose = onClose
        self.onSendReply = onSendReply
        self.onAttachFile = onAttachFile
        self.isRealityEnvironment = isRealityEnvironment
    }

    var body: some View
    {
        ZStack
        {
            if isRealityEnvironment
            {
                realityEnvironmentView
                    .onAppear
                    {
                        print("🏞 Reality环境视图出现")
                        realityAppearAnimation()
                    }
            }
            else
            {
                standardEnvironmentView
                    .onAppear
                    {
                        print("📱 标准环境视图出现")
                        standardAppearAnimation()
                    }
            }

            // AI助手
            if showAIAssistant
            {
                AIAssistant.forExplore(question: question, isPresented: $showAIAssistant)
                    .zIndex(200)
            }
        }
    }

    // MARK: - Reality环境视图

    private var realityEnvironmentView: some View
    {
        VStack(spacing: 0)
        {
            // 头部
            headerView
                .padding(24)
                .background(.regularMaterial)
                .scaleEffect(headerScale)
                .opacity(contentOpacity)

            // 滚动内容区域
            ScrollView
            {
                messagesView
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }
            .opacity(contentOpacity)
            .ornament(
                attachmentAnchor: .scene(.bottom),
                contentAlignment: .center
            )
            {
                inputView
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .glassBackgroundEffect()
                    .opacity(contentOpacity)
                    .scaleEffect(contentOpacity > 0.5 ? 1.0 : 0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.25), radius: 25, x: 0, y: 10)
        .onAppear
        {
            realityAppearAnimation()
        }
        .onDisappear
        {
            realityDisappearAnimation()
        }
        .ignoresSafeArea()
    }

    // MARK: - 标准环境视图

    private var standardEnvironmentView: some View
    {
        ZStack
        {
            // 半透明遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .opacity(animationOpacity)

            // 右边缘布局
            HStack
            {
                Spacer()

                // 详情内容
                VStack
                {
                    // 头部
                    VStack
                    {
                        headerView
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))

                        ScrollView
                        {
                            messagesView
                                .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(width: 600)
                .frame(maxHeight: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
                .scaleEffect(animationOpacity)
                .opacity(animationOpacity)
                .offset(x: animationOffset)
                .padding(20)
                .onAppear
                {
                    standardAppearAnimation()
                }
                .onChange(of: isPresented)
                { _ in
                    if !isPresented
                    {
                        standardDisappearAnimation()
                    }
                }
                .ornament(
                    attachmentAnchor: .scene(.bottom),
                    contentAlignment: .center
                )
                {
                    inputView
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .glassBackgroundEffect()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    // MARK: - 共享的头部视图

    private var headerView: some View
    {
        VStack(alignment: .leading, spacing: 16)
        {
            HStack
            {
                Text(question.actualPlace)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: onClose)
                {
                    Image(systemName: "xmark")
                        
                        .font(.title)
                        .foregroundColor(.secondary)
                        .frame(width: 64, height: 64)  // 改大按钮尺寸
                        
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .buttonBorderShape(.circle)  // 添加这个
                .hoverEffect(.highlight)
            }

            HStack(spacing: 10)
            {
                // 使用真实的用户头像，与ExploreView.swift保持一致
                if let avatarUrl = question.avatarUrl, !avatarUrl.isEmpty
                {
                    AsyncImage(url: URL(string: avatarUrl))
                    { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // 占位符显示默认头像
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                }
                else
                {
                    // 如果没有头像URL，显示默认头像
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                        .frame(width: 48, height: 48)
                }

                // 使用真实的用户名，与ExploreView.swift保持一致
                Text(question.username ?? "未知用户")
                    .font(.headline)
                Spacer()
                Text(formatDate(question.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(question.title)
                .font(.title)
                .fontWeight(.bold)
        }
    }

    // MARK: - 共享的消息视图

    private var messagesView: some View
    {
        QuestionMessagesView(
            question: question,
            isRealityEnvironment: isRealityEnvironment
        )
        .environmentObject(userManager)
    }

    // MARK: - 输入视图（修改AI助手按钮）

    private var inputView: some View
    {
        VStack(spacing: 12)
        {
            // 错误提示
            if let error = replyError
            {
                HStack
                {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("✕")
                    {
                        replyError = nil
                    }
                    .foregroundColor(.orange)
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 20)
            {
                // AI助手按钮
                Button(action: {
                    openAIAssistantWindow()
                })
                {
                    ZStack
                    {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        .blue.opacity(0.3),
                                        .purple.opacity(0.2),
                                        .clear,
                                    ]),
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 40, height: 40)

                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .blue.opacity(0.9),
                                        .purple.opacity(0.7),
                                        .cyan.opacity(0.5),
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)

                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)  // 改小按钮尺寸
                    }
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .disabled(isSendingReply)
                .buttonBorderShape(.circle)  // 添加这个

                // 输入框
                TextField("输入你的回答...", text: $replyText, axis: .vertical)
                    .focused($isTextFieldFocused)
                    .lineLimit(1 ... 4)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .font(.system(size: isRealityEnvironment ? 24 : 16))
                    .textFieldStyle(.plain)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: isRealityEnvironment ? 550 : 400)
                    .onSubmit
                    {
                        if !isSendingReply
                        {
                            handleSendReply()
                        }
                    }
                    .disabled(isSendingReply)
                    .hoverEffect(.highlight)

                // 发送按钮
                Button(action: handleSendReply)
                {
                    if isSendingReply
                    {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 64, height: 64)  // 改小按钮尺寸
                    }
                    else
                    {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)  // 改小按钮尺寸
                    }
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .tint(.blue)
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingReply)
                .scaleEffect(isRealityEnvironment && (replyText.isEmpty || isSendingReply) ? 0.9 : 1.0)
                .animation(isRealityEnvironment ? .easeInOut(duration: 0.2) : .none, value: replyText.isEmpty)
                .animation(isRealityEnvironment ? .easeInOut(duration: 0.2) : .none, value: isSendingReply)
                .buttonBorderShape(.circle)  // 添加这个
            }

            // 字数统计
            HStack
            {
                Text("\(replyText.count)/1000")
                    .font(.caption2)
                    .foregroundColor(replyText.count > 1000 ? .red : .secondary)

                Spacer()

                if isSendingReply
                {
                    Text("正在发送...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .opacity(replyText.isEmpty && !isSendingReply ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: replyText.isEmpty)
            .animation(.easeInOut(duration: 0.2), value: isSendingReply)
        }
    }

    // MARK: - Reality环境动画（保持不变）

    private func realityAppearAnimation()
    {
        withAnimation(.easeOut(duration: 0.3))
        {
            contentOpacity = 1.0
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1))
        {
            headerScale = 1.0
        }

        withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15))
        {
            scrollViewOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6)
        {
            withAnimation(.easeInOut(duration: 0.3))
            {
                isTextFieldFocused = true
            }
        }
    }

    private func realityDisappearAnimation()
    {
        contentOpacity = 0
        headerScale = 0.8
        scrollViewOffset = 30
    }

    // MARK: - 标准环境动画（保持不变）

    private func standardAppearAnimation()
    {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8))
        {
            animationOffset = 0
            animationOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6)
        {
            isTextFieldFocused = true
        }
    }

    private func standardDisappearAnimation()
    {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9))
        {
            animationOffset = 400
            animationOpacity = 0
        }
    }

    // MARK: - 修复：添加打开AI助手窗口的方法

    private func openAIAssistantWindow()
    {
        if isRealityEnvironment
        {
            // Reality环境：打开独立窗口
            print("🤖 Reality模式下打开独立AI助手窗口")

            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAIAssistantWindow"),
                object: nil,
                userInfo: [
                    "question": question,
                    "mode": "reality",
                ]
            )

            openWindow(id: "AIAssistantWindow")
        }
        else
        {
            // 标准环境：显示嵌入式AI助手
            print("🤖 标准模式下显示嵌入式AI助手")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8))
            {
                showAIAssistant = true
            }
        }
    }

    // MARK: - 辅助方法（保持不变）

    private func handleSendReply()
    {
        let trimmedText = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty
        else
        {
            replyError = "回复内容不能为空"
            return
        }

        // 检查内容长度
        if trimmedText.count > 1000
        {
            replyError = "回复内容不能超过1000个字符"
            return
        }

        // 检查用户是否已登录
        guard let currentUserId = userManager.getUserId()
        else
        {
            replyError = "请先登录后再回复"
            return
        }

        // 如果有自定义的回调函数，优先使用
        if let onSendReply = onSendReply
        {
            onSendReply(trimmedText)
            replyText = ""

            // 🔥 添加：即使使用自定义回调，也发送通知让其他视图刷新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
            {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ReplySuccessReloadAnswers"),
                    object: nil,
                    userInfo: ["questionId": self.question.id]
                )
            }
            return
        }

        // 默认行为：发送到后端API
        print("💬 准备发送回复: \(trimmedText.prefix(50))...")

        // 重置错误状态
        replyError = nil
        isSendingReply = true

        Task
        {
            do
            {
                let response = try await NetworkManager.shared.sendAnswer(
                    questionId: question.id,
                    userId: currentUserId,
                    content: trimmedText
                )

                await MainActor.run
                {
                    self.isSendingReply = false

                    if response.success
                    {
                        print("✅ 回复发送成功")
                        self.replyText = ""
                        self.replyError = nil

                        // 🔥 关键修复：立即重新加载答案数据
                        self.loadQuestionAnswers()

                        // 发送通知给其他视图
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ReplySuccessReloadAnswers"),
                            object: nil,
                            userInfo: ["questionId": self.question.id]
                        )
                    }
                    else
                    {
                        self.replyError = response.message ?? "发送回复失败"
                    }
                }
            }
            catch let NetworkError.serverError(message)
            {
                await MainActor.run
                {
                    self.isSendingReply = false
                    self.replyError = message
                    print("❌ 发送回复服务器错误: \(message)")
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isSendingReply = false
                    self.replyError = "网络错误，请检查网络连接后重试"
                    print("❌ 发送回复网络错误: \(error)")
                }
            }
        }
    }

    private func loadQuestionAnswers()
    {
        // 重置状态
        isLoadingAnswers = true
        loadingError = nil
        questionAnswers = nil

        print("📄 开始加载问题答案: questionId=\(question.id)")

        Task
        {
            do
            {
                let answersResponse = try await NetworkManager.shared.getQuestionAnswer(question: question)

                await MainActor.run
                {
                    self.questionAnswers = answersResponse
                    self.isLoadingAnswers = false
                    self.loadingError = nil
                    print("✅ 成功加载问题答案: \(answersResponse.answerCount) 个答案")

                    // 打印详细的答案信息用于调试
                    for (index, answer) in answersResponse.answers.enumerated()
                    {
                        print("   答案 \(index + 1): \(answer.username) - \(answer.content.prefix(50))...")
                    }
                }
            }
            catch let NetworkError.serverError(message)
            {
                await MainActor.run
                {
                    self.isLoadingAnswers = false
                    self.loadingError = "服务器错误: \(message)"
                    print("❌ 加载问题答案失败 - 服务器错误: \(message)")
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoadingAnswers = false
                    self.loadingError = "加载失败: \(error.localizedDescription)"
                    print("❌ 加载问题答案失败: \(error)")
                }
            }
        }
    }
}

// MARK: - 可复用的问题消息视图组件

// 在 QuestionMessagesView 中添加请求管理

struct QuestionMessagesView: View
{
    let question: Question
    let isRealityEnvironment: Bool

    @EnvironmentObject var userManager: UserManager

    // 数据状态
    @State private var questionAnswers: getQuestionAnswerResponse?
    @State private var isLoadingAnswers: Bool = false
    @State private var loadingError: String?
    
    // ✅ 新增：管理异步任务
    @State private var loadTask: Task<Void, Never>?
    @State private var lastRefreshTime: Date = Date()

    var body: some View
    {
        ScrollViewReader
        { proxy in
            ScrollView
            {
                LazyVStack(alignment: .leading, spacing: isRealityEnvironment ? 16 : 12)
                {
                    if isLoadingAnswers
                    {
                        // 加载状态
                        VStack(spacing: 16)
                        {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("加载答案中...")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                    else if let error = loadingError
                    {
                        // 错误状态
                        VStack(spacing: 16)
                        {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                            Text("加载失败")
                                .font(.headline)
                            Text(error)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("重新加载")
                            {
                                loadQuestionAnswers()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                    else if let answersData = questionAnswers
                    {
                        // 显示问题和答案数据
                        
                        // 第一条消息：问题内容
                        HStack
                        {
                            VStack(alignment: .leading, spacing: 5)
                            {
                                HStack(spacing: 20)
                                {
                                    if let avatarUrl = question.avatarUrl, !avatarUrl.isEmpty
                                    {
                                        AsyncImage(url: URL(string: avatarUrl))
                                        { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 48))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                    }
                                    else
                                    {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(.gray)
                                            .frame(width: 48, height: 48)
                                    }
                                    Text(question.content)
                                        .font(.body)
                                        .padding(12)
                                        .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                                        .foregroundColor(.primary)
                                }

                                HStack(spacing: 5)
                                {
                                    Text(question.username ?? "未知用户")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatDate(question.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .id("firstMessage")

                        // 后续消息：所有答案
                        ForEach(Array(answersData.answers.enumerated()), id: \.offset)
                        { index, answer in
                            HStack
                            {
                                let currentUserId = userManager.getUserId() ?? -1
                                let isCurrentUser = answer.userId == currentUserId
                                let isQuestionAuthor = answer.userId == question.userID

                                if isCurrentUser
                                {
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 5)
                                    {
                                        HStack(spacing: 20)
                                        {
                                            Text(answer.content)
                                                .font(.body)
                                                .padding(12)
                                                .background(.blue.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                                                .foregroundColor(.white)
                                            if let avatarUrl = answer.avatarUrl, !avatarUrl.isEmpty
                                            {
                                                AsyncImage(url: URL(string: avatarUrl))
                                                { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Image(systemName: "person.circle.fill")
                                                        .font(.system(size: 48))
                                                        .foregroundColor(.gray)
                                                }
                                                .frame(width: 48, height: 48)
                                                .clipShape(Circle())
                                            }
                                            else
                                            {
                                                Image(systemName: "person.circle.fill")
                                                    .font(.system(size: 48))
                                                    .foregroundColor(.gray)
                                                    .frame(width: 48, height: 48)
                                            }
                                        }
                                        HStack(spacing: 5)
                                        {
                                            Text(answer.username)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text("•")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(formatAnswerDate(answer.createdAt))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                else
                                {
                                    VStack(alignment: .leading, spacing: 5)
                                    {
                                        HStack(spacing: 20)
                                        {
                                            if let avatarUrl = answer.avatarUrl, !avatarUrl.isEmpty
                                            {
                                                AsyncImage(url: URL(string: avatarUrl))
                                                { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Image(systemName: "person.circle.fill")
                                                        .font(.system(size: 48))
                                                        .foregroundColor(.gray)
                                                }
                                                .frame(width: 48, height: 48)
                                                .clipShape(Circle())
                                            }
                                            else
                                            {
                                                Image(systemName: "person.circle.fill")
                                                    .font(.system(size: 48))
                                                    .foregroundColor(.gray)
                                                    .frame(width: 48, height: 48)
                                            }

                                            Text(answer.content)
                                                .font(.body)
                                                .padding(12)
                                                .background(
                                                    isQuestionAuthor ?
                                                        Color.orange.opacity(0.2) :
                                                        Color.gray.opacity(0.2),
                                                    in: RoundedRectangle(cornerRadius: 16)
                                                )
                                                .foregroundColor(.primary)
                                        }
                                        HStack(spacing: 5)
                                        {
                                            Text(answer.username)
                                                .font(.caption2)
                                                .foregroundColor(isQuestionAuthor ? .orange : .secondary)
                                            Text("•")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(formatAnswerDate(answer.createdAt))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .id("answer_\(index)")
                        }

                        // 如果没有答案，显示提示
                        if answersData.answers.isEmpty
                        {
                            VStack(spacing: 16)
                            {
                                Image(systemName: "questionmark.bubble")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("还没有人回答这个问题")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                Text("成为第一个回答的人吧!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .id("emptyState")
                        }
                    }

                    // 底部安全区域
                    Spacer()
                        .frame(height: isRealityEnvironment ? 160 : 120)
                        .id("bottomSpacer")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .onChange(of: questionAnswers?.answers.count)
                { _ in
                    withAnimation(.easeOut(duration: 0.5))
                    {
                        proxy.scrollTo("bottomSpacer", anchor: .bottom)
                    }
                }
            }
            .refreshable
            {
                await refreshAnswers()
            }
            .onAppear
            {
                print("📱 消息视图已出现，开始加载问题答案")
                if questionAnswers == nil && !isLoadingAnswers
                {
                    loadQuestionAnswers()
                }
            }
            .onDisappear
            {
                // ✅ 清理：视图消失时取消正在进行的任务
                loadTask?.cancel()
                loadTask = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceRefreshMessages")))
            { notification in
                if let questionId = notification.userInfo?["questionId"] as? Int64,
                   questionId == question.id
                {
                    print("强制刷新消息列表")
                    self.loadQuestionAnswers()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReplySuccessReloadAnswers")))
            { notification in
                if let questionId = notification.userInfo?["questionId"] as? Int64,
                   questionId == question.id
                {
                    print("📱 收到回复成功通知，重新加载答案 - questionId: \(questionId)")

                    // 延迟一小段时间再刷新，确保后端数据已经更新
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)
                    {
                        self.loadQuestionAnswers()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReplyFailed")))
            { notification in
                if let error = notification.userInfo?["error"] as? String
                {
                    print("❌ 收到回复失败通知: \(error)")
                    DispatchQueue.main.async
                    {
                        self.loadingError = error
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification))
            { _ in
                print("📱 应用进入前台，刷新消息数据")
                if !isLoadingAnswers
                {
                    loadQuestionAnswers()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WindowDidBecomeKey")))
            { _ in
                print("📱 窗口获得焦点，刷新消息数据")
                if !isLoadingAnswers
                {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
                    {
                        self.loadQuestionAnswers()
                    }
                }
            }
        }
    }

    // ✅ 改进的刷新方法 - 添加防抖和请求管理
    @MainActor
    private func refreshAnswers() async
    {
        // 1. 防抖：如果距离上次刷新不到1秒，忽略
        let now = Date()
        if now.timeIntervalSince(lastRefreshTime) < 1.0 {
            print("⏱️ 刷新过于频繁，忽略此次请求")
            return
        }
        lastRefreshTime = now
        
        // 2. 如果正在加载，不要重复请求
        guard !isLoadingAnswers else {
            print("⏳ 已有请求进行中，忽略重复刷新")
            return
        }

        print("🔄 用户下拉刷新消息数据")

        // 3. 取消之前的任务
        loadTask?.cancel()
        
        isLoadingAnswers = true
        loadingError = nil

        // 4. 创建新的任务
        loadTask = Task {
            do
            {
                // 检查任务是否被取消
                try Task.checkCancellation()
                
                let answersResponse = try await NetworkManager.shared.getQuestionAnswer(question: question)

                // 再次检查任务是否被取消
                try Task.checkCancellation()
                
                // 更新UI必须在主线程
                await MainActor.run {
                    self.questionAnswers = answersResponse
                    self.isLoadingAnswers = false
                    self.loadingError = nil
                    print("✅ 下拉刷新成功加载问题答案: \(answersResponse.answerCount) 个答案")
                }
            }
            catch is CancellationError
            {
                // 任务被取消，正常情况，不显示错误
                print("🔄 刷新任务被取消")
                await MainActor.run {
                    self.isLoadingAnswers = false
                }
            }
            catch let NetworkError.serverError(message)
            {
                await MainActor.run {
                    self.isLoadingAnswers = false
                    self.loadingError = "服务器错误: \(message)"
                    print("❌ 下拉刷新加载问题答案失败 - 服务器错误: \(message)")
                }
            }
            catch
            {
                await MainActor.run {
                    self.isLoadingAnswers = false
                    self.loadingError = "加载失败: \(error.localizedDescription)"
                    print("❌ 下拉刷新加载问题答案失败: \(error)")
                }
            }
        }
        
        // 等待任务完成
        await loadTask?.value
    }

    // ✅ 改进的加载方法 - 添加请求管理
    private func loadQuestionAnswers()
    {
        // 1. 如果正在加载，不要重复请求
        guard !isLoadingAnswers else {
            print("⏳ 已有加载任务进行中，忽略重复请求")
            return
        }
        
        // 2. 取消之前的任务
        loadTask?.cancel()
        
        isLoadingAnswers = true
        loadingError = nil
        questionAnswers = nil

        print("📄 开始加载问题答案: questionId=\(question.id)")

        // 3. 创建新的任务
        loadTask = Task
        {
            do
            {
                // 检查任务是否被取消
                try Task.checkCancellation()
                
                let answersResponse = try await NetworkManager.shared.getQuestionAnswer(question: question)

                // 再次检查任务是否被取消
                try Task.checkCancellation()
                
                await MainActor.run
                {
                    self.questionAnswers = answersResponse
                    self.isLoadingAnswers = false
                    self.loadingError = nil
                    print("✅ 成功加载问题答案: \(answersResponse.answerCount) 个答案")
                }
            }
            catch is CancellationError
            {
                // 任务被取消，正常情况，不显示错误
                print("🔄 加载任务被取消")
                await MainActor.run
                {
                    self.isLoadingAnswers = false
                }
            }
            catch let NetworkError.serverError(message)
            {
                await MainActor.run
                {
                    self.isLoadingAnswers = false
                    self.loadingError = "服务器错误: \(message)"
                    print("❌ 加载问题答案失败 - 服务器错误: \(message)")
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoadingAnswers = false
                    self.loadingError = "加载失败: \(error.localizedDescription)"
                    print("❌ 加载问题答案失败: \(error)")
                }
            }
        }
    }
}

// MARK: - 便捷构造器扩展

extension QuestionDetailModal
{
    // 更新现有的便捷构造器，确保它们仍然正常工作
    static func forReality(
        question: Question,
        isPresented: Binding<Bool>,
        onClose: @escaping () -> Void,
        onSendReply: ((String) -> Void)? = nil
    ) -> QuestionDetailModal
    {
        QuestionDetailModal(
            question: question,
            isPresented: isPresented,
            onClose: onClose,
            onSendReply: onSendReply,
            isRealityEnvironment: true
        )
    }

    static func standard(
        question: Question,
        isPresented: Binding<Bool>,
        onClose: @escaping () -> Void,
        onSendReply: ((String) -> Void)? = nil,
        onAttachFile: (() -> Void)? = nil
    ) -> QuestionDetailModal
    {
        QuestionDetailModal(
            question: question,
            isPresented: isPresented,
            onClose: onClose,
            onSendReply: onSendReply,
            onAttachFile: onAttachFile,
            isRealityEnvironment: false
        )
    }
}

// MARK: - 通用地图组件

struct MapView: UIViewRepresentable
{
    // 数据
    var mapItems: [MKMapItem]
    var defaultMapItem: MKMapItem?

    // 绑定
    @Binding var regionSpan: Double
    @Binding var selectedMapItem: MKMapItem?

    // 配置
    var markerColor: UIColor = .systemBlue
    var enableSelection: Bool = true
    var centerOffset: CGFloat = 0 // 正值向右偏移，负值向左偏移
    var showPopup: Binding<Bool>? = nil
    var onAnnotationSelected: ((MKMapItem) -> Void)? = nil
    var onRegionChange: (() -> Void)? = nil

    func makeUIView(context: Context) -> MKMapView
    {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context)
    {
        // 清除现有标注
        view.removeAnnotations(view.annotations.filter { !($0 is MKUserLocation) })

        // 添加搜索结果的标注
        for item in mapItems
        {
            let annotation = ReusableAnnotation()
            annotation.title = item.name
            annotation.coordinate = item.placemark.coordinate
            annotation.mapItem = item
            view.addAnnotation(annotation)
        }

        // 设置地图区域
        var centerCoordinate: CLLocationCoordinate2D?

        if let firstItem = mapItems.first
        {
            centerCoordinate = firstItem.placemark.coordinate
        }
        else if let defaultMapItem = defaultMapItem
        {
            // 添加默认位置标注
            let annotation = ReusableAnnotation()
            annotation.title = defaultMapItem.name
            annotation.coordinate = defaultMapItem.placemark.coordinate
            annotation.mapItem = defaultMapItem
            view.addAnnotation(annotation)

            centerCoordinate = defaultMapItem.placemark.coordinate
        }

        if let center = centerCoordinate
        {
            // 应用中心点偏移
            var adjustedCenter = center
            if centerOffset != 0
            {
                let offsetRatio = centerOffset / view.bounds.width
                let longitudeOffset = regionSpan * 0.000001 * offsetRatio
                adjustedCenter.longitude += longitudeOffset
            }

            let region = MKCoordinateRegion(
                center: adjustedCenter,
                latitudinalMeters: regionSpan,
                longitudinalMeters: regionSpan
            )
            view.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator
    {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate
    {
        var parent: MapView

        init(_ parent: MapView)
        {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
        {
            if annotation is MKUserLocation
            {
                return nil
            }

            let identifier = "ReusablePin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil
            {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false

                // 创建自定义标记
                let size: CGFloat = 28
                let circleView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circleView.backgroundColor = .clear
                circleView.layer.cornerRadius = size / 2
                circleView.layer.borderColor = UIColor.white.cgColor
                circleView.layer.borderWidth = 3
                circleView.layer.backgroundColor = parent.markerColor.cgColor

                annotationView?.frame = CGRect(x: 0, y: 0, width: size, height: size)
                annotationView?.addSubview(circleView)
            }
            else
            {
                annotationView?.annotation = annotation
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView)
        {
            guard parent.enableSelection,
                  let reusableAnnotation = view.annotation as? ReusableAnnotation,
                  let mapItem = reusableAnnotation.mapItem
            else
            {
                return
            }

            // 处理中心点偏移
            if parent.centerOffset != 0
            {
                var offsetCoordinate = reusableAnnotation.coordinate
                let offsetRatio = parent.centerOffset / mapView.bounds.width
                let region = mapView.region
                let longitudeOffset = region.span.longitudeDelta * offsetRatio
                offsetCoordinate.longitude += longitudeOffset

                let newRegion = MKCoordinateRegion(
                    center: offsetCoordinate,
                    span: region.span
                )
                mapView.setRegion(newRegion, animated: true)
            }

            // 更新状态
            DispatchQueue.main.async
            {
                self.parent.selectedMapItem = mapItem
                self.parent.onAnnotationSelected?(mapItem)

                if let showPopupBinding = self.parent.showPopup
                {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
                    {
                        showPopupBinding.wrappedValue = true
                    }
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool)
        {
            // 如果有弹窗显示，关闭它
            if let showPopupBinding = parent.showPopup, showPopupBinding.wrappedValue
            {
                DispatchQueue.main.async
                {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
                    {
                        showPopupBinding.wrappedValue = false
                    }
                }
            }

            parent.onRegionChange?()
        }
    }
}

// MARK: - 自定义标注类

class ReusableAnnotation: NSObject, MKAnnotation
{
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var title: String?
    var subtitle: String?
    var mapItem: MKMapItem?
}

// MARK: - 地图配置枚举

enum MapMarkerColor
{
    case blue
    case orange
    case green
    case red
    case purple

    var uiColor: UIColor
    {
        switch self
        {
        case .blue: return .systemBlue
        case .orange: return .systemOrange
        case .green: return .systemGreen
        case .red: return .systemRed
        case .purple: return .systemPurple
        }
    }
}

// MARK: - 可复用的问题卡片组件

struct QuestionCard: View
{
    // MARK: - 必需参数

    let question: Question
    let onSelect: () -> Void

    // MARK: - 可选配置参数

    var showLocationTag: Bool = true
    var showDate: Bool = true
    var showAvatar: Bool = true
    var showLikeButton: Bool = true
    var cardHeight: CGFloat = 240
    var cornerRadius: CGFloat = 32
    var padding: CGFloat = 20
    var avatarSize: CGFloat = 64
    var primaryColor: Color = .orange

    // MARK: - 自定义回调

    var onLike: (() -> Void)?
    var onAvatarTap: (() -> Void)?

    // MARK: - 内部状态

    @State private var isHovered = false
    @State private var isLiked = false

    var body: some View
    {
        VStack(spacing: 10)
        {
            // 问题头部信息
            if showLocationTag || showDate
            {
                HStack
                {
                    if showLocationTag
                    {
                        Text(question.actualPlace)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(Color.white)
                    }

                    Spacer()

                    if showDate
                    {
                        Text(formatDate(question.updatedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 问题内容区域
            HStack(alignment: .top)
            {
                VStack(alignment: .leading, spacing: 10)
                {
                    Text(question.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(question.content)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // 用户头像（使用真实头像）
                if showAvatar
                {
                    Button(action: {
                        onAvatarTap?()
                    })
                    {
                        Group
                        {
                            if let avatarUrl = question.avatarUrl,
                               !avatarUrl.isEmpty,
                               !avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            {
                                AsyncImage(url: URL(string: avatarUrl))
                                { phase in
                                    switch phase
                                    {
                                    case let .success(image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure:
                                        // 加载失败时显示默认头像
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: avatarSize))
                                            .foregroundColor(.gray)
                                    case .empty:
                                        // 加载中显示占位符
                                        ProgressView()
                                            .frame(width: avatarSize, height: avatarSize)
                                    @unknown default:
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: avatarSize))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            else
                            {
                                // 没有头像URL时显示默认头像
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: avatarSize))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(onAvatarTap == nil)
                }
            }

            Spacer()

            // 操作按钮区域 - 保持原有逻辑不变
            HStack(spacing: 12)
            {
                // 点赞按钮（可选）
                if showLikeButton
                {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2))
                        {
                            isLiked.toggle()
                        }
                        onLike?()
                    })
                    {
                        HStack(spacing: 4)
                        {
                            Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.caption)
                                .foregroundColor(isLiked ? primaryColor : .primary)
                            Text("+1")
                                .foregroundColor(isLiked ? primaryColor : .primary)
                        }
                        .frame(maxWidth: 60)
                    }
                    .frame(height: 36)
                    .buttonStyle(.bordered)
                    .scaleEffect(isLiked ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                }

                Spacer()

                // 查看详情按钮
                Button(action: onSelect)
                {
                    HStack(spacing: 6)
                    {
                        Image(systemName: "arrowshape.turn.up.left.circle")
                            .font(.caption)
                        Text("\(question.replyCount)")
                        Spacer()
                        Text("查看详情")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: showLikeButton ? 130 : .infinity)
                }
                .frame(height: 36)
                .buttonStyle(.borderedProminent)
                .tint(primaryColor)
            }
        }
        .padding(padding)
        .frame(height: cardHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isHovered ? primaryColor.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover
        { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 扩展：预设样式

extension QuestionCard
{
    // 紧凑样式 - 适用于侧边栏
    static func compact(
        question: Question,
        onSelect: @escaping () -> Void,
        onLike: (() -> Void)? = nil
    ) -> QuestionCard
    {
        QuestionCard(
            question: question,
            onSelect: onSelect,
            showLocationTag: true,
            showDate: false,
            showAvatar: true,
            showLikeButton: true,
            cardHeight: 180,
            cornerRadius: 32,
            padding: 16,
            avatarSize: 48,
            onLike: onLike
        )
    }

    // 详细样式 - 适用于主列表
    static func detailed(
        question: Question,
        onSelect: @escaping () -> Void,
        onLike: (() -> Void)? = nil,
        onAvatarTap: (() -> Void)? = nil
    ) -> QuestionCard
    {
        QuestionCard(
            question: question,
            onSelect: onSelect,
            showLocationTag: true,
            showDate: true,
            showAvatar: true,
            showLikeButton: true,
            cardHeight: 240,
            cornerRadius: 32,
            padding: 20,
            avatarSize: 64,
            onLike: onLike,
            onAvatarTap: onAvatarTap
        )
    }

    // 简洁样式 - 适用于搜索结果
    static func minimal(
        question: Question,
        onSelect: @escaping () -> Void
    ) -> QuestionCard
    {
        QuestionCard(
            question: question,
            onSelect: onSelect,
            showLocationTag: false,
            showDate: true,
            showAvatar: false,
            showLikeButton: false,
            cardHeight: 120,
            cornerRadius: 12,
            padding: 12,
            primaryColor: .blue
        )
    }

    // 自定义尺寸
    func sized(height: CGFloat, cornerRadius: CGFloat = 24) -> QuestionCard
    {
        var card = self
        card.cardHeight = height
        card.cornerRadius = cornerRadius
        return card
    }
}

struct AddressSearchField: View
{
    @Binding var searchText: String
    @Binding var selectedMapItem: MKMapItem?
    let placeholder: String
    let onLocationSelected: (MKMapItem) -> Void

    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @FocusState private var isFocused: Bool

    // ✅ 防抖相关
    @State private var searchTask: Task<Void, Never>?
    @State private var currentSearch: MKLocalSearch?

    var body: some View
    {
        VStack(alignment: .leading, spacing: 0)
        {
            // ✅ 使用HStack正确布局图标和输入框
            HStack(spacing: 8)
            {
                // 搜索图标
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)

                // 输入框
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onChange(of: searchText)
                    { newValue in
                        // ✅ 取消之前的搜索任务
                        searchTask?.cancel()
                        currentSearch?.cancel()

                        // ✅ 如果输入为空，清空结果
                        if newValue.isEmpty
                        {
                            searchResults = []
                            isSearching = false
                            return
                        }

                        // ✅ 如果输入少于2个字符，不搜索
                        if newValue.count < 2
                        {
                            searchResults = []
                            return
                        }

                        // ✅ 防抖：延迟0.5秒后执行搜索
                        searchTask = Task
                        {
                            isSearching = true
                            try? await Task.sleep(nanoseconds: 500000000) // 0.5秒

                            // 检查任务是否被取消
                            if !Task.isCancelled
                            {
                                await performSearch(query: newValue)
                            }
                        }
                    }

                // 清除按钮
                if !searchText.isEmpty
                {
                    Button(action: {
                        // ✅ 取消搜索任务
                        searchTask?.cancel()
                        currentSearch?.cancel()

                        searchText = ""
                        searchResults = []
                        selectedMapItem = nil
                        isSearching = false
                    })
                    {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                            .frame(width: 64,height: 64)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                    .buttonBorderShape(.circle)  // 添加圆形边框
                    .hoverEffect(.highlight)
                }

                // 加载指示器
                if isSearching
                {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .cornerRadius(12)
            .onDisappear
            {
                // ✅ 清理资源
                searchTask?.cancel()
                currentSearch?.cancel()
            }

            // ✅ 搜索结果列表 - 选择后自动隐藏
            if !searchResults.isEmpty && !searchText.isEmpty && isFocused
            {
                VStack(alignment: .leading, spacing: 0)
                {
                    ForEach(searchResults, id: \.self)
                    { item in
                        Button(action: {
                            // ✅ 选择后立即执行所有操作
                            selectAddress(item)
                        })
                        {
                            VStack(alignment: .leading, spacing: 4)
                            {
                                Text(item.name ?? "未知地点")
                                    .font(.body)
                                    .foregroundColor(.primary)

                                if let address = formatAddress(item.placemark)
                                {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .background(Color.clear)
                        .hoverEffect(.highlight)

                        if item != searchResults.last
                        {
                            Divider()
                        }
                    }
                }
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
    }

    // ✅ 选择地址的统一处理
    private func selectAddress(_ item: MKMapItem)
    {
        print("✅ AddressSearchField: 用户选择了地址 - \(item.name ?? "未知")")

        // ✅ 取消所有搜索任务
        searchTask?.cancel()
        currentSearch?.cancel()

        // 更新显示文本
        searchText = item.name ?? ""

        // 更新选中的地点
        selectedMapItem = item

        // 清空搜索结果（关键：选择后立即隐藏列表）
        searchResults = []
        isSearching = false

        // 移除焦点（也会隐藏列表）
        isFocused = false

        // 触发回调
        onLocationSelected(item)
    }

    // ✅ 修改为异步方法
    private func performSearch(query: String) async
    {
        print("🔍 执行搜索: \(query)")

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        // 可以添加区域限制，提高搜索准确性
        // request.region = ...

        let search = MKLocalSearch(request: request)
        currentSearch = search

        do
        {
            let response = try await search.start()

            // 检查任务是否被取消
            guard !Task.isCancelled
            else
            {
                await MainActor.run
                {
                    isSearching = false
                }
                return
            }

            await MainActor.run
            {
                self.searchResults = response.mapItems
                self.isSearching = false
                print("✅ 搜索完成: \(self.searchResults.count) 个结果")
            }
        }
        catch
        {
            // 检查是否是取消错误
            if (error as NSError).code != NSUserCancelledError
            {
                print("❌ 搜索错误: \(error.localizedDescription)")
            }

            await MainActor.run
            {
                self.searchResults = []
                self.isSearching = false
            }
        }
    }

    private func formatAddress(_ placemark: MKPlacemark) -> String?
    {
        var components: [String] = []

        if let subLocality = placemark.subLocality
        {
            components.append(subLocality)
        }
        if let locality = placemark.locality
        {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea
        {
            components.append(administrativeArea)
        }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

// MARK: - 搜索结果行组件

struct AddressSearchResultRow: View
{
    let mapItem: MKMapItem
    let onSelect: () -> Void

    var body: some View
    {
        Button(action: onSelect)
        {
            HStack(spacing: 12)
            {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2)
                {
                    if let name = mapItem.name
                    {
                        Text(name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    if let address = mapItem.placemark.title
                    {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

// MARK: - 更新后的ExploreView搜索栏

struct ExploreSearchBar: View
{
    @Binding var searchText: String
    @Binding var isLoading: Bool
    let onLocationSelected: ((MKMapItem) -> Void)?
    let onManualSearch: (() -> Void)?

    @State private var selectedSearchMapItem: MKMapItem?

    var body: some View
    {
        HStack
        {
            // 使用改进的地址搜索组件
            AddressSearchField(
                searchText: $searchText,
                selectedMapItem: $selectedSearchMapItem,
                placeholder: "    搜索场所或地址...",
                onLocationSelected: { mapItem in
                    onLocationSelected?(mapItem)
                }
            )
            .frame(width: 600)
            .cornerRadius(24)

            // 手动搜索按钮（可选保留）
            if isLoading
            {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 44, height: 44)
            }
        }
    }
}

// MARK: - 颜色选择弹窗

struct ColorPickerView: View
{
    @Binding var selectedColor: Color
    @Environment(\.dismiss) var dismiss

    var body: some View
    {
        NavigationStack
        {
            VStack(spacing: 30)
            {
                Text("选择模型颜色")
                    .font(.title2)
                    .fontWeight(.semibold)

                // 颜色预览
                RoundedRectangle(cornerRadius: 20)
                    .fill(selectedColor)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    )
                    .padding(.horizontal)

                // 颜色选择器
                ColorPicker("选择颜色", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(maxWidth: 300)

                Spacer()
            }
            .padding()
            .navigationTitle("自定义颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .navigationBarLeading)
                {
                    Button("取消")
                    {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing)
                {
                    Button("确定")
                    {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 颜色按钮组件

struct ColorButton: View
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
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.5), lineWidth: isSelected ? 3 : 1)
                )
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

