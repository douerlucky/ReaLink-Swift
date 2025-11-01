import SwiftUI
import MapKit

// MARK: - ✅ 增强版窗口状态管理器
class WindowStateManager: ObservableObject {
    // MARK: - 单例
    static let shared = WindowStateManager()
    
    // MARK: - 窗口状态属性
    
    /// RealityWindow - 问题详情窗口
    @Published var isRealityWindowOpen = false {
        didSet {
            if isRealityWindowOpen != oldValue {
                print("🪟 [RealityWindow] 状态变更: \(isRealityWindowOpen ? "打开" : "关闭")")
            }
        }
    }
    
    /// ControlMenuWindow - 控制菜单窗口
    @Published var isControlMenuWindowOpen = false {
        didSet {
            if isControlMenuWindowOpen != oldValue {
                print("🪟 [ControlMenuWindow] 状态变更: \(isControlMenuWindowOpen ? "打开" : "关闭")")
            }
        }
    }
    
    /// ModelControlWindow - 模型控制窗口
    @Published var isModelControlWindowOpen = false {
        didSet {
            if isModelControlWindowOpen != oldValue {
                print("🪟 [ModelControlWindow] 状态变更: \(isModelControlWindowOpen ? "打开" : "关闭")")
            }
        }
    }
    
    /// AIAssistantWindow - AI助手窗口
    @Published var isAIAssistantWindowOpen = false {
        didSet {
            if isAIAssistantWindowOpen != oldValue {
                print("🪟 [AIAssistantWindow] 状态变更: \(isAIAssistantWindowOpen ? "打开" : "关闭")")
            }
        }
    }
    
    /// ModelsListWindow - 模型列表窗口
    @Published var isModelsListWindowOpen = false {
        didSet {
            if isModelsListWindowOpen != oldValue {
                print("🪟 [ModelsListWindow] 状态变更: \(isModelsListWindowOpen ? "打开" : "关闭")")
            }
        }
    }
    
    /// BrushControlWindow - 画笔控制窗口
    @Published var isBrushControlWindowOpen = false {
        didSet {
            if isBrushControlWindowOpen != oldValue {
                print("🪟 [BrushControlWindow] 状态变更: \(isBrushControlWindowOpen ? "打开" : "关闭")")
            }
        }
    }
    
    /// ImmersiveSpace - 沉浸式空间状态
    @Published var isImmersiveSpaceOpen = false {
        didSet {
            if isImmersiveSpaceOpen != oldValue {
                print("🌌 [ImmersiveSpace] 状态变更: \(isImmersiveSpaceOpen ? "打开" : "关闭")")
            }
        }
    }
    
    // MARK: - 初始化
    
    public init() {
        setupNotificationListeners()
        print("✅ WindowStateManager 已初始化")
    }
    
    // MARK: - 通知监听
    
    private func setupNotificationListeners() {
        // 监听各个窗口的关闭通知
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RealityWindowClosed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isRealityWindowOpen = false
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ControlMenuWindowClosed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isControlMenuWindowOpen = false
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ModelControlWindowClosed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isModelControlWindowOpen = false
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AIAssistantWindowClosed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAIAssistantWindowOpen = false
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ModelsListWindowClosed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isModelsListWindowOpen = false
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BrushControlWindowClosed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isBrushControlWindowOpen = false
        }
        
