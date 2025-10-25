//
//  QuestionDetailModal.swift
//  ReaLink
//
//  问题详情模态框 - 带TabView的主体结构
//

import SwiftUI
import RealityKit

struct QuestionDetailModalWithTabs: View
{
    let question: Question
    @Binding var isPresented: Bool
    let onClose: () -> Void
    @State private var isAddingModel = false
    
    // 问题回答数据
    @State public var questionAnswers: getQuestionAnswerResponse?
    @State public var isLoadingAnswers: Bool = false
    @State public var answersError: String?

    // 可选的回调
    let onSendReply: ((String) -> Void)?
    let onAttachFile: (() -> Void)?
    let onRefreshAnswers: (() -> Void)?

    // Reality环境适配参数
    let isRealityEnvironment: Bool

    @State public var showModelTypePicker = false
    @State public var showModelColorPicker = false
    @State public var selectedTab = 0
    @State public var animationOffset: CGFloat = 400
    @State public var animationOpacity: Double = 0
    @State public var replyText: String = ""
    @FocusState public var isTextFieldFocused: Bool

    // Reality环境专用动画状态
    @State public var contentOpacity: Double = 0
    @State public var headerScale: CGFloat = 0.8
    @State public var scrollViewOffset: CGFloat = 30

    // 发送回复状态
    @State public var isSendingReply = false
    @State public var replyError: String?

    // 空间绘画相关状态
    @StateObject public var brushManager = BrushManager.shared
    @State public var isSavingPainting = false
    @State public var paintingSaveStatus = ""
    @State public var isRefreshingPainting = false

    // 3D模型相关状态
    @StateObject public var modelManager = ModelManager.shared
    @State public var isSavingModels = false
    @State public var modelsSaveStatus = ""
    @State public var isRefreshingModels = false

    // 模型编辑状态
    @State private var selectedModelForEdit: PlacedModel?
    @State private var isEditingModel = false
    @State private var editModelColor: Color = .blue
    @State private var modelRotationX: Double = 0
    @State private var modelRotationY: Double = 0
    @State private var modelRotationZ: Double = 0
    @State private var selectedModelText: String = ""
    
    // 环境对象
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var targetQuestionManager: TargetQuesitonManager
    @EnvironmentObject var windowStateManager: WindowStateManager
    @Environment(\.openWindow) public var openWindow
    
    // ✅ 新增：管理异步任务
       @State private var loadTask: Task<Void, Never>?
       @State private var lastRefreshTime: Date = Date()
    

    // 主构造器
    init(
        question: Question,
        isPresented: Binding<Bool>,
        onClose: @escaping () -> Void,
        onSendReply: ((String) -> Void)? = nil,
        onAttachFile: (() -> Void)? = nil,
        onRefreshAnswers: (() -> Void)? = nil,
        isRealityEnvironment: Bool = false
    )
    {
        self.question = question
        _isPresented = isPresented
        self.onClose = onClose
        self.onSendReply = onSendReply
        self.onAttachFile = onAttachFile
        self.onRefreshAnswers = onRefreshAnswers
        self.isRealityEnvironment = isRealityEnvironment
    }

    var body: some View
    {
        if isRealityEnvironment
        {
            realityEnvironmentViewWithTabs
                .onAppear
                {
                    setupModelEditNotificationListeners()
                }
        }
        else
        {
            standardEnvironmentView
        }
    }

    // MARK: - 模型编辑通知监听

    private func setupModelEditNotificationListeners()
    {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ModelSelected"),
            object: nil,
            queue: .main
        )
        { notification in
            if let model = notification.userInfo?["model"] as? PlacedModel
            {
                self.selectedModelForEdit = model
                self.isEditingModel = true
                self.editModelColor = model.color
                print("QuestionDetailModalWithTabs: 收到模型选中通知 - \(model.id)")
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ModelDeselected"),
            object: nil,
            queue: .main
        )
        { _ in
            self.selectedModelForEdit = nil
            self.isEditingModel = false
            print("QuestionDetailModalWithTabs: 收到模型取消选中通知")
        }
    }

    // MARK: - Reality环境带TabView的视图

