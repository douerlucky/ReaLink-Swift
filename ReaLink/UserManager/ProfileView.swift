import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var vrManager: VRSessionManager
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var showingLoginSheet = false
    @State private var showingEditProfileModal = false
    @State private var showingLogoutAlert = false
    @State private var showingMessageSheet = false
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: UserContribution?
    
    // 用户统计数据
    @State private var userStats: UserStats?
    @State private var isLoadingStats = false
    @State private var statsError: String?
    
    // 选中的Tab
    @State private var selectedTab: ProfileTab = .questions
    
    // 问题数据
    @State private var userQuestions: [Question] = []
    @State private var userAnsweredQuestions: [Question] = []
    @State private var userContributions: [UserContribution] = []
    @State private var isLoadingQuestions = false
    @State private var questionsError: String?
    
    // 问题详情和地图
    @State private var selectedQuestion: Question?
    @State private var showQuestionDetail = false
    @State private var currentLocationInfo: LocationInfo?
    
    // 3D视图相关
    @State private var selectedContribution: UserContribution?
    @State private var locationToEdit: Location?
    
    // 动画状态
    @State private var leftPanelScale: CGFloat = 0.95
    @State private var rightPanelOffset: CGFloat = 50
    @State private var contentOpacity: Double = 0
    
    enum ProfileTab {
        case questions
        case answers
        case contributions
        
        var title: String {
            switch self {
            case .questions: return "已提问"
            case .answers: return "已回答"
            case .contributions: return "我的贡献"
            }
        }
        
        var icon: String {
            switch self {
            case .questions: return "questionmark.bubble"
            case .answers: return "arrowshape.turn.up.left"
            case .contributions: return "cube.transparent"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 全屏地图背景层
            if showQuestionDetail, let locationInfo = currentLocationInfo {
                FullScreenMapView(locationInfo: locationInfo)
                    .ignoresSafeArea(.all)
                    .zIndex(0)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // 主内容区域
            NavigationStack {
                if userManager.isLoggedIn, let user = userManager.currentUser {
                    HStack(spacing: 24) {
                        // 左侧用户信息面板
                        leftUserPanel(user: user)
                            .frame(width: 380)
                            .scaleEffect(leftPanelScale)
                            .opacity(contentOpacity)
                        
                        // 右侧内容面板
                        rightContentPanel()
                            .frame(maxWidth: .infinity)
                            .offset(x: rightPanelOffset)
                            .opacity(contentOpacity)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                } else {
                    loggedOutView
                }
            }
            .background(.regularMaterial)
            .cornerRadius(32)
            .opacity(showQuestionDetail ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: showQuestionDetail)
            .zIndex(1)
            
            // 问题详情弹窗
            if showQuestionDetail, let question = selectedQuestion {
                QuestionDetailModal.standard(
                    question: question,
                    isPresented: $showQuestionDetail,
                    onClose: { closeQuestionDetailAndMap() },
                    onSendReply: nil,
                    onAttachFile: { print("附加文件功能") }
                )
                .zIndex(20)
            }
        }
        .onAppear {
            performAppearAnimation()
            if userManager.isLoggedIn {
                loadUserData()
            }
        }
        .onChange(of: userManager.currentUser?.avatarUrl) { _, _ in
            if userManager.isLoggedIn {
                loadDataForTab(selectedTab)
            }
        }
        .sheet(isPresented: $showingLoginSheet) {
            LoginView().environmentObject(userManager)
        }
        .sheet(isPresented: $showingEditProfileModal) {
            EditProfileModal().environmentObject(userManager)
        }
        .sheet(isPresented: $showingMessageSheet) {
            MessageView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $locationToEdit) { location in
            AddRealSpace(
                locationId: location.id,
                locationName: location.name,
                latitude: location.latitude,
                longitude: location.longitude
            )
            .environmentObject(userManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("确认登出", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("登出", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    userManager.logout()
                    performAppearAnimation()
                }
            }
        } message: {
            Text("确定要登出当前账号吗？")
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {
                itemToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let item = itemToDelete {
                    deleteContribution(item)
                }
            }
        } message: {
            Text("确定要删除这个3D全景视图吗？此操作无法撤销。")
        }
    }
    
    // MARK: - 左侧用户信息面板
    
    @ViewBuilder
    private func leftUserPanel(user: User) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Button(action: {
                    showingEditProfileModal = true
                }) {
                    AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 3))
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                
                Text(user.username)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // 统计信息卡片
            if let stats = userStats {
                VStack(spacing: 12) {
                    StatCard(
                        icon: "questionmark.bubble.fill",
                        title: "已提问",
                        count: stats.totalQuestions,
                        color: .orange
                    )
                    
                    StatCard(
                        icon: "arrowshape.turn.up.left.fill",
                        title: "已回答",
                        count: stats.totalAnswers,
                        color: .orange
                    )
                }
            } else if isLoadingStats {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("加载统计中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(32)
            }
            
            Spacer()
            
            Button(action: {
                showingLogoutAlert = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.circle")
                        .font(.title3)
                    Text("登出")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - 右侧内容面板
    
    @ViewBuilder
    private func rightContentPanel() -> some View {
        VStack(spacing: 20) {
            // 顶部控制栏
            HStack {
                // Tab选择按钮 - 不使用ForEach，直接写清楚
                HStack(spacing: 12) {
                    // 已提问按钮
                    TabButton(
                        title: "已提问",
                        action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = .questions
                            }
                            loadDataForTab(.questions)
                        },
                        isSelected: selectedTab == .questions,
                        count: userStats?.totalQuestions,
                        icon: "questionmark.bubble"
                    )
                    
                    // 已回答按钮
                    TabButton(
                        title: "已回答",
                        action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = .answers
                            }
                            loadDataForTab(.answers)
                        },
                        isSelected: selectedTab == .answers,
                        count: userStats?.totalAnswers,
                        icon: "arrowshape.turn.up.left"
                    )
                    
                    // 我的贡献按钮
                    TabButton(
                        title: "我的贡献",
                        action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = .contributions
                            }
                            loadDataForTab(.contributions)
                        },
                        isSelected: selectedTab == .contributions,
                        count: userContributions.count,
                        icon: "cube.transparent"
                    )
                }
                
                Spacer()
                
                Button(action: {
                    showingMessageSheet = true
                }) {
                    Image(systemName: "bell")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
            
            // 内容区域
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoadingQuestions {
                        LoadingView(message: "加载\(selectedTab.title)中...")
                    } else if let error = questionsError {
                        ErrorView(message: error) {
                            loadDataForTab(selectedTab)
                        }
                    } else {
                        // 根据选中的Tab显示不同内容
                        if selectedTab == .questions {
                            questionsListView
                        } else if selectedTab == .answers {
                            answersListView
                        } else if selectedTab == .contributions {
                            contributionsListView
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshCurrentTab()
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - 已提问列表视图
    
    @ViewBuilder
    private var questionsListView: some View {
        if userQuestions.isEmpty {
            EmptyStateView(
                icon: "questionmark.bubble",
                title: "还没有提问",
                message: "去发布你的第一个问题吧"
            )
        } else {
            ForEach(userQuestions) { question in
                let updatedQuestion = updateQuestionWithCurrentUserAvatar(question)
                QuestionCard.detailed(
                    question: updatedQuestion,
                    onSelect: { selectQuestion(updatedQuestion) },
                    onLike: { print("点赞问题: \(updatedQuestion.title)") },
                    onAvatarTap: { print("查看用户信息") }
                )
            }
        }
    }
    
    // MARK: - 已回答列表视图
    
    @ViewBuilder
    private var answersListView: some View {
        let uniqueQuestions = Dictionary(grouping: userAnsweredQuestions, by: { $0.id })
            .compactMapValues { $0.first }
            .values
            .sorted { $0.createdAt > $1.createdAt }
        
        if uniqueQuestions.isEmpty {
            EmptyStateView(
                icon: "arrowshape.turn.up.left",
                title: "还没有回答",
                message: "去回答一些问题来帮助其他人吧"
            )
        } else {
            ForEach(Array(uniqueQuestions)) { question in
                let updatedQuestion = updateQuestionWithCurrentUserAvatar(question)
                QuestionCard.detailed(
                    question: updatedQuestion,
                    onSelect: { selectQuestion(updatedQuestion) },
                    onLike: { print("点赞问题: \(updatedQuestion.title)") },
                    onAvatarTap: { print("查看用户信息") }
                )
            }
        }
    }
    
    // MARK: - 我的贡献列表视图
    
    @ViewBuilder
    private var contributionsListView: some View {
        if userContributions.isEmpty {
            EmptyStateView(
                icon: "cube.transparent",
                title: "还没有贡献",
                message: "去上传你的第一个3D全景视图吧"
            )
        } else {
            ForEach(userContributions) { contribution in
                ContributionCard(
                    contribution: contribution,
                    onTap: {
                        enterContribution3DView(contribution)
                    },
                    onEdit: {
                        editContribution(contribution)
                    },
                    onDelete: {
                        itemToDelete = contribution
                        showingDeleteAlert = true
                    }
                )
            }
        }
    }
    
    // MARK: - 未登录视图
    
    @ViewBuilder
    private var loggedOutView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 12) {
                    Text("尚未登录")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("登录后可以发布问题、参与讨论\n并查看个人资料")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            VStack(spacing: 16) {
                Button(action: {
                    showingLoginSheet = true
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text("立即登录")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: 300)
                
                Text("或")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Button("创建新账号") {
                    showingLoginSheet = true
                }
                .foregroundColor(.blue)
                .font(.headline)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - 数据加载方法
    
    private func loadUserData() {
        loadUserStats()
        loadDataForTab(selectedTab)
    }
    
    @MainActor
    private func refreshCurrentTab() async {
        async let statsTask = refreshUserStats()
        async let dataTask = refreshDataForTab(selectedTab)
        await statsTask
        await dataTask
    }
    
    @MainActor
    private func refreshUserStats() async {
        guard let userId = userManager.getUserId() else { return }
        do {
            let stats = try await NetworkManager.shared.getUserStats(userId: userId)
            self.userStats = stats
        } catch {
            print("统计数据刷新失败: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func refreshDataForTab(_ tab: ProfileTab) async {
        guard let userId = userManager.getUserId() else { return }
        do {
            switch tab {
            case .questions:
                let response = try await NetworkManager.shared.getUserQuestions(userId: userId)
                self.userQuestions = response.questions.map { $0.toQuestion() }
            case .answers:
                let response = try await NetworkManager.shared.getUserAnsweredQuestions(userId: userId)
                self.userAnsweredQuestions = response.questions.map { $0.toQuestion() }
            case .contributions:
                let contributions = try await NetworkManager.shared.getUserContributions(userId: userId)
                self.userContributions = contributions
            }
        } catch {
            print("数据刷新失败: \(error.localizedDescription)")
        }
    }
    
    private func loadUserStats() {
        guard let userId = userManager.getUserId() else { return }
        isLoadingStats = true
        statsError = nil
        
        Task {
            do {
                let stats = try await NetworkManager.shared.getUserStats(userId: userId)
                await MainActor.run {
                    self.userStats = stats
                    self.isLoadingStats = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingStats = false
                    self.statsError = "加载失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadDataForTab(_ tab: ProfileTab) {
        guard let userId = userManager.getUserId() else { return }
        isLoadingQuestions = true
        questionsError = nil
        
        Task {
            do {
                switch tab {
                case .questions:
                    let response = try await NetworkManager.shared.getUserQuestions(userId: userId)
                    await MainActor.run {
                        self.userQuestions = response.questions.map { $0.toQuestion() }
                        self.isLoadingQuestions = false
                    }
                case .answers:
                    let response = try await NetworkManager.shared.getUserAnsweredQuestions(userId: userId)
                    await MainActor.run {
                        self.userAnsweredQuestions = response.questions.map { $0.toQuestion() }
                        self.isLoadingQuestions = false
                    }
                case .contributions:
                    let contributions = try await NetworkManager.shared.getUserContributions(userId: userId)
                    await MainActor.run {
                        self.userContributions = contributions
                        self.isLoadingQuestions = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingQuestions = false
                    self.questionsError = "加载失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - 3D贡献操作
    
    private func enterContribution3DView(_ contribution: UserContribution) {
        Task {
            await MainActor.run {
                vrManager.setLoadingState(true)
                vrManager.updateLocationInfoWithURL(
                    title: contribution.locationName,
                    panoramaImageURL: contribution.fileURL
                )
            }
            
            await openImmersiveSpace(id: "Realistic3DScene")
            await MainActor.run {
                dismissWindow(id: "MainWindow")
            }
        }
    }
    
    private func editContribution(_ contribution: UserContribution) {
        locationToEdit = Location(
            id: contribution.locationId,
            name: contribution.locationName,
            longitude: contribution.longitude ?? 0,
            latitude: contribution.latitude ?? 0,
            questionCount: 0
        )

    }
    
    private func deleteContribution(_ contribution: UserContribution) {
        Task {
            do {
                let success = try await NetworkManager.shared.deleteContribution(
                    real3DViewId: contribution.id,
                    userId: userManager.getUserId() ?? -1
                )
                
                if success {
                    await MainActor.run {
                        userContributions.removeAll { $0.id == contribution.id }
                        itemToDelete = nil
                    }
                }
            } catch {
                print("删除失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 问题操作
    
    private func selectQuestion(_ question: Question) {
        selectedQuestion = question
        if question.locationID > 0 {
            Task {
                await loadLocationAndShowDetails(for: question)
            }
        } else {
            showQuestionDetail = true
        }
    }
    
    private func loadLocationAndShowDetails(for question: Question) async {
        do {
            let locationDetail = try await NetworkManager.shared.getLocationInfo(locationId: question.locationID)
            let locationInfo = locationDetail.toLocationInfo()
            
            await MainActor.run {
                self.currentLocationInfo = locationInfo
                withAnimation(.easeInOut(duration: 0.4)) { }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.showQuestionDetail = true
                    }
                }
            }
        } catch {
            print("获取位置信息失败: \(error)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.showQuestionDetail = true
                }
            }
        }
    }
    
    private func closeQuestionDetailAndMap() {
        showQuestionDetail = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.selectedQuestion = nil
            self.currentLocationInfo = nil
        }
    }
    
    private func updateQuestionWithCurrentUserAvatar(_ question: Question) -> Question {
        if let currentUser = userManager.currentUser, question.userID == currentUser.id {
            let finalAvatarUrl = currentUser.avatarUrl?.isEmpty == false ? currentUser.avatarUrl : question.avatarUrl
            return Question(
                id: question.id,
                locationID: question.locationID,
                userID: question.userID,
                actualPlace: question.actualPlace,
                title: question.title,
                content: question.content,
                replyCount: question.replyCount,
                status: question.status,
                createdAt: question.createdAt,
                updatedAt: question.updatedAt,
                username: currentUser.username,
                avatarUrl: finalAvatarUrl
            )
        }
        return question
    }
    
    // MARK: - 动画
    
    private func performAppearAnimation() {
        leftPanelScale = 0.95
        rightPanelOffset = 50
        contentOpacity = 0
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            leftPanelScale = 1.0
            contentOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) {
            rightPanelOffset = 0
        }
    }
}

// MARK: - 辅助视图组件

struct StatCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("个问题")
                .font(.subheadline)
                .foregroundColor(color)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.1)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            Text("加载失败")
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重新加载", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct ContributionCard: View {
    let contribution: UserContribution
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 地点名称
            Text(contribution.locationName)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 缩略图
            Button(action: onTap) {
                ZStack {
                    if let thumbnail = thumbnailImage {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    } else if isLoadingThumbnail {
                        ProgressView()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                    } else {
                        Color.clear
                            .frame(height: 180)
                            .background(.ultraThinMaterial)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .cornerRadius(12)
                .overlay(
                    HStack(spacing: 6) {
                        Image(systemName: "cube.transparent")
                            .font(.caption)
                        Text("查看3D视图")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding(8),
                    alignment: .bottomTrailing
                )
            }
            .buttonStyle(.plain)
            
            // 操作按钮
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("编辑")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: onDelete) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("删除")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2), lineWidth: 1))
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        isLoadingThumbnail = true
        Task {
            do {
                let base64 = try await NetworkManager.shared.get3DViewThumbnail(
                    locationId: contribution.locationId,
                    width: 300,
                    height: 180
                )
                if let base64Data = base64.components(separatedBy: ",").last,
                   let imageData = Data(base64Encoded: base64Data),
                   let image = UIImage(data: imageData) {
                    await MainActor.run {
                        self.thumbnailImage = image
                        self.isLoadingThumbnail = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingThumbnail = false
                }
            }
        }
    }
}

// MARK: - 数据模型

struct UserContribution: Identifiable, Codable {
    let id: Int64
    let locationId: Int64
    let locationName: String
    let fileURL: String
    let latitude: Double?
    let longitude: Double?
    let createdAt: String
}