        // 监听重置所有状态的通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ResetAllVRStates"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetAllWindowStates()
        }
        
        print("✅ WindowStateManager 通知监听器已设置")
    }
    
    // MARK: - 公共方法
    
    /// 检查是否所有窗口都已关闭
    /// - Returns: 如果所有窗口都关闭返回 true
    func areAllWindowsClosed() -> Bool {
        let allClosed = !isRealityWindowOpen &&
                       !isControlMenuWindowOpen &&
                       !isModelControlWindowOpen &&
                       !isAIAssistantWindowOpen &&
                       !isModelsListWindowOpen &&
                       !isBrushControlWindowOpen
        
        if !allClosed {
            print("⚠️【窗口状态】还有窗口未关闭:")
            printCurrentWindowStates()
        } else {
            print("✅【窗口状态】所有窗口都已关闭")
        }
        
        return allClosed
    }
    
    /// ✅ 检查关键窗口是否都已关闭（不包括辅助窗口）
    /// 这是用于OK手势检测的核心方法
    /// - Returns: 如果关键窗口都关闭返回 true
    func areCriticalWindowsClosed() -> Bool {
        // 关键窗口：RealityWindow、ControlMenuWindow
        // 这些窗口打开时不应该响应OK手势
        let criticalClosed = !isRealityWindowOpen && !isControlMenuWindowOpen
        
        if !criticalClosed {
            print("⚠️【关键窗口检查】还有关键窗口未关闭:")
            if isRealityWindowOpen {
                print("   - RealityWindow: 打开中")
            }
            if isControlMenuWindowOpen {
                print("   - ControlMenuWindow: 打开中")
            }
        } else {
            print("✅【关键窗口检查】所有关键窗口都已关闭，可以响应OK手势")
        }
        
        return criticalClosed
    }
    
    /// 重置所有窗口状态
    func resetAllWindowStates() {
        print("🧹【WindowStateManager】重置所有窗口状态")
        
        isRealityWindowOpen = false
        isControlMenuWindowOpen = false
        isModelControlWindowOpen = false
        isAIAssistantWindowOpen = false
        isModelsListWindowOpen = false
        isBrushControlWindowOpen = false
        
        print("✅【WindowStateManager】所有窗口状态已重置")
    }
    
    /// 打印当前所有窗口状态（调试用）
    func printCurrentWindowStates() {
        print("📊【当前窗口状态】")
        print("   - RealityWindow: \(isRealityWindowOpen ? "打开" : "关闭")")
        print("   - ControlMenuWindow: \(isControlMenuWindowOpen ? "打开" : "关闭")")
        print("   - ModelControlWindow: \(isModelControlWindowOpen ? "打开" : "关闭")")
        print("   - AIAssistantWindow: \(isAIAssistantWindowOpen ? "打开" : "关闭")")
        print("   - ModelsListWindow: \(isModelsListWindowOpen ? "打开" : "关闭")")
        print("   - BrushControlWindow: \(isBrushControlWindowOpen ? "打开" : "关闭")")
        print("   - ImmersiveSpace: \(isImmersiveSpaceOpen ? "打开" : "关闭")")
    }
}

// MARK: - VRSessionManager (保持原样)
@MainActor
class VRSessionManager: ObservableObject {
    @Published var currentLocationTitle: String = "未知位置"
    @Published var currentLocationId: Int64 = 0
    @Published var panoramaImageName: String = ""
    @Published var panoramaImageURL: String = ""
    @Published var isLoadingPanorama: Bool = false
    
    static let shared = VRSessionManager()
    
    private let updateQueue = DispatchQueue(label: "VRSessionManager.update", qos: .userInitiated)
    
    private init() {}
    
    func updateLocationInfo(title: String, locationId: Int64, panoramaImage: String) {
        Task { @MainActor in
            self.currentLocationTitle = title
            self.currentLocationId = locationId
            self.panoramaImageName = panoramaImage
            self.panoramaImageURL = ""
            
            // 🔥 关键修复：同步设置 SceneManager 的位置ID
            SceneManager.shared?.currentLocationId = locationId
            
            print("✅ 更新本地全景图: \(panoramaImage)")
            print("   - Location ID: \(locationId)")
            print("   - SceneManager.currentLocationId: \(SceneManager.shared?.currentLocationId ?? -1)")
        }
    }
    
    // 🔥 增强版：自动从URL中解析locationId（动态适配）
    func updateLocationInfoWithURL(title: String, locationId: Int64? = nil, panoramaImageURL: String) {
        Task { @MainActor in
            // 🎯 优先使用传入的 locationId，如果为nil则从URL自动解析
            let finalLocationId: Int64
            if let providedLocationId = locationId {
                finalLocationId = providedLocationId
                print("✅【使用提供的locationId】: \(finalLocationId)")
            } else {
                // 从URL中解析 locationId
                finalLocationId = self.extractLocationIdFromURL(panoramaImageURL) ?? 0
                if finalLocationId > 0 {
                    print("✅【自动解析】从URL中提取 locationId: \(finalLocationId)")
                } else {
                    print("⚠️【自动解析】无法从URL中提取 locationId，使用默认值0")
                }
            }
            
            self.currentLocationTitle = title
            self.currentLocationId = finalLocationId
            self.panoramaImageURL = panoramaImageURL
            self.panoramaImageName = ""
            
            // 🔥 关键修复：同步设置 SceneManager 的位置ID
            SceneManager.shared?.currentLocationId = finalLocationId
            
            print("✅ 更新URL全景图: \(title)")
            print("   - Location ID: \(finalLocationId)")
            print("   - URL: \(panoramaImageURL)")
            print("   - SceneManager.currentLocationId: \(SceneManager.shared?.currentLocationId ?? -1)")
        }
    }
    
