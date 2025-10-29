import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        TabView(selection: Binding(
            get: { appModel.selectedTab },
            set: { appModel.selectedTab = $0 }
        )) {
            ExploreView()
                .tabItem {
                    Label("实景探索", image: "home_icon")
                }
                .tag(0)
            
            QandAView(searchContent: .constant(""))
                .tabItem {
                    Label("问答搜索", image: "search_icon")
                }
                .tag(1)
            
            QuestionView()
                .tabItem {
                    Label("智能提问", image: "ai_question_icon")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("个人中心", image: "Profile")
                }
                .tag(3)
        }
        .frame(minWidth: 1000, minHeight: 700)
        .environment(appModel)
        // 🔥 监听切换到问题提问页面的通知
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToQuestionTab"))) { _ in
            print("📱 切换到问题提问页面")
            appModel.selectedTab = 2
        }
        // 🔥 新增：监听关闭所有沉浸式空间的通知
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseAllImmersiveSpaces"))) { _ in
            print("🌌 MainTabView: 收到关闭沉浸式空间通知")
            Task {
                await dismissImmersiveSpace()
                print("✅ MainTabView: 沉浸式空间已关闭")
            }
        }
        // 🔥 新增：监听关闭窗口的通知
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissWindow"))) { notification in
            if let windowId = notification.userInfo?["windowId"] as? String {
                print("🪟 MainTabView: 收到关闭窗口通知 - \(windowId)")
                dismissWindow(id: windowId)
            }
        }
    }
}

struct DebugView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var isPaintingSpaceOpen = false
    @State private var isBrushControlOpen = false
    @State private var isModelTestingSpaceOpen = false
    @State private var isModelControlOpen = false
    @State private var answerResult = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    Text("开发调试中心")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("测试各种3D空间功能")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 15) {
                    Text("API测试")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        Task {
                            answerResult = await sendQuestion()
                        }
                    }) {
                        Label("发送测试请求", systemImage: "network")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    if !answerResult.isEmpty {
                        Text("响应结果: \(answerResult)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "paintbrush.pointed.fill")
                            .foregroundColor(.blue)
                        Text("空间绘画测试")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    Text("在3D空间中自由绘画和创作")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Button(action: {
                        Task {
                            if isPaintingSpaceOpen {
                                await dismissImmersiveSpace()
                                dismissWindow(id: "BrushControlWindow")
                                isPaintingSpaceOpen = false
                                isBrushControlOpen = false
                            } else {
                                await openImmersiveSpace(id: "PaintingDebug")
                                isPaintingSpaceOpen = true
                            }
                        }
                    }) {
                        Label(
                            isPaintingSpaceOpen ? "退出绘画空间" : "进入绘画空间",
                            systemImage: isPaintingSpaceOpen ? "xmark" : "paintpalette"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(isPaintingSpaceOpen ? .red : .blue)
                    
                    if isPaintingSpaceOpen {
                        Button(action: {
                            if isBrushControlOpen {
                                dismissWindow(id: "BrushControlWindow")
                                isBrushControlOpen = false
                            } else {
                                openWindow(id: "BrushControlWindow")
                                isBrushControlOpen = true
                            }
                        }) {
                            Label(
                                isBrushControlOpen ? "关闭画笔控制" : "打开画笔控制",
                                systemImage: "slider.horizontal.3"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.green)
                        Text("3D模型测试")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    Text("在3D空间中放置和操作各种模型")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Button(action: {
                        Task {
                            if isModelTestingSpaceOpen {
                                await dismissImmersiveSpace()
                                dismissWindow(id: "ModelControlWindow")
                                isModelTestingSpaceOpen = false
                                isModelControlOpen = false
                            } else {
                                await openImmersiveSpace(id: "ModelTestingSpace")
                                isModelTestingSpaceOpen = true
                            }
                        }
                    }) {
                        Label(
                            isModelTestingSpaceOpen ? "退出模型测试空间" : "进入模型测试空间",
                            systemImage: isModelTestingSpaceOpen ? "xmark" : "cube.transparent"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(isModelTestingSpaceOpen ? .red : .green)
                    
                    if isModelTestingSpaceOpen {
                        Button(action: {
                            if isModelControlOpen {
                                dismissWindow(id: "ModelControlWindow")
                                isModelControlOpen = false
                            } else {
                                openWindow(id: "ModelControlWindow")
                                isModelControlOpen = true
                            }
                        }) {
                            Label(
                                isModelControlOpen ? "关闭模型控制" : "打开模型控制",
                                systemImage: "gearshape.fill"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("功能说明", systemImage: "info.circle")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎨 空间绘画:")
                        Text("  • 使用手势在3D空间中绘制")
                        Text("  • 支持多种画笔和颜色")
                        
                        Text("\n🧊 3D模型测试:")
                        Text("  • 在空间中放置3D模型")
                        Text("  • 双指缩放调整大小")
                        Text("  • 支持悬停效果交互")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
            }
            .padding(40)
        }
        .frame(width: 600, height: 700)
        .background(.regularMaterial)
    }
}

#Preview(windowStyle: .automatic) {
    MainTabView()
        .environment(AppModel())
        .environmentObject(VRSessionManager.shared)
        .environmentObject(WindowStateManager())
        .environmentObject(UserManager.shared)
}
