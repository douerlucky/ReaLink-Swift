import SwiftUI
import MapKit

class WindowStateManager: ObservableObject {
    @Published var isRealityWindowOpen = false
    @Published var isControlMenuWindowOpen = false
    @Published var isImmersiveSpaceOpen = false
}

@MainActor
class VRSessionManager: ObservableObject {
    @Published var currentLocationTitle: String = "未知位置"
    @Published var panoramaImageName: String = ""
    @Published var panoramaImageURL: String = ""
    @Published var isLoadingPanorama: Bool = false
    
    static let shared = VRSessionManager()
    
    private let updateQueue = DispatchQueue(label: "VRSessionManager.update", qos: .userInitiated)
    
    private init() {}
    
    func updateLocationInfo(title: String, panoramaImage: String) {
        Task { @MainActor in
            self.currentLocationTitle = title
            self.panoramaImageName = panoramaImage
            self.panoramaImageURL = ""
            print("更新本地全景图: \(panoramaImage)")
        }
    }
    
    func updateLocationInfoWithURL(title: String, panoramaImageURL: String) {
        Task { @MainActor in
            self.currentLocationTitle = title
            self.panoramaImageURL = panoramaImageURL
            self.panoramaImageName = ""
            print("更新URL全景图: \(panoramaImageURL)")
        }
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
            self.panoramaImageName = ""
            self.panoramaImageURL = ""
            self.isLoadingPanorama = false
            print("重置全景图状态")
        }
    }
    
    func getCurrentState() -> (title: String, imageName: String, imageURL: String, isLoading: Bool) {
        return (currentLocationTitle, panoramaImageName, panoramaImageURL, isLoadingPanorama)
    }
}

@MainActor
class TargetQuesitonManager: ObservableObject {
    @Published var currentQuestion: Question = Question_1
    
    static let shared = TargetQuesitonManager()
    
    private init() {}
    
    func updateQuestion(question: Question) {
        currentQuestion = question
    }
}

@main
struct ReaLinkApp: App {
    @State private var appModel = AppModel()
    @StateObject private var vrManager = VRSessionManager.shared
    @StateObject private var targetQuestionManager = TargetQuesitonManager.shared
    @StateObject private var windowStateManager = WindowStateManager()
    @StateObject private var userManager = UserManager.shared
    
    // 🔥 新增：监听场景阶段
    @Environment(\.scenePhase) private var scenePhase
    
    // 🔥 新增：跟踪清理状态，避免重复执行
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
                // 🔥 关键修改：监听场景阶段变化
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
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

        WindowGroup(id: "ModelsListWindow") {
            ModelsListManagementView()
                .environmentObject(userManager)
                .frame(width: 400, height: 600)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)
        
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
        
        WindowGroup(id: "AIAssistantWindow") {
            AIAssistantWindow()
                .environmentObject(userManager)
                .environmentObject(targetQuestionManager)
                .environmentObject(vrManager)
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
                    print("🤖 独立AI助手窗口已打开")
                }
                .onDisappear {
                    print("🤖 独立AI助手窗口已关闭")
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 700)
        
        WindowGroup(id: "ControlMenuWindow") {
            ControlMenuWindow()
                .environmentObject(vrManager)
                .environmentObject(userManager)
                .onAppear {
                    windowStateManager.isControlMenuWindowOpen = true
                }
                .onDisappear {
                    windowStateManager.isControlMenuWindowOpen = false
                }
                .frame(width: 450)

        }
        .windowResizability(.contentSize)
        