    // 🔥 新增：从URL中提取 locationId
    /// 支持的URL格式：
    /// - http://example.com/uploads/location_10_1761676957072.jpg
    /// - /uploads/location_10_xxx.jpg
    /// - location_10_xxx.jpg
    /// - http://example.com/uploads/panoramas/location_10_xxx.jpg
    private func extractLocationIdFromURL(_ url: String) -> Int64? {
        // 使用正则表达式匹配 location_数字 格式
        let pattern = "location_(\\d+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("❌【URL解析】正则表达式创建失败")
            return nil
        }
        
        let nsString = url as NSString
        let results = regex.matches(in: url, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results.first, match.numberOfRanges > 1 {
            let locationIdRange = match.range(at: 1)
            let locationIdString = nsString.substring(with: locationIdRange)
            
            if let locationId = Int64(locationIdString) {
                print("✅【URL解析】成功提取 locationId: \(locationId) (从 \(url))")
                return locationId
            }
        }
        
        print("⚠️【URL解析】无法从URL中提取 locationId: \(url)")
        return nil
    }
    
    func setLoadingState(_ isLoading: Bool) {
        Task { @MainActor in
            self.isLoadingPanorama = isLoading
            print("设置加载状态: \(isLoading)")
        }
    }
    
    var isUsingURL: Bool {
        return !panoramaImageURL.isEmpty
    }
    
    func resetPanoramaState() {
        Task { @MainActor in
            self.currentLocationId = 0
            self.panoramaImageName = ""
            self.panoramaImageURL = ""
            self.isLoadingPanorama = false
            print("重置全景图状态")
        }
    }
    
    func getCurrentState() -> (title: String, locationId: Int64, imageName: String, imageURL: String, isLoading: Bool) {
        return (currentLocationTitle, currentLocationId, panoramaImageName, panoramaImageURL, isLoadingPanorama)
    }
}

// MARK: - TargetQuesitonManager (保持原样)
@MainActor
class TargetQuesitonManager: ObservableObject {
    @Published var currentQuestion: Question = Question_1
    
    static let shared = TargetQuesitonManager()
    
    private init() {}
    
    func updateQuestion(question: Question) {
        currentQuestion = question
    }
}

// MARK: - 主应用
@main
struct ReaLinkApp: App {
    @State private var appModel = AppModel()
    @StateObject private var vrManager = VRSessionManager.shared
    @StateObject private var targetQuestionManager = TargetQuesitonManager.shared
    @StateObject private var windowStateManager = WindowStateManager.shared  // ✅ 使用单例
    @StateObject private var userManager = UserManager.shared
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var isCleaningUp = false
    
    var body: some Scene {
        // 主标签页窗口
        WindowGroup(id: "MainWindow") {
            MainTabView()
                .environment(appModel)
                .environmentObject(vrManager)
                .environmentObject(windowStateManager)
                .environmentObject(userManager)
                .onAppear {
                    print("🚀 应用启动，当前登录状态: \(userManager.isLoggedIn)")
                    if userManager.isLoggedIn, let username = userManager.getUsername() {
                        print("👋 欢迎回来, \(username)!")
                        
                        Task {
                            await userManager.updateLocationOnAppStart()
                        }
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceBackgroundCleanup"))) { _ in
                    print("🚨【收到强制后台清理通知】")
                    if !isCleaningUp {
                        performBackgroundCleanup()
                    }
                }
        }
        
        // 沉浸式空间
        ImmersiveSpace(id: "Realistic3DScene") {
            BasicPanoramaView()
                .environmentObject(vrManager)
                .environmentObject(targetQuestionManager)
                .environmentObject(userManager)
                .environmentObject(windowStateManager)
                .onAppear {
                    windowStateManager.isImmersiveSpaceOpen = true
                    print("🌌 沉浸式空间已打开")
                }
                .onDisappear {
                    windowStateManager.isImmersiveSpaceOpen = false
                    print("🌌 沉浸式空间已关闭")
                }
        }
        .upperLimbVisibility(.visible)
        .immersionStyle(selection: .constant(.full), in: .full, .progressive)
        
        ImmersiveSpace(id: "Question3DSetSpace") {
            Question3DSet(
                onPositionSet: { position in
                    print("🎯 问题位置已设置: \(position)")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("QuestionPositionSet"),
                        object: nil,
                        userInfo: ["position": position]
                    )
                },
                onCancel: {
                    print("❌ 取消设置问题位置")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("QuestionPositionCancel"),
                        object: nil
                    )
                }
            )
            .environmentObject(vrManager)
            .environmentObject(userManager)
            .onAppear {
                print("🎯 问题3D位置设置空间已打开")
            }
            .onDisappear {
                print("🎯 问题3D位置设置空间已关闭")
            }
        }
        .upperLimbVisibility(.visible)
        .immersionStyle(selection: .constant(.full), in: .full)

