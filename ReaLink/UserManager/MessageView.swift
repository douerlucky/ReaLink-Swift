import SwiftUI

struct MessageView: View {
    // MARK: - 环境和状态管理
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: UserManager
    @StateObject private var networkManager = NetworkManager.shared
    
    // MARK: - 基础状态
    @State private var selectedMessageType = 0 // 0: 邀请你回答, 1: 收到回复
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false

    
    // MARK: - 消息数据
    @State private var inviteMessages: [Question] = []
    @State private var receivedMessages: [ReceivedMessage] = []
    
    // MARK: - 问题详情相关
    @State private var selectedQuestion: Question?
    @State private var showQuestionDetail = false
    @State private var currentLocationInfo: LocationInfo?
    
    // MARK: - 任务管理
    @State private var loadTask: Task<Void, Never>?
    @State private var refreshTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // 主内容区域
            VStack(spacing: 0) {
                // 顶部工具栏
                headerSection
                
                Divider()
                
                // 消息内容区域
                contentSection
            }
            .background(backgroundGradient)
            .opacity(showQuestionDetail ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: showQuestionDetail)
            .zIndex(1)
            
            // 问题详情弹窗（顶层）
            if showQuestionDetail, let question = selectedQuestion {
                QuestionDetailModal.standard(
                    question: question,
                    isPresented: $showQuestionDetail,
                    onClose: {
                        closeQuestionDetail()
                    }
                )
                .zIndex(20)
            }
        }
        .navigationBarHidden(true)
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .onAppear {
            loadMessages()
        }
        .onDisappear {
            cancelAllTasks()
        }
    }
    
    // MARK: - 视图组件
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 关闭按钮和操作栏
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .buttonBorderShape(.circle)  // 添加圆形边框
                .hoverEffect(.highlight)
                
                Spacer()
                
                // 消息数量指示
                Text(messageCountText)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // 全部已读按钮
                Button("全部已读") {
                    handleMarkAllAsRead()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isLoading || currentMessageCount == 0)

            }
            
            // 消息类型选择
            HStack(spacing: 12) {
                TabButton(
                    title: "邀请你回答",
                    action: {
                        selectedMessageType = 0
                        loadMessages()
                    },
                    isSelected: selectedMessageType == 0,
                    count: inviteMessages.count
                )
                
                TabButton(
                    title: "收到回复",
                    action: {
                        selectedMessageType = 1
                        loadMessages()
                    },
                    isSelected: selectedMessageType == 1,
                    count: receivedMessages.count
                )
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private var contentSection: some View {
        Group {
            if selectedMessageType == 0 {
                InviteMessagesView(
                    messages: inviteMessages,
                    isLoading: isLoading,
                    onQuestionSelect: { question in
                        selectQuestion(question)
                    }
                )
            } else {
                ReceivedMessagesView(
                    messages: receivedMessages,
                    isLoading: isLoading,
                    onAnswerSelect: { message in
                        selectReceivedMessage(message)
                    },
                    onMarkAsRead: { message, index in
                        handleMarkAsRead(message, at: index)
                    }
                )
            }
        }
        .refreshable {
            await refreshMessages()
        }
    }
    
    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.08),
                Color.blue.opacity(0.04),
                Color.purple.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - 计算属性
    
    private var messageCountText: String {
        let count = currentMessageCount
        let type = selectedMessageType == 0 ? "邀请" : "回复"
        return "\(count) 条\(type)消息"
    }
    
    private var currentMessageCount: Int {
        selectedMessageType == 0 ? inviteMessages.count : receivedMessages.count
    }
    
    // MARK: - 事件处理
    
    private func selectQuestion(_ question: Question) {
        print("选择问题: \(question.title)")
        selectedQuestion = question
        showQuestionDetail = true
    }
    
    private func selectReceivedMessage(_ message: ReceivedMessage) {
        // 将ReceivedMessage转换为Question并显示详情
        let question = message.toQuestion()
        selectQuestion(question)
    }
    
    private func closeQuestionDetail() {
        selectedQuestion = nil
        showQuestionDetail = false
    }
    
    private func handleMarkAsRead(_ message: ReceivedMessage, at index: Int) {
        Task {
            await markMessageAsRead(message, at: index)
        }
    }
    
    private func handleMarkAllAsRead() {
        Task {
            await markAllMessagesAsRead()
        }
    }
    
    private func handleClearAllMessages() {
        Task {
            await clearAllMessages()
        }
    }
    
    // MARK: - 数据加载和操作
    
    private func loadMessages() {
        guard let userId = userManager.getUserId() else {
            print("用户未登录，无法加载消息")
            errorMessage = "请先登录"
            showingError = true
            return
        }
        
        loadTask?.cancel()
        
        loadTask = Task {
            if selectedMessageType == 0 {
                await loadInviteMessages(userId: userId)
            } else {
                await loadReceivedMessages(userId: userId)
            }
        }
    }
    
    private func loadInviteMessages(userId: Int64) async {
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try Task.checkCancellation()
            
            let response = try await networkManager.getInviteMessages(userId: userId)
            
            try Task.checkCancellation()
            
            await MainActor.run {
                if response.success {
                    self.inviteMessages = response.messages
                    print("✅ 加载邀请消息成功: \(response.messages.count) 条消息")
                } else {
                    self.errorMessage = "加载邀请消息失败"
                    self.showingError = true
                }
                self.isLoading = false
            }
        } catch is CancellationError {
            print("邀请消息加载请求被取消")
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "网络请求失败: \(error.localizedDescription)"
                self.showingError = true
                self.isLoading = false
            }
        }
    }
    
    private func loadReceivedMessages(userId: Int64) async {
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try Task.checkCancellation()
            
            let response = try await networkManager.getReceivedMessages(userId: userId)
            
            try Task.checkCancellation()
            
            await MainActor.run {
                if response.success {
                    self.receivedMessages = response.messages
                    print("✅ 加载回复消息成功: \(response.messages.count) 条消息")
                } else {
                    self.errorMessage = "加载回复消息失败"
                    self.showingError = true
                }
                self.isLoading = false
            }
        } catch is CancellationError {
            print("回复消息加载请求被取消")
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "网络请求失败: \(error.localizedDescription)"
                self.showingError = true
                self.isLoading = false
            }
        }
    }
    
    private func refreshMessages() async {
        guard let userId = userManager.getUserId() else { return }
        
        refreshTask?.cancel()
        
        refreshTask = Task {
            if selectedMessageType == 0 {
                await loadInviteMessages(userId: userId)
            } else {
                await loadReceivedMessages(userId: userId)
            }
        }
    }
    
    private func markMessageAsRead(_ message: ReceivedMessage, at index: Int) async {
        guard let userId = userManager.getUserId() else { return }
        
        do {
            let response = try await networkManager.deleteMessage(
                messageId: message.messageId,
                userId: userId
            )
            
            await MainActor.run {
                if response.success {
                    if index < self.receivedMessages.count {
                        withAnimation(.easeOut(duration: 0.4)) {
                            self.receivedMessages.remove(at: index)
                        }
                    }
                    print("✅ 消息标记为已读并删除成功")
                } else {
                    self.errorMessage = response.message
                    self.showingError = true
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "标记已读失败: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
    
    private func markAllMessagesAsRead() async {
        guard selectedMessageType == 1,
              let userId = userManager.getUserId() else { return }
        
        do {
            let response = try await networkManager.clearAllMessages(userId: userId)
            
            await MainActor.run {
                if response.success {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.receivedMessages.removeAll()
                    }
                    print("✅ 所有消息标记为已读")
                } else {
                    self.errorMessage = response.message
                    self.showingError = true
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "标记全部已读失败: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
    
    private func clearAllMessages() async {
        guard selectedMessageType == 1,
              let userId = userManager.getUserId() else {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    if selectedMessageType == 0 {
                        self.inviteMessages.removeAll()
                    } else {
                        self.receivedMessages.removeAll()
                    }
                }
            }
            return
        }
        
        do {
            let response = try await networkManager.clearAllMessages(userId: userId)
            
            await MainActor.run {
                if response.success {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.receivedMessages.removeAll()
                    }
                    print("✅ 所有消息清空成功")
                } else {
                    self.errorMessage = response.message
                    self.showingError = true
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "清空失败: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
    
    private func cancelAllTasks() {
        loadTask?.cancel()
        refreshTask?.cancel()
        loadTask = nil
        refreshTask = nil
        print("取消所有消息加载任务")
    }
}

// MARK: - 邀请消息视图

struct InviteMessagesView: View {
    let messages: [Question]
    let isLoading: Bool
    let onQuestionSelect: (Question) -> Void
    
    var body: some View {
        Group {
            if isLoading && messages.isEmpty {
                loadingView
            } else if messages.isEmpty {
                emptyStateView
            } else {
                messagesList
            }
        }
        .background(backgroundGradient)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载邀请消息中...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.bubble")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无邀请消息")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("当有人邀请你回答问题时，会在这里显示")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(messages) { question in
                    QuestionCard.detailed(
                        question: question,
                        onSelect: {
                            onQuestionSelect(question)
                        },
                        onLike: {
                            print("邀请消息不支持点赞")
                        },
                        onAvatarTap: {
                            print("查看用户信息: \(question.username ?? "未知用户")")
                        }
                    )
                }
                
                if isLoading && !messages.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("加载中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
    
    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.08),
                Color.blue.opacity(0.04),
                Color.purple.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 收到回复消息视图

struct ReceivedMessagesView: View {
    let messages: [ReceivedMessage]
    let isLoading: Bool
    let onAnswerSelect: (ReceivedMessage) -> Void
    let onMarkAsRead: (ReceivedMessage, Int) -> Void
    
    var body: some View {
        Group {
            if isLoading && messages.isEmpty {
                loadingView
            } else if messages.isEmpty {
                emptyStateView
            } else {
                messagesList
            }
        }
        .background(backgroundGradient)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载回复消息中...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无回复消息")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("当有人回复你的问题时，会在这里显示")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(messages.indices, id: \.self) { index in
                    let message = messages[index]
                    
                    AnswerCard(
                        message: message,
                        onSelect: {
                            onAnswerSelect(message)
                        },
                        onMarkAsRead: {
                            onMarkAsRead(message, index)
                        }
                    )
                }
                
                if isLoading && !messages.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("处理中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
    
    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.08),
                Color.blue.opacity(0.04),
                Color.purple.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 回复卡片组件

struct AnswerCard: View {
    let message: ReceivedMessage
    let onSelect: () -> Void
    let onMarkAsRead: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 问题标题
            HStack(spacing: 12) {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("你的问题")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(message.questionTitle)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 新回复标记
                Text("新回复")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.9))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            // 回复内容
                
            HStack(alignment: .top, spacing: 12) {
                // 回复者头像
                AsyncImage(url: URL(string: message.senderAvatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    // 回复者昵称和时间
                    HStack {
                        Text(message.senderUsername)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(formatAnswerDate(message.answerCreatedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 回复内容
                    Text(message.answerContent)
                        .font(.body)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        
            
            
            // 操作按钮
            HStack {
                Button(action: onSelect) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                        Text("查看详情")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onMarkAsRead) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                        Text("标记已读")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - TabButton组件（保持不变）

struct TabButton: View {
    let title: String
    let action: () -> Void
    var isSelected: Bool = false
    var count: Int? = nil
    var icon: String? = nil
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                
                Text(title)
                    .font(.headline)
                
                if let count = count {
                    Text("(\(count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ? .ultraThickMaterial : .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .foregroundColor(isSelected ? .primary : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? .orange.opacity(0.5) : .clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预览

#Preview {
    MessageView()
        .preferredColorScheme(.dark)
        .environmentObject(UserManager.shared)
}

#Preview("Sheet 展示") {
    NavigationView {
        Color.clear
    }
    .sheet(isPresented: .constant(true)) {
        MessageView()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .environmentObject(UserManager.shared)
    }
    .preferredColorScheme(.dark)
}
