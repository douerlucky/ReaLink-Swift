import SwiftUI
import ARKit

// MARK: - 保留原有的数据结构

struct QuestionDraftData
{
    let location: String
    let specificPlace: String
    let title: String
    let content: String
    let latitude: Double?
    let longitude: Double?
}

// MARK: - AI助手核心逻辑类

class AIAssistantCore: ObservableObject
{
    enum AIAssistantType
    {
        case explore(question: Question)
        case questionDraft(data: QuestionDraftData)
    }

    @Published var messages: [AIChatMessage] = []
    @Published var inputText = ""
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var isLoadingSummary = false
    @Published var isLoadingSmartSuggestion = false
    @Published var isLoadingRelatedSearch = false

    @Published var selectedRegion: SelectionRegion?
    @Published var sceneRecognitionState: SceneRecognitionState = .idle

    var type: AIAssistantType
    private var hasInitialized = false

    init(type: AIAssistantType)
    {
        self.type = type
    }

    // MARK: - 核心方法

    @MainActor func initializeIfNeeded()
    {
        guard !hasInitialized else { return }
        hasInitialized = true

        switch type
        {
        case .explore:
            loadConversationHistory()
        case .questionDraft:
            break
        }
    }

    @MainActor func sendMessage()
    {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }

        let newUserMessage = AIChatMessage(
            content: userMessage,
            isUser: true,
            timestamp: Date()
        )
        messages.append(newUserMessage)

        inputText = ""
        isSending = true
        errorMessage = nil