        // ✅ ModelsListWindow - 添加状态管理
        WindowGroup(id: "ModelsListWindow") {
            ModelsListManagementView()
                .environmentObject(userManager)
                .environmentObject(windowStateManager)  // ✅ 注入
                .frame(width: 400, height: 600)
                .onAppear {
                    windowStateManager.isModelsListWindowOpen = true
                }
                .onDisappear {
                    windowStateManager.isModelsListWindowOpen = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ModelsListWindowClosed"),
                        object: nil
                    )
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)
        
        // ✅ RealityWindow - 已有状态管理
        WindowGroup(id: "RealityWindow") {
            RealityWindowView()
                .environmentObject(vrManager)
                .environmentObject(targetQuestionManager)
                .environmentObject(userManager)
                .environmentObject(windowStateManager)
                .onAppear {
                    windowStateManager.isRealityWindowOpen = true
                    print("🟢 RealityWindow 已打开")
                }
                .onDisappear {
                    print("🔴 RealityWindow onDisappear 触发")
                    windowStateManager.isRealityWindowOpen = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RealityWindowClosed"),
                        object: nil
                    )
                    print("🔴 RealityWindow 已关闭，通知已发送")
                }
        }
        .windowResizability(.contentSize)
        
        // ✅ AIAssistantWindow - 添加状态管理
        WindowGroup(id: "AIAssistantWindow") {
            AIAssistantWindow()
                .environmentObject(userManager)
                .environmentObject(targetQuestionManager)
                .environmentObject(vrManager)
                .environmentObject(windowStateManager)  // ✅ 注入
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAIAssistantWindow"))) { notification in
                    print("🤖 AI助手窗口收到通知")
                    if let question = notification.userInfo?["question"] as? Question {
                        targetQuestionManager.updateQuestion(question: question)
                        print("🤖 AI助手窗口接收到问题: \(question.title)")
                        
                        if let mode = notification.userInfo?["mode"] as? String {
                            print("🤖 运行模式: \(mode)")
                        }
                    }
                }
                .onAppear {
                    windowStateManager.isAIAssistantWindowOpen = true
                    print("🤖 独立AI助手窗口已打开")
                }
                .onDisappear {
                    windowStateManager.isAIAssistantWindowOpen = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AIAssistantWindowClosed"),
                        object: nil
                    )
                    print("🤖 独立AI助手窗口已关闭")
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 700)
        
        // ✅ ControlMenuWindow - 已有状态管理
        WindowGroup(id: "ControlMenuWindow") {
            ControlMenuWindow()
                .environmentObject(vrManager)
                .environmentObject(userManager)
                .environmentObject(windowStateManager)  // ✅ 注入
                .onAppear {
                    windowStateManager.isControlMenuWindowOpen = true
                }
                .onDisappear {
                    windowStateManager.isControlMenuWindowOpen = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ControlMenuWindowClosed"),
                        object: nil
                    )
                }
                .frame(width: 450)
        }
        .windowResizability(.contentSize)
        
        // ✅ BrushControlWindow - 添加状态管理
        WindowGroup(id: "BrushControlWindow") {
            BrushControlWindow()
                .environmentObject(windowStateManager)  // ✅ 注入
                .frame(width: 400)
                .onAppear {
                    windowStateManager.isBrushControlWindowOpen = true
                }
                .onDisappear {
                    windowStateManager.isBrushControlWindowOpen = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("BrushControlWindowClosed"),
                        object: nil
                    )
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)
        
        ImmersiveSpace(id: "PaintingDebug") {
            PaintingDebug()
                .environmentObject(userManager)
                .onAppear {
                    print("🎨 绘画调试空间已打开")
                }
                .onDisappear {
                    print("🎨 绘画调试空间已关闭")
                }
        }
        .upperLimbVisibility(.visible)
        .immersionStyle(selection: .constant(.full), in: .full)
        
        // ✅ ModelControlWindow - 添加状态管理
        WindowGroup(id: "ModelControlWindow") {
            ModelControlWindow()
                .environmentObject(windowStateManager)  // ✅ 注入
                .frame(width: 400)
                .onAppear {
                    windowStateManager.isModelControlWindowOpen = true
                }
                .onDisappear {
                    windowStateManager.isModelControlWindowOpen = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ModelControlWindowClosed"),
                        object: nil
                    )
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 700)
        
        ImmersiveSpace(id: "ModelTestingSpace") {
            ModelTestingSpace()
                .environmentObject(userManager)
                .onAppear {
                    print("🧊 3D模型测试空间已打开")
                }
                .onDisappear {
                    print("🧊 3D模型测试空间已关闭")
                }
        }
        .upperLimbVisibility(.visible)
        .immersionStyle(selection: .constant(.full), in: .full)
    }
    
    // MARK: - 场景阶段变化处理
    
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        print("📱 场景阶段变化: \(oldPhase) -> \(newPhase)")
        
        if (newPhase == .background || newPhase == .inactive) && oldPhase == .active {
            print("⚠️ 应用进入后台，开始清理全景模式...")
            performBackgroundCleanup()
        }
        
        if newPhase == .active {
            isCleaningUp = false
            print("✅ 应用重新激活")
        }
    }
    
    // MARK: - 后台清理核心方法
    
    private func performBackgroundCleanup() {
        guard !isCleaningUp else {
            print("⏭️ 清理已在进行中，跳过")
            return
        }
        
        isCleaningUp = true
        print("🧹 【开始执行后台清理 - Vision Pro 已摘下】")
        
        Task { @MainActor in
            NotificationCenter.default.post(
                name: NSNotification.Name("ResetAllVRStates"),
                object: nil
            )
            print("📢 已发送重置所有VR状态通知")
            
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            closeAllAssociatedWindows()
            
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await closeAllImmersiveSpaces()
            
            resetAllStates()
            
            ensureMainTabViewActive()
            
            print("✅ 【后台清理完成 - 已恢复到初始状态】")
        }
    }
    
    // MARK: - 关闭所有ImmersiveSpace
    
    private func closeAllImmersiveSpaces() async {
        print("🌌 关闭所有沉浸式空间...")
        
        if windowStateManager.isImmersiveSpaceOpen {
            do {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloseAllImmersiveSpaces"),
                    object: nil
                )
                
                try await Task.sleep(nanoseconds: 500_000_000)
                
                print("✅ 沉浸式空间已关闭")
            } catch {
                print("⚠️ 等待沉浸式空间关闭时出错: \(error)")
            }
        } else {
            print("ℹ️ 没有活动的沉浸式空间")
        }
    }
    
    // MARK: - 关闭所有关联窗口
    
    private func closeAllAssociatedWindows() {
        print("🪟 关闭所有关联窗口...")
        
        let windowsToClose = [
            "RealityWindow",
            "ControlMenuWindow",
            "BrushControlWindow",
            "ModelControlWindow",
            "AIAssistantWindow",
            "ModelsListWindow"
        ]
        
        for windowId in windowsToClose {
            NotificationCenter.default.post(
                name: NSNotification.Name("DismissWindow"),
                object: nil,
                userInfo: ["windowId": windowId]
            )
            print("  🗑️ 请求关闭窗口: \(windowId)")
        }
        
        print("✅ 所有窗口关闭请求已发送")
    }
    
    // MARK: - 重置所有状态
    
    private func resetAllStates() {
        print("🔄 重置所有状态...")
        
        // ✅ 使用 WindowStateManager 的重置方法
        windowStateManager.resetAllWindowStates()
        print("  ✓ 窗口状态已重置")
        
        vrManager.resetPanoramaState()
        print("  ✓ VR会话状态已重置")
        
        appModel.reset()
        print("  ✓ AppModel状态已重置")
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ResetAllVRStates"),
            object: nil
        )
        print("  ✓ 全局重置通知已发送")
        
        print("✅ 所有状态已重置")
    }
    
    // MARK: - 确保MainTabView激活
    
    private func ensureMainTabViewActive() {
        print("🏠 确保MainTabView激活...")
        
        appModel.selectedTab = 0
        
        appModel.hideFullscreenMap()
        appModel.hideQuestionsPanel()
        
        print("✅ MainTabView已激活，位于Explore标签页")
    }
}