        WindowGroup(id: "BrushControlWindow") {
            BrushControlWindow()
                .frame(width: 400)
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
        
        WindowGroup(id: "ModelControlWindow") {
            ModelControlWindow()
                .frame(width: 400)
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
    
    // MARK: - 🔥 场景阶段变化处理
    
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        print("📱 场景阶段变化: \(oldPhase) -> \(newPhase)")
        
        // 当进入后台或不活跃状态时，执行清理
        if (newPhase == .background || newPhase == .inactive) && oldPhase == .active {
            print("⚠️ 应用进入后台，开始清理全景模式...")
            performBackgroundCleanup()
        }
        
        // 当重新激活时，重置清理标志
        if newPhase == .active {
            isCleaningUp = false
            print("✅ 应用重新激活")
        }
    }
    
    // MARK: - 🔥 后台清理核心方法
    
    private func performBackgroundCleanup() {
        // 防止重复执行
        guard !isCleaningUp else {
            print("⏭️ 清理已在进行中，跳过")
            return
        }
        
        isCleaningUp = true
        print("🧹 【开始执行后台清理 - Vision Pro 已摘下】")
        
        Task { @MainActor in
            // 0️⃣ 🔥 先发送重置通知，让 BasicPanoramaView 清理状态
            NotificationCenter.default.post(
                name: NSNotification.Name("ResetAllVRStates"),
                object: nil
            )
            print("📢 已发送重置所有VR状态通知")
            
            // 等待一小段时间让通知处理完成
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
            
            // 1️⃣ 关闭所有关联窗口
            closeAllAssociatedWindows()
            
            // 2️⃣ 等待窗口关闭完成
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
            
            // 3️⃣ 关闭所有ImmersiveSpace
            await closeAllImmersiveSpaces()
            
            // 4️⃣ 重置所有状态
            resetAllStates()
            
            // 5️⃣ 确保回到MainTabView
            ensureMainTabViewActive()
            
            print("✅ 【后台清理完成 - 已恢复到初始状态】")
        }
    }
    
    // MARK: - 🔥 关闭所有ImmersiveSpace
    
    private func closeAllImmersiveSpaces() async {
        print("🌌 关闭所有沉浸式空间...")
        
        // 使用dismissImmersiveSpace()会关闭当前活动的沉浸式空间
        // visionOS会自动处理，无需指定ID
        if windowStateManager.isImmersiveSpaceOpen {
            do {
                // 🔥 关键：使用Environment获取dismissImmersiveSpace
                // 由于我们在App级别，需要通过发送通知来触发关闭
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloseAllImmersiveSpaces"),
                    object: nil
                )
                
                // 等待一小段时间确保关闭完成
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                
                print("✅ 沉浸式空间已关闭")
            } catch {
                print("⚠️ 等待沉浸式空间关闭时出错: \(error)")
            }
        } else {
            print("ℹ️ 没有活动的沉浸式空间")
        }
    }
    
    // MARK: - 🔥 关闭所有关联窗口
    
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
    
    // MARK: - 🔥 重置所有状态
    
    private func resetAllStates() {
        print("🔄 重置所有状态...")
        
        // 1. 重置窗口状态
        windowStateManager.isRealityWindowOpen = false
        windowStateManager.isControlMenuWindowOpen = false
        windowStateManager.isImmersiveSpaceOpen = false
        print("  ✓ 窗口状态已重置")
        
        // 2. 重置VR会话状态
        vrManager.resetPanoramaState()
        print("  ✓ VR会话状态已重置")
        
        // 3. 重置AppModel状态
        appModel.reset()
        print("  ✓ AppModel状态已重置")
        
        // 4. 发送全局重置通知
        NotificationCenter.default.post(
            name: NSNotification.Name("ResetAllVRStates"),
            object: nil
        )
        print("  ✓ 全局重置通知已发送")
        
        print("✅ 所有状态已重置")
    }
    
    // MARK: - 🔥 确保MainTabView激活
    
    private func ensureMainTabViewActive() {
        print("🏠 确保MainTabView激活...")
        
        // 重置到Explore标签页（第一个标签）
        appModel.selectedTab = 0
        
        // 关闭全屏地图和问题面板
        appModel.hideFullscreenMap()
        appModel.hideQuestionsPanel()
        
        print("✅ MainTabView已激活，位于Explore标签页")
    }
}