        switch type
        {
        case let .explore(question):
            sendExploreMessage(userMessage, question: question)
        case let .questionDraft(data):
            sendQuestionDraftMessage(userMessage, data: data)
        }
    }

    @MainActor func sendQuickMessage(_ message: String)
    {
        inputText = message
        sendMessage()
    }

    func requestConversationSummary()
    {
        guard case let .explore(question) = type else { return }

        isLoadingSummary = true
        errorMessage = nil

        Task
        {
            do
            {
                let summary = try await NetworkManager.shared.getQuestionSummary(questionId: question.id)

                await MainActor.run
                {
                    let summaryMessage = AIChatMessage(
                        content: summary,
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(summaryMessage)
                    self.isLoadingSummary = false
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoadingSummary = false
                    self.errorMessage = "获取对话总结失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func requestSmartSuggestion()
    {
        guard case let .questionDraft(data) = type else { return }

        isLoadingSmartSuggestion = true
        errorMessage = nil

        Task
        {
            do
            {
                let response = try await NetworkManager.shared.getQuestionSmartSuggestion(
                    location: data.location,
                    specificPlace: data.specificPlace,
                    title: data.title,
                    content: data.content
                )

                await MainActor.run
                {
                    let suggestionMessage = AIChatMessage(
                        content: response.suggestion,
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(suggestionMessage)
                    self.isLoadingSmartSuggestion = false
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoadingSmartSuggestion = false
                    self.errorMessage = "获取智能建议失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func requestRelatedSearch()
    {
        guard case let .questionDraft(data) = type else { return }

        guard let latitude = data.latitude,
              let longitude = data.longitude
        else
        {
            errorMessage = "缺少位置坐标信息，无法搜索相关问题"
            return
        }

        isLoadingRelatedSearch = true
        errorMessage = nil

        Task
        {
            do
            {
                let response = try await NetworkManager.shared.getRelatedQuestionsSummary(
                    location: data.location,
                    latitude: latitude,
                    longitude: longitude,
                    title: data.title,
                    content: data.content
                )

                await MainActor.run
                {
                    let searchMessage = AIChatMessage(
                        content: response.summary,
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(searchMessage)
                    self.isLoadingRelatedSearch = false
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoadingRelatedSearch = false
                    self.errorMessage = "搜索相关问题失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func clearError()
    {
        errorMessage = nil
    }

    // MARK: - 计算属性

    var headerIcon: String
    {
        return "sparkles"
    }

    var headerTitle: String
    {
        switch type
        {
        case .explore: return "AI 智能助手"
        case .questionDraft: return "AI 智能提问助手"
        }
    }

    var headerColor: Color
    {
        switch type
        {
        case .explore: return .purple
        case .questionDraft: return .blue
        }
    }

    var headerSubtitle: String?
    {
        switch type
        {
        case .explore: return nil
        case .questionDraft: return "AI帮您优化问题"
        }
    }

    var welcomeMessage: String
    {
        switch type
        {
        case let .explore(question):
            return "我可以帮你分析问题「\(question.title)」，位于\(question.actualPlace)"
        case let .questionDraft(data):
            return "我会根据您输入的问题内容，提供专业的提问建议，帮您修正语言表达，让问题更清晰明确。"
        }
    }

    var loadingText: String
    {
        if isLoadingSummary { return "正在总结对话..." }
        if isLoadingSmartSuggestion { return "正在生成智能建议..." }
        if isLoadingRelatedSearch { return "正在搜索相关问题..." }
        return "AI正在思考..."
    }

    var isLoading: Bool
    {
        return isSending || isLoadingSummary || isLoadingSmartSuggestion || isLoadingRelatedSearch
    }

    // MARK: - 私有方法

    @MainActor private func loadConversationHistory()
    {
        guard case let .explore(question) = type else { return }

        let currentUserId = UserManager.shared.getUserId() ?? 0
        guard currentUserId > 0
        else
        {
            print("🤖 用户未登录，跳过加载对话历史")
            return
        }

        Task
        {
            do
            {
                let historyMessages = try await NetworkManager.shared.getAIConversationHistory(
                    questionId: question.id,
                    userId: currentUserId
                )

                await MainActor.run
                {
                    if !historyMessages.isEmpty
                    {
                        self.messages = historyMessages
                        print("🤖 加载了 \(historyMessages.count) 条历史消息")
                    }
                }
            }
            catch
            {
                print("🤖 加载对话历史失败: \(error)")
            }
        }
    }

    @MainActor private func sendExploreMessage(_ message: String, question: Question)
    {
        let currentUserId = UserManager.shared.getUserId() ?? 0

        let context = """
        用户正在查看问题：
        标题：\(question.title)
        内容：\(question.content)
        地点：\(question.actualPlace)
        提问者：\(question.username ?? "匿名用户")
        提问时间：\(question.createdAt)
        回复数：\(question.replyCount)
        状态：\(question.status)

        地理位置详细信息：
        - 具体地点：\(question.actualPlace)
        - 这是一个真实的地理位置，请在回答时考虑这个地点的特色、环境、交通、周边设施等相关信息
        - 如果用户询问相关地点信息，请提供实用的本地化建议

        请用简洁、实用的中文回答用户的问题。
        """

        Task
        {
            await sendToAI(
                message: message,
                context: context,
                questionId: question.id,
                userId: currentUserId
            )
        }
    }

    private func sendQuestionDraftMessage(_ message: String, data: QuestionDraftData)
    {
        let context = """
        用户问题信息：
        地点：\(data.location)
        具体位置：\(data.specificPlace)
        问题标题：\(data.title)
        问题内容：\(data.content)

        助手类型：AI智能提问助手
        """

        Task
        {
            do
            {
                let response = try await NetworkManager.shared.sendQuestionAIFollowUp(
                    message: message,
                    context: context
                )

                await MainActor.run
                {
                    let aiMessage = AIChatMessage(
                        content: response.content,
                        isUser: false,
                        timestamp: Date()
                    )

                    self.messages.append(aiMessage)
                    self.isSending = false
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isSending = false
                    self.errorMessage = "发送消息失败: \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func sendToAI(
        message: String,
        context: String,
        questionId: Int64,
        userId: Int64
    ) async
    {
        do
        {
            let response = try await NetworkManager.shared.sendAIMessage(
                message: message,
                context: context,
                conversationId: "question_\(questionId)_user_\(userId)",
                questionId: questionId,
                userId: userId
            )

            let aiMessage = AIChatMessage(
                content: response.content,
                isUser: false,
                timestamp: Date()
            )

            messages.append(aiMessage)
            isSending = false

            print("🤖 AI消息发送成功，已保存到对话历史")
        }
        catch
        {
            isSending = false
            errorMessage = "发送失败：\(error.localizedDescription)"
            print("🤖 AI消息发送失败: \(error)")
        }
    }
}

// MARK: - 快捷操作按钮组件

struct QuickActionButton: View
{
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View
    {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1))
            {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
            {
                withAnimation(.easeInOut(duration: 0.1))
                {
                    isPressed = false
                }
                action()
            }
        })
        {
            HStack(spacing: 6)
            {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        color,
                        color.opacity(0.8),
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: color.opacity(0.3), radius: isPressed ? 1 : 3, x: 0, y: isPressed ? 1 : 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 聊天气泡组件

struct ChatBubbleCompact: View
{
    let message: AIChatMessage

    var body: some View
    {
        HStack
        {
            if message.isUser
            {
                Spacer()
                VStack(alignment: .trailing, spacing: 2)
                {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            else
            {
                VStack(alignment: .leading, spacing: 2)
                {
                    HStack(spacing: 6)
                    {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text("AI")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Spacer()
                    }

                    Group
                    {
                        if let attributedString = try? AttributedString(markdown: message.content)
                        {
                            Text(attributedString)
                                .padding()
                                .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.primary)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil) // Allow unlimited lines
                                .fixedSize(horizontal: false, vertical: true) // Enable wrapping
                        }
                        else
                        {
                            Text(message.content)
                                .padding()
                                .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.primary)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil) // Allow unlimited lines
                                .fixedSize(horizontal: false, vertical: true) // Enable wrapping
                        }
                    }

                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    private func formatTime(_ date: Date) -> String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct MarkdownTextView: UIViewRepresentable
{
    var markdown: String

    func makeUIView(context: Context) -> UITextView
    {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context)
    {
        if let data = markdown.data(using: .utf8)
        {
            if let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
            )
            {
                uiView.attributedText = attributedString
            }
        }
    }
}

// MARK: - AI助手核心内容组件

struct AIAssistantContent: View
{
    @ObservedObject var core: AIAssistantCore
    @FocusState var isTextFieldFocused: Bool

    @Binding var selectedRegion: SelectionRegion?
    @Binding var sceneRecognitionState: SceneRecognitionState
    var onSendSceneRecognition: ((SelectionRegion, String) -> Void)?

    var body: some View
    {
        VStack(spacing: 0)
        {
            // 消息列表
            messagesListView

            // 快捷操作区域
            if case .explore = core.type
            {
                quickActionsSection
            }
            else
            {
                questionDraftActionsSection
            }

            // 输入区域
            inputView
        }
    }

    private var messagesListView: some View
    {
        ScrollView
        {
            ScrollViewReader
            { proxy in
                LazyVStack(alignment: .leading, spacing: 12)
                {
                    // 欢迎消息
                    if core.messages.isEmpty
                    {
                        welcomeMessageView
                    }

                    // 聊天消息
                    ForEach(core.messages)
                    { message in
                        ChatBubbleCompact(message: message)
                            .id(message.id)
                    }

                    // 加载指示器
                    if core.isLoading
                    {
                        HStack
                        {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(core.loadingText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .onChange(of: core.messages.count)
                { _ in
                    if let lastMessage = core.messages.last
                    {
                        withAnimation(.easeOut(duration: 0.3))
                        {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private var welcomeMessageView: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack
            {
                Image(systemName: core.headerIcon)
                    .font(.title2)
                    .foregroundColor(core.headerColor)
                Text(core.headerTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Text(core.welcomeMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
        }
        .padding(16)
        .background(core.headerColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var quickActionsSection: some View
    {
        VStack(spacing: 0)
        {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false)
            {
                HStack(spacing: 12)
                {
                    if case let .explore(question) = core.type
                    {
                        QuickActionButton(
                            icon: "lightbulb.fill",
                            title: "分析问题",
                            color: .purple
                        )
                        {
                            core.sendQuickMessage("请帮我分析一下这个问题：\(question.title) - \(question.content)")
                        }

                        QuickActionButton(
                            icon: "list.bullet.clipboard.fill",
                            title: "总结对话",
                            color: .blue
                        )
                        {
                            core.requestConversationSummary()
                        }

                        QuickActionButton(
                            icon: "map.fill",
                            title: "了解地点",
                            color: .green
                        )
                        {
                            core.sendQuickMessage("告诉我关于\(question.actualPlace)这个地方的详细信息，包括特色、交通、周边设施等")
                        }

                        QuickActionButton(
                            icon: "questionmark.circle.fill",
                            title: "相关建议",
                            color: .orange
                        )
                        {
                            core.sendQuickMessage("基于这个问题，给我一些相关的建议和解决方案")
                        }

                        QuickActionButton(
                            icon: "person.3.fill",
                            title: "其他观点",
                            color: .cyan
                        )
                        {
                            core.sendQuickMessage("分析一下其他人对这个问题的看法和回答")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 52)
        }
    }

    private var questionDraftActionsSection: some View
    {
        VStack(spacing: 0)
        {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            HStack(spacing: 12)
            {
                Button(action: {
                    core.requestSmartSuggestion()
                })
                {
                    HStack(spacing: 6)
                    {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("智能提问")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(core.isLoading)

                Button(action: {
                    core.requestRelatedSearch()
                })
                {
                    HStack(spacing: 6)
                    {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                        Text("搜索相关")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(core.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var inputView: some View
    {
        VStack(spacing: 8)
        {
            // 错误提示
            if let error = core.errorMessage
            {
                HStack
                {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("关闭")
                    {
                        core.clearError()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
            }

            // 输入框
            HStack(spacing: 12)
            {
                TextField("向AI智能助手提问...", text: $core.inputText, axis: .vertical)
                    .focused($isTextFieldFocused)
                    .lineLimit(1 ... 4)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .onSubmit
                    {
                        handleSendMessage() // 🔥 修改：使用新的发送方法
                    }
                    .disabled(core.isLoading)
                    .hoverEffect(.highlight)

                Button(action: handleSendMessage)
                { // 🔥 修改：使用新的发送方法
                    if core.isSending
                    {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    else
                    {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 64,height: 64)
                    }
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .buttonBorderShape(.circle)  // 添加这个
                .tint(core.headerColor)
                .disabled(core.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || core.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // 发送消息处理方法
    private func handleSendMessage() {
        guard !core.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !core.isLoading
        else {
            return
        }

        let userMessage = core.inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 🔥 关键判断：是否处于等待确认状态（有选中区域）
        if let region = selectedRegion, sceneRecognitionState == .waitingConfirm {
            // ✅ 有选中区域且等待确认 → 进行场景识别
            print("🎯【检测到选中区域】将进行场景识别")
            
            // 添加用户消息到聊天记录
            let newUserMessage = AIChatMessage(
                content: userMessage,
                isUser: true,
                timestamp: Date()
            )
            core.messages.append(newUserMessage)
            core.inputText = ""
            
            // 🔥 关键：不改变状态，保持 waitingConfirm
            // 这样用户可以继续看到选区和拟合球面
            
            // 调用场景识别回调
            onSendSceneRecognition?(region, userMessage)
            
        } else {
            // ❌ 没有选中区域 → 普通的AI聊天
            print("💬【普通消息】发送AI聊天")
            core.sendMessage()
        }
    }
}

// MARK: - 重构后的AIAssistant组件（保持原有接口）

struct AIAssistant: View
{
    enum AIAssistantType
    {
        case explore(question: Question)
        case questionDraft(data: QuestionDraftData)
    }

    enum AIAssistantSide
    {
        case left
        case right
    }

    @Binding var isPresented: Bool
    let type: AIAssistantType
    let side: AIAssistantSide

    @StateObject private var core: AIAssistantCore
    @FocusState private var isTextFieldFocused: Bool

    @State private var offsetX: CGFloat = 0
    @State private var backgroundOpacity: Double = 0

    init(isPresented: Binding<Bool>, type: AIAssistantType, side: AIAssistantSide)
    {
        _isPresented = isPresented
        self.type = type
        self.side = side

        let coreType: AIAssistantCore.AIAssistantType
        switch type
        {
        case let .explore(question):
            coreType = .explore(question: question)
        case let .questionDraft(data):
            coreType = .questionDraft(data: data)
        }

        _core = StateObject(wrappedValue: AIAssistantCore(type: coreType))
    }

    var body: some View
    {
        ZStack
        {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture
                { location in
                    let shouldClose = side == .left ? location.x > 440 : location.x < 500
                    if shouldClose
                    {
                        closeAssistant()
                    }
                }
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            HStack
            {
                if side == .left
                {
                    aiAssistantPanel
                        .offset(x: offsetX)
                    Spacer()
                }
                else
                {
                    Spacer()
                    aiAssistantPanel
                        .offset(x: offsetX)
                }
            }
        }
        .onAppear
        {
            openAssistant()
            core.initializeIfNeeded()
        }
        .onChange(of: isPresented)
        { _ in
            if !isPresented
            {
                closeAssistant()
            }
        }
    }

    private var aiAssistantPanel: some View
    {
        VStack(spacing: 0)
        {
            // 标题栏
            headerView

            // 核心内容
            AIAssistantContent(
                core: core,
                isTextFieldFocused: _isTextFieldFocused,
                selectedRegion: $core.selectedRegion,
                sceneRecognitionState: $core.sceneRecognitionState,
                onSendSceneRecognition: nil // 👈 nil，禁用场景识别
            )
        }
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 25, x: side == .left ? 10 : -10, y: 0)
        .padding(side == .left ? .leading : .trailing, 20)
        .padding(.vertical, 40)
    }

    private var headerView: some View
    {
        HStack(spacing: 12)
        {
            ZStack
            {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                core.headerColor.opacity(0.3),
                                core.headerColor.opacity(0.2),
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
                                core.headerColor.opacity(0.9),
                                core.headerColor.opacity(0.7),
                                core.headerColor.opacity(0.5),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: core.headerIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2)
            {
                Text(core.headerTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                if let subtitle = core.headerSubtitle
                {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                closeAssistant()
            })
            {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 64,height: 64)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .buttonBorderShape(.circle)  // 添加圆形边框
            .hoverEffect(.highlight)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func openAssistant()
    {
        let initialOffset: CGFloat = side == .left ? -500 : 500
        offsetX = initialOffset

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8))
        {
            offsetX = 0
            backgroundOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7)
        {
            isTextFieldFocused = true
        }
    }

    private func closeAssistant()
    {
        let targetOffset: CGFloat = side == .left ? -450 : 450

        withAnimation(.spring(response: 0.4, dampingFraction: 0.9))
        {
            offsetX = targetOffset
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4)
        {
            isPresented = false
        }
    }
}

// MARK: - 便捷构造器（保持原有接口）

extension AIAssistant
{
    static func forExplore(
        question: Question,
        isPresented: Binding<Bool>
    ) -> AIAssistant
    {
        AIAssistant(
            isPresented: isPresented,
            type: .explore(question: question),
            side: .left
        )
    }

    static func forQuestionDraft(
        questionData: QuestionDraftData,
        isPresented: Binding<Bool>
    ) -> AIAssistant
    {
        AIAssistant(
            isPresented: isPresented,
            type: .questionDraft(data: questionData),
            side: .right
        )
    }
}


// MARK: - 重构后的AIAssistantWindow（复用核心逻辑）

struct AIAssistantWindow: View
{
    @Environment(\.dismissWindow) private var dismissWindow
    @EnvironmentObject var userManager: UserManager

    @State private var currentQuestion: Question = Question_1
    @StateObject public var core = AIAssistantCore(type: .explore(question: Question_1))
    @FocusState private var isTextFieldFocused: Bool

    @State private var contentOpacity: Double = 0
    @State private var headerScale: CGFloat = 0.8

    // 🔥 场景识别相关状态
    @State public var showSceneRecognition = false
    @State public var sceneRecognitionState: SceneRecognitionState = .idle
    @State public var selectedRegion: SelectionRegion?
    @State public var recognitionResult: String?
    
    // 🔥 添加相机追踪
   @State private var arSession = ARKitSession()
   @State private var worldTracking = WorldTrackingProvider()
   @State public var currentCameraPosition: SIMD3<Float> = SIMD3(0, 1.7, 0) // 初始估计值
   

    var body: some View
    {
        VStack(spacing: 0)
        {
            // 头部区域
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .scaleEffect(headerScale)
                .opacity(contentOpacity)

            // 核心内容区域
            AIAssistantContent(
                core: core,
                isTextFieldFocused: _isTextFieldFocused,
                selectedRegion: $selectedRegion,
                sceneRecognitionState: $sceneRecognitionState,
                onSendSceneRecognition: { region, userPrompt in
                    sendSceneRecognitionRequest(region: region, userPrompt: userPrompt)
                }
            )
            .opacity(contentOpacity)
            
            // 🔥 Vision AI 场景识别区域
            if showSceneRecognition
            {
                SceneRecognitionPanel(
                    state: $sceneRecognitionState,
                    selectedRegion: $selectedRegion,
                    recognitionResult: $recognitionResult,
                    onClose: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
                        {
                            showSceneRecognition = false
                            sceneRecognitionState = .idle
                        }
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: AnyTransition.move(edge: .bottom).combined(with: .opacity),
                        removal: AnyTransition.move(edge: .bottom).combined(with: .opacity)
                    )
                )
            }
            else
            {
                // 场景识别入口按钮
                SceneRecognitionEntryButton(
                    onTap: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8))
                        {
                            showSceneRecognition = true
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 480, height: showSceneRecognition ? 720 : 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear
        {
            setupWindow()
            realityAppearAnimation()
            // 启用相机追踪
            Task
            {
                await startCameraTracking()
                
            }
        }
        .onDisappear {
            print("🪟【AI助手窗口即将关闭】")
            
            NotificationCenter.default.post(
                name: NSNotification.Name("AIAssistantWindowWillClose"),
                object: nil
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("DisableRegionSelection"),
                object: nil
            )
            
            print("✅【窗口关闭清理通知已发送】")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateAIAssistantQuestion")))
        { notification in
            if let question = notification.userInfo?["question"] as? Question
            {
                updateQuestion(question)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RegionSelectionCompleted")))
        { notification in
            handleRegionSelectionCompleted(notification)
        }
    }


    // 🔥 新增：启动相机追踪
    private func startCameraTracking() async
    {
        #if !targetEnvironment(simulator)
            do
            {
                // 请求权限
                let auth = await arSession.requestAuthorization(for: [.worldSensing])
                guard auth[.worldSensing] == .allowed
                else
                {
                    print("❌ WorldSensing权限被拒绝")
                    return
                }

                // 启动ARKit会话
                try await arSession.run([worldTracking])
                print("✅ ARKit相机追踪已启动")

                // 🔥 持续更新相机位置
                startCameraPositionUpdates()
            }
            catch
            {
                print("❌ ARKit启动失败: \(error)")
            }
        #endif
    }

    // 🔥 新增：持续更新相机位置
    // 🔥 修复后的相机位置更新方法
    private func startCameraPositionUpdates() {
        #if !targetEnvironment(simulator)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // ✅ 修复：直接使用 self，不需要 guard let
            // struct 是值类型，不存在循环引用问题
            guard self.worldTracking.state == .running else { return }

            if let deviceAnchor = self.worldTracking.queryDeviceAnchor(
                atTimestamp: CACurrentMediaTime()
            ) {
                let transform = deviceAnchor.originFromAnchorTransform
                let position = SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )

                // 🔥 关键：真正更新相机位置
                Task { @MainActor in
                    self.currentCameraPosition = position
                }
                
                // 每5秒打印一次（不是每次都打印）
                if Int(Date().timeIntervalSince1970) % 5 == 0 {
                    print("📍 相机位置已更新: \(position)")
                }
            }
        }
        #endif
    }

    private var headerView: some View
    {
        HStack(spacing: 12)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2)
            {
                Text("AI 智能助手")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

            }

            Spacer()

            // 🧪 Debug 菜单按钮（仅在 DEBUG 模式下显示）
            #if DEBUG
            Menu {
                Button(action: {
                    print("🧪【显示测试球面区域】")
                    showTestSphericalRegion()
                }) {
                    Label("显示测试区域", systemImage: "scope")
                }
                
                Button(action: {
                    print("🧪【测试坐标转换】")
                    testCoordinateMapping()
                }) {
                    Label("测试坐标转换", systemImage: "arrow.triangle.2.circlepath")
                }
                
                Button(action: {
                    print("🧪【模拟AI识别】")
                    simulateAISendWithTestRegion()
                }) {
                    Label("模拟AI识别", systemImage: "brain")
                }
                
                Divider()
                
                Button(role: .destructive, action: {
                    print("🧪【清除测试区域】")
                    hideTestSphericalRegion()
                }) {
                    Label("清除测试区域", systemImage: "trash")
                }
            } label: {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(Circle().fill(Color.orange.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .help("调试工具")
            #endif

            Button(action: {
                dismissWindow(id: "AIAssistantWindow")
            })
            {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 64,height: 64)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .buttonBorderShape(.circle)  // 添加圆形边框
            .hoverEffect(.highlight)
        }
    }

    // MARK: - 处理区域选择完成

    private func handleRegionSelectionCompleted(_ notification: Notification)
    {
        guard let region = notification.userInfo?["region"] as? SelectionRegion else { return }

        print("✅【AI助手】收到区域选择完成通知")

        Task
        { @MainActor in
            selectedRegion = region
            sceneRecognitionState = .waitingConfirm
        }
    }

    private func setupWindow()
    {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenAIAssistantWindow"),
            object: nil,
            queue: .main
        )
        { notification in
            if let question = notification.userInfo?["question"] as? Question
            {
                self.updateQuestion(question)
            }
        }
        
        // 🔥 监听区域选择完成
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RegionSelectionCompleted"),
            object: nil,
            queue: .main
        ) { notification in
            if let region = notification.userInfo?["region"] as? SelectionRegion {
                DispatchQueue.main.async {
                    self.selectedRegion = region
                    self.sceneRecognitionState = .waitingConfirm
                    print("✅【区域选择完成】已更新状态")
                }
            }
        }
        
        // 🔥 监听发送识别请求
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SendSceneRecognitionRequest"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let region = userInfo["region"] as? SelectionRegion,
               let userPrompt = userInfo["userPrompt"] as? String {
                self.sendSceneRecognitionRequest(region: region, userPrompt: userPrompt)
            }
        }
    }

    private func updateQuestion(_ question: Question)
    {
        currentQuestion = question
        core.type = .explore(question: question)
        core.initializeIfNeeded()
    }
    

    private func realityAppearAnimation()
    {
        withAnimation(.easeOut(duration: 0.4))
        {
            contentOpacity = 1.0
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1))
        {
            headerScale = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)
        {
            isTextFieldFocused = true
        }

        core.initializeIfNeeded()
    }
}

//
//  VisionAIView+TestButton.swift
//  ✅ 为VisionAIView添加测试按钮
//

import SwiftUI

extension AIAssistantWindow {
    
    // MARK: - 🧪 测试按钮视图
    @ViewBuilder
    var testRegionButton: some View {
        VStack(spacing: 12) {
            // 显示测试球面区域按钮
            Button(action: {
                print("🧪【用户点击：显示测试球面区域】")
                showTestSphericalRegion()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 16))
                    Text("显示测试区域")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            
            // 直接测试转换按钮
            Button(action: {
                print("🧪【用户点击：测试坐标转换】")
                testCoordinateMapping()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16))
                    Text("测试坐标转换")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            
            // 模拟AI发送（使用测试区域）
            Button(action: {
                print("🧪【用户点击：模拟AI发送】")
                simulateAISendWithTestRegion()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 16))
                    Text("模拟AI识别")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            
            // 清除测试区域按钮
            Button(action: {
                print("🧪【用户点击：清除测试区域】")
                hideTestSphericalRegion()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                    Text("清除测试区域")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(Color(white: 0.15).opacity(0.7))
        .cornerRadius(12)
    }
    
    // MARK: - 🎯 显示测试球面区域
    private func showTestSphericalRegion() {
        // 发送通知到BasicPanoramaView
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowTestSphericalRegion"),
            object: nil,
            userInfo: [
                "expectedTopLeft": (2840, 1122),
                "expectedBottomRight": (5631, 2494),
                "sphereRadius": 10.0
            ]
        )
        
        print("✅【已发送显示测试球面区域通知】")
    }
    
    // MARK: - 🧪 测试坐标转换
    private func testCoordinateMapping() {
        // 生成模拟轨迹点
        let uvTopLeft = (u: Float(2840) / 8704.0, v: Float(1122) / 4352.0)
        let uvBottomRight = (u: Float(5631) / 8704.0, v: Float(2494) / 4352.0)
        
        let azimuthStart = (uvTopLeft.u - 0.5) * 2.0 * .pi
        let azimuthEnd = (uvBottomRight.u - 0.5) * 2.0 * .pi
        let elevationTop = (0.5 - uvTopLeft.v) * .pi
        let elevationBottom = (0.5 - uvBottomRight.v) * .pi
        
        let mockPoints = TestSphericalRegion.generateMockTrajectoryPoints(
            azimuthRange: (azimuthStart, azimuthEnd),
            elevationRange: (elevationTop, elevationBottom),
            radius: 10.0,
            numPoints: 50
        )
        
        let mockRegion = SelectionRegion(
            topLeft: SIMD3<Float>(-1, 0.5, -10),
            topRight: SIMD3<Float>(1, 0.5, -10),
            bottomLeft: SIMD3<Float>(-1, -0.5, -10),
            bottomRight: SIMD3<Float>(1, -0.5, -10),
            center: SIMD3<Float>(0, 0, -10),
            size: SIMD3<Float>(2, 1, 0.2),
            cameraPosition: SIMD3<Float>(0, 0, 0),
            captureTimestamp: Date(),
            trackedPoints: mockPoints
        )
        
        let converter = PanoramaCoordinateConverter(
            panoramaWidth: 8704,
            panoramaHeight: 4352
        )
        
        let result = converter.convertSelectionToPanoramaRegion(mockRegion)
        
        print("\n🎯【测试结果】")
        print("期望: (2840,1122) → (5631,2494)")
        print("实际: (\(result.topLeft.x),\(result.topLeft.y)) → (\(result.bottomRight.x),\(result.bottomRight.y))")
        
        let xError = abs(result.topLeft.x - 2840) + abs(result.bottomRight.x - 5631)
        let yError = abs(result.topLeft.y - 1122) + abs(result.bottomRight.y - 2494)
        
        print("误差: X=\(xError)px, Y=\(yError)px")
        print(xError < 500 && yError < 200 ? "✅ 通过" : "❌ 失败")
    }
    
    // MARK: - 🤖 模拟AI发送（使用测试区域）
    private func simulateAISendWithTestRegion() {
        print("🤖【模拟AI识别 - 使用测试球面区域】")
        
        // 1. 生成模拟轨迹点（对应测试区域）
        let uvTopLeft = (u: Float(2840) / 8704.0, v: Float(1122) / 4352.0)
        let uvBottomRight = (u: Float(5631) / 8704.0, v: Float(2494) / 4352.0)
        
        let azimuthStart = (uvTopLeft.u - 0.5) * 2.0 * .pi
        let azimuthEnd = (uvBottomRight.u - 0.5) * 2.0 * .pi
        let elevationTop = (0.5 - uvTopLeft.v) * .pi
        let elevationBottom = (0.5 - uvBottomRight.v) * .pi
        
        let mockPoints = TestSphericalRegion.generateMockTrajectoryPoints(
            azimuthRange: (azimuthStart, azimuthEnd),
            elevationRange: (elevationTop, elevationBottom),
            radius: 10.0,
            numPoints: 50
        )
        let mockRegion = SelectionRegion(
            topLeft: SIMD3<Float>(-1, 0.5, -10),
            topRight: SIMD3<Float>(1, 0.5, -10),
            bottomLeft: SIMD3<Float>(-1, -0.5, -10),
            bottomRight: SIMD3<Float>(1, -0.5, -10),
            center: SIMD3<Float>(0, 0, -10),
            size: SIMD3<Float>(2, 1, 0.2),
            cameraPosition: SIMD3<Float>(0, 0, 0),
            captureTimestamp: Date(),
            trackedPoints: mockPoints
        )
        
        // 2. 执行坐标转换
        let converter = PanoramaCoordinateConverter(
            panoramaWidth: 8704,
            panoramaHeight: 4352
        )
        
        let panoramaRegion = converter.convertSelectionToPanoramaRegion(mockRegion)
        
        print("\n📊【坐标转换结果】")
        print("目标像素: (2840,1122) → (5631,2494)")
        print("实际像素: (\(panoramaRegion.topLeft.x),\(panoramaRegion.topLeft.y)) → (\(panoramaRegion.bottomRight.x),\(panoramaRegion.bottomRight.y))")
        
        // 3. 模拟发送AI请求
        Task {
            do {
                await MainActor.run {
                    core.sceneRecognitionState = .recognizing
                }
                
                // 使用测试locationId=1
                let response = try await NetworkManager.shared.recognizeSceneRegion(
                    locationId: 1,
                    region: panoramaRegion,
                    userPrompt: "这是什么地方？(测试用模拟区域)"
                )
                
                await MainActor.run {
                    if response.success {
                        let aiMessage = AIChatMessage(
                            content: "【测试模式】\n\n坐标映射结果：\n期望: (2840,1122)→(5631,2494)\n实际: (\(panoramaRegion.topLeft.x),\(panoramaRegion.topLeft.y))→(\(panoramaRegion.bottomRight.x),\(panoramaRegion.bottomRight.y))\n\nAI识别结果：\n\(response.result)",
                            isUser: false,
                            timestamp: Date()
                        )
                        core.messages.append(aiMessage)
                        core.sceneRecognitionState = .completed
                        print("✅【AI识别完成】")
                    } else {
                        core.errorMessage = response.message ?? "识别失败"
                        core.sceneRecognitionState = .idle
                    }
                }
                
            } catch {
                await MainActor.run {
                    core.errorMessage = "测试出错: \(error.localizedDescription)"
                    core.sceneRecognitionState = .idle
                }
            }
        }
    }
    
    // MARK: - 🗑️ 清除测试球面区域
    private func hideTestSphericalRegion() {
        NotificationCenter.default.post(
            name: NSNotification.Name("HideTestSphericalRegion"),
            object: nil
        )
        print("✅【已发送清除测试球面区域通知】")
    }
}

extension AIAssistantWindow {
    
    /// 🔥 窗口关闭时的清理逻辑
    func setupWindowCloseHandler() -> some View {
        self.onDisappear {
            print("🪟【AI助手窗口即将关闭】")
            
            // 发送窗口关闭通知，让RegionSelectionManager清理所有可视化
            NotificationCenter.default.post(
                name: NSNotification.Name("AIAssistantWindowWillClose"),
                object: nil
            )
            
            // 禁用区域选择
            NotificationCenter.default.post(
                name: NSNotification.Name("DisableRegionSelection"),
                object: nil
            )
            
            print("✅【窗口关闭清理通知已发送】")
        }
    }
}

// MARK: - 🎛️ 可折叠Debug面板（修复遮挡问题）
struct CollapsibleDebugPanel: View {
    @State private var isExpanded = false
    
    // 需要访问AIAssistantWindow的方法
    @EnvironmentObject var window: AIAssistantWindowEnvironment
    
    var body: some View {
        VStack(spacing: 0) {
            // 🎛️ 折叠/展开切换按钮
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    
                    Text(isExpanded ? "隐藏调试面板" : "🧪 调试工具")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.borderless)
            
            // 📦 Debug面板内容（带动画折叠）
            if isExpanded {
                TestRegionButtonsView()
                    .padding(.top, 8)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
            }
        }
    }
}

// MARK: - 🧪 测试按钮视图（从testRegionButton提取）
struct TestRegionButtonsView: View {
    var body: some View {
        VStack(spacing: 12) {
            // 显示测试球面区域按钮
            Button(action: {
                print("🧪【用户点击：显示测试球面区域】")
                showTestSphericalRegion()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 16))
                    Text("显示测试区域")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            
            // 直接测试转换按钮
            Button(action: {
                print("🧪【用户点击：测试坐标转换】")
                testCoordinateMapping()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16))
                    Text("测试坐标转换")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            
            // 模拟AI发送（使用测试区域）
            Button(action: {
                print("🧪【用户点击：模拟AI发送】")
                simulateAISendWithTestRegion()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 16))
                    Text("模拟AI识别")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            
            // 清除测试区域按钮
            Button(action: {
                print("🧪【用户点击：清除测试区域】")
                hideTestSphericalRegion()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                    Text("清除测试区域")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(Color(white: 0.15).opacity(0.7))
        .cornerRadius(12)
    }
    
    // MARK: - Helper methods (这些需要通过通知发送，因为没有直接访问AIAssistantWindow)
    
    private func showTestSphericalRegion() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowTestSphericalRegion"),
            object: nil,
            userInfo: [
                "expectedTopLeft": (2840, 1122),
                "expectedBottomRight": (5631, 2494),
                "sphereRadius": 10.0
            ]
        )
        print("✅【已发送显示测试球面区域通知】")
    }
    
    private func testCoordinateMapping() {
        NotificationCenter.default.post(
            name: NSNotification.Name("TestCoordinateMapping"),
            object: nil
        )
        print("✅【已发送测试坐标转换通知】")
    }
    
    private func simulateAISendWithTestRegion() {
        NotificationCenter.default.post(
            name: NSNotification.Name("SimulateAISendWithTestRegion"),
            object: nil
        )
        print("✅【已发送模拟AI发送通知】")
    }
    
    public func hideTestSphericalRegion() {
        NotificationCenter.default.post(
            name: NSNotification.Name("HideTestSphericalRegion"),
            object: nil
        )
        print("✅【已发送清除测试球面区域通知】")
    }
}

// MARK: - Environment helper (如果需要)
class AIAssistantWindowEnvironment: ObservableObject {
    // 这里可以放置需要共享的方法
}


#Preview(windowStyle: .automatic)
{
    AIAssistantWindow()
        .environmentObject(UserManager.shared)
}