    public var realityEnvironmentViewWithTabs: some View
    {
        VStack(spacing: 0)
        {
            // 头部
            headerView
                .padding(24)
                .background(.regularMaterial)
                .scaleEffect(headerScale)
                .opacity(contentOpacity)

            // TabView 主体内容
            TabView(selection: $selectedTab)
            {
                // Tab 1: 对话内容
                QuestionConversationTab(
                    question: question,
                    isRealityEnvironment: isRealityEnvironment,
                    contentOpacity: contentOpacity
                )
                .environmentObject(userManager)
                .tabItem
                {
                    Label("对话", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(0)

                // Tab 2: 空间绘画控制
                SpatialPaintingTab(
                    question: question,
                    brushManager: brushManager,
                    contentOpacity: contentOpacity,
                    isSavingPainting: $isSavingPainting,
                    paintingSaveStatus: $paintingSaveStatus,
                    isRefreshingPainting: $isRefreshingPainting,
                    onSave: savePaintingData
                )
                .tabItem
                {
                    Label("绘画", systemImage: "paintbrush")
                }
                .tag(1)

                // Tab 3: 模型放置控制
                ModelPlacementTab(
                        question: question,
                        modelManager: modelManager,
                        selectedModelForEdit: $selectedModelForEdit,
                        isEditingModel: $isEditingModel,
                        editModelColor: $editModelColor,
                        modelRotationX: $modelRotationX,
                        modelRotationY: $modelRotationY,
                        modelRotationZ: $modelRotationZ,
                        selectedModelText: $selectedModelText,
                        showModelTypePicker: $showModelTypePicker,
                        contentOpacity: contentOpacity,
                        isSavingModels: $isSavingModels,
                        modelsSaveStatus: $modelsSaveStatus,
                        isRefreshingModels: $isRefreshingModels,
                        isAddingModel: $isAddingModel,
                        // ✅ 移除这个参数
                        // showModelsList: $showModelsList,
                        onSave: saveModelsData
                    )
                    .environmentObject(userManager)
                    .tabItem {
                        Label("模型", systemImage: "cube")
                    }
                    .tag(2)
            }
            .tabViewStyle(.sidebarAdaptable)
            .opacity(contentOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.25), radius: 25, x: 0, y: 10)
        .onAppear
        {
            realityAppearAnimation()
            loadQuestionAnswers()
        }
        .onDisappear
                {
                    realityDisappearAnimation()
                    // ✅ 清理任务
                    loadTask?.cancel()
                    loadTask = nil
                }
        .ornament(
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .center
        )
        {
            if selectedTab == 0
            {
                inputView
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .glassBackgroundEffect()
                    .opacity(contentOpacity)
                    .scaleEffect(contentOpacity > 0.5 ? 1.0 : 0.8)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showModelTypePicker)
        {
            ModelTypePickerView(selectedModelType: $modelManager.selectedModelType)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showModelColorPicker)
        {
            ModelColorPickerSheet(
                selectedColor: $editModelColor,
                onColorSelected: { color in
                    handleModelColorChange(color)
                    showModelColorPicker = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - 标准环境视图

    public var standardEnvironmentView: some View
    {
        ZStack
        {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .opacity(animationOpacity)

            HStack
            {
                Spacer()

                VStack
                {
                    VStack
                    {
                        headerView
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))

                        ScrollView
                        {
                            QuestionMessagesView(
                                question: question,
                                isRealityEnvironment: isRealityEnvironment
                            )
                            .environmentObject(userManager)
                            .padding(.horizontal, 10)
                        }
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
                loadQuestionAnswers()
            }
            .onChange(of: isPresented)
                   { _ in
                       if !isPresented
                       {
                           standardDisappearAnimation()
                           // ✅ 清理任务
                           loadTask?.cancel()
                           loadTask = nil
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    // MARK: - 共享的头部视图

    public var headerView: some View
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
                    Image(systemName: isRealityEnvironment ? "xmark" : "xmark.circle.fill")
                        .font(isRealityEnvironment ? .body : .title2)
                        .fontWeight(isRealityEnvironment ? .medium : .regular)
                        .symbolRenderingMode(isRealityEnvironment ? .monochrome : .hierarchical)
                        .foregroundColor(.white)
                }
                .hoverEffect(.highlight)
            }

            HStack
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
                }

                Text(question.username ?? "匿名用户")
                    .font(.headline)
                Spacer()
                Text(formatTimestamp(question.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(question.title)
                .font(.title)
                .fontWeight(.bold)
        }
    }

    // MARK: - 共享的输入视图

    public var inputView: some View
    {
        VStack(spacing: 12)
        {
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSendingReply)

                HStack
                {
                    TextField("输入你的回答...", text: $replyText, axis: .vertical)
                        .focused($isTextFieldFocused)
                        .lineLimit(1 ... 4)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .font(.system(size: 24))
                        .textFieldStyle(.plain)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 550)
                        .onSubmit
                        {
                            if !isSendingReply
                            {
                                handleSendReply()
                            }
                        }
                        .disabled(isSendingReply)
                }.hoverEffect(.highlight)

                Button(action: handleSendReply)
                {
                    if isSendingReply
                    {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    else
                    {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingReply)
                .scaleEffect((replyText.isEmpty || isSendingReply) ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: replyText.isEmpty)
                .animation(.easeInOut(duration: 0.2), value: isSendingReply)
            }

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

    // MARK: - 数据操作方法

    private func savePaintingData()
    {
        guard question.locationID > 0 && question.id > 0
        else
        {
            paintingSaveStatus = "问题数据无效"
            return
        }

        isSavingPainting = true
        paintingSaveStatus = "正在保存..."

        print("开始保存绘画数据到云端")

        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false)
        { _ in
            DispatchQueue.main.async
            {
                if self.isSavingPainting
                {
                    self.isSavingPainting = false
                    self.paintingSaveStatus = "保存超时,请重试"

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3)
                    {
                        self.paintingSaveStatus = ""
                    }
                }
            }
        }

        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudOperationResult"),
            object: nil,
            queue: .main
        )
        { notification in
            timeoutTimer.invalidate()

            if let userInfo = notification.userInfo,
               let success = userInfo["success"] as? Bool,
               let message = userInfo["message"] as? String
            {
                DispatchQueue.main.async
                {
                    self.isSavingPainting = false
                    self.paintingSaveStatus = message

                    print("云端绘画操作结果: \(success ? "成功" : "失败") - \(message)")

                    let displayTime: TimeInterval = success ? 2.0 : 5.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + displayTime)
                    {
                        self.paintingSaveStatus = ""
                    }
                }
            }

            if let observer = observer
            {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        let userInfo: [String: Any] = [
            "action": "savePaintingToCloud",
            "locationId": question.locationID,
            "questionId": question.id,
            "userId": NSNull(),
        ]

        NotificationCenter.default.post(
            name: NSNotification.Name("CloudPaintingOperation"),
            object: nil,
            userInfo: userInfo
        )
    }

    private func saveModelsData()
    {
        guard question.locationID > 0 && question.id > 0
        else
        {
            modelsSaveStatus = "问题数据无效"
            return
        }

        isSavingModels = true
        modelsSaveStatus = "正在保存..."

        print("开始保存3D模型数据到云端")

        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false)
        { _ in
            DispatchQueue.main.async
            {
                if self.isSavingModels
                {
                    self.isSavingModels = false
                    self.modelsSaveStatus = "保存超时,请检查网络后重试"

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3)
                    {
                        self.modelsSaveStatus = ""
                    }
                }
            }
        }

        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudModelOperationResult"),
            object: nil,
            queue: .main
        )
        { notification in
            timeoutTimer.invalidate()

            if let userInfo = notification.userInfo,
               let success = userInfo["success"] as? Bool,
               let message = userInfo["message"] as? String
            {
                DispatchQueue.main.async
                {
                    self.isSavingModels = false
                    self.modelsSaveStatus = message

                    print("云端模型操作结果: \(success ? "成功" : "失败") - \(message)")

                    let displayTime: TimeInterval = success ? 2.0 : 5.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + displayTime)
                    {
                        self.modelsSaveStatus = ""
                    }
                }
            }

            if let observer = observer
            {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        let userInfo: [String: Any] = [
            "action": "saveModelsToCloud",
            "locationId": question.locationID,
            "questionId": question.id,
            "userId": NSNull(),
        ]

        NotificationCenter.default.post(
            name: NSNotification.Name("CloudModelOperation"),
            object: nil,
            userInfo: userInfo
        )
    }

    public func handleSendReply()
    {
        let trimmedText = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty
        else
        {
            replyError = "回复内容不能为空"
            return
        }

        if trimmedText.count > 1000
        {
            replyError = "回复内容不能超过1000个字符"
            return
        }

        guard let currentUserId = userManager.getUserId()
        else
        {
            replyError = "请先登录后再回复"
            return
        }

        if let onSendReply = onSendReply
        {
            onSendReply(trimmedText)
            replyText = ""
            return
        }

        print("💬 准备发送回复: \(trimmedText.prefix(50))...")

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

                        self.loadQuestionAnswers()

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
                    self.replyError = "网络错误,请检查网络连接后重试"
                    print("❌ 发送回复网络错误: \(error)")
                }
            }
        }
    }

    public func loadQuestionAnswers()
       {
           // 1. 如果正在加载，不要重复请求
           guard !isLoadingAnswers else {
               print("⏳ 已有加载任务进行中，忽略重复请求")
               return
           }
           
           // 2. 防抖：如果距离上次加载不到0.5秒，忽略
           let now = Date()
           if now.timeIntervalSince(lastRefreshTime) < 0.5 {
               print("⏱️ 请求过于频繁，忽略此次请求")
               return
           }
           lastRefreshTime = now
           
           // 3. 取消之前的任务
           loadTask?.cancel()
           
           isLoadingAnswers = true
           answersError = nil
           questionAnswers = nil

           print("📄 开始加载问题答案: questionId=\(question.id)")

           // 4. 创建新的任务
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
                       self.answersError = nil
                       print("✅ 成功加载问题答案: \(answersResponse.answerCount) 个答案")

                       for (index, answer) in answersResponse.answers.enumerated()
                       {
                           print("   答案 \(index + 1): \(answer.username) - \(answer.content.prefix(50))...")
                       }
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
                       self.answersError = "服务器错误: \(message)"
                       print("❌ 加载问题答案失败 - 服务器错误: \(message)")
                   }
               }
               catch
               {
                   await MainActor.run
                   {
                       self.isLoadingAnswers = false
                       self.answersError = "加载失败: \(error.localizedDescription)"
                       print("❌ 加载问题答案失败: \(error)")
                   }
               }
           }
       }

    private func handleModelColorChange(_ newColor: Color)
    {
        guard let model = selectedModelForEdit
        else
        {
            print("没有选中的模型进行颜色变更")
            return
        }

        print("RealityWindow: 变更模型颜色 \(model.id)")

        let colorComponents = newColor.cgColor?.components ?? [0, 0, 1, 1]
        let userInfo: [String: Any] = [
            "action": "changeColor",
            "modelId": model.id.uuidString,
            "color": [
                "red": Float(colorComponents[0]),
                "green": Float(colorComponents[1]),
                "blue": Float(colorComponents[2]),
                "alpha": Float(colorComponents.count > 3 ? colorComponents[3] : 1.0),
            ],
        ]

        NotificationCenter.default.post(
            name: NSNotification.Name("ModelEditOperation"),
            object: nil,
            userInfo: userInfo
        )

        print("已发送颜色变更通知")
    }

    public func openAIAssistantWindow()
    {
        print("Reality模式下打开AI助手窗口")

        NotificationCenter.default.post(
            name: NSNotification.Name("OpenAIAssistantWindow"),
            object: nil,
            userInfo: [
                "question": targetQuestionManager.currentQuestion,
                "mode": "reality",
            ]
        )

        openWindow(id: "AIAssistantWindow")

        print("AI助手窗口打开指令已发送: \(targetQuestionManager.currentQuestion.title)")
    }

    // MARK: - Reality环境动画

    public func realityAppearAnimation()
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

    public func realityDisappearAnimation()
    {
        contentOpacity = 0
        headerScale = 0.8
        scrollViewOffset = 30
    }

    // MARK: - 标准环境动画

    public func standardAppearAnimation()
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

    public func standardDisappearAnimation()
    {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9))
        {
            animationOffset = 400
            animationOpacity = 0
        }
    }
}

// MARK: - 便捷构造器扩展

extension QuestionDetailModalWithTabs
{
    static func forReality(
        question: Question,
        isPresented: Binding<Bool>,
        onClose: @escaping () -> Void,
        onSendReply: ((String) -> Void)? = nil,
        onRefreshAnswers: (() -> Void)? = nil
    ) -> QuestionDetailModalWithTabs
    {
        QuestionDetailModalWithTabs(
            question: question,
            isPresented: isPresented,
            onClose: onClose,
            onSendReply: onSendReply,
            onRefreshAnswers: onRefreshAnswers,
            isRealityEnvironment: true
        )
    }

    static func standard(
        question: Question,
        isPresented: Binding<Bool>,
        onClose: @escaping () -> Void,
        onSendReply: ((String) -> Void)? = nil,
        onAttachFile: (() -> Void)? = nil,
        onRefreshAnswers: (() -> Void)? = nil
    ) -> QuestionDetailModalWithTabs
    {
        QuestionDetailModalWithTabs(
            question: question,
            isPresented: isPresented,
            onClose: onClose,
            onSendReply: onSendReply,
            onAttachFile: onAttachFile,
            onRefreshAnswers: onRefreshAnswers,
            isRealityEnvironment: false
        )
    }
}
