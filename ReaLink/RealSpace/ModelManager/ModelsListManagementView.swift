//
//  ModelsListManagementView.swift
//  ReaLink
//
//  场景模型管理视图 - 单栏切换版本（400x600）
//

import SwiftUI
import RealityKit

// MARK: - 查看模式枚举
enum ViewMode: String, CaseIterable {
    case allModels = "所有模型"
    case byUser = "用户分类"
    case byType = "模型分类"
    
    var icon: String {
        switch self {
        case .allModels: return "cube.transparent"
        case .byUser: return "person.2.fill"
        case .byType: return "square.grid.2x2.fill"
        }
    }
}

struct ModelsListManagementView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismissWindow) var dismissWindow
    
    @State private var placedModels: [ModelInfo] = []
    @State private var isLoading = false
    @State private var currentMode: ViewMode = .allModels
    
    // 🔥 用户过滤状态
    @State private var hiddenUserIds: Set<Int64> = []
    
    // 🔥 模型类型过滤状态
    @State private var hiddenModelTypes: Set<ModelType> = []
    
    // 🔥 选中的模型ID（用于高亮显示）
    @State private var selectedModelId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            TopToolbar(
                currentMode: $currentMode,
                isLoading: isLoading,
                modelCount: filteredModels.count,
                onRefresh: loadPlacedModels,
                onClose: {
                    dismissWindow(id: "ModelsListWindow")
                }
            )
            
            Divider()
            
            // 主内容区域
            ZStack {
                switch currentMode {
                case .allModels:
                    AllModelsView(
                        models: filteredModels,
                        selectedModelId: $selectedModelId,
                        onToggleVisibility: toggleModelVisibility
                    )
                    
                case .byUser:
                    UserCategoryView(
                        models: placedModels,
                        hiddenUserIds: $hiddenUserIds,
                        currentUserId: userManager.getUserId() ?? -1,
                        onToggleUser: toggleUserVisibility
                    )
                    
                case .byType:
                    ModelTypeCategoryView(
                        models: placedModels,
                        hiddenModelTypes: $hiddenModelTypes,
                        onToggleType: toggleModelTypeVisibility
                    )
                }
                
                // 加载状态遮罩
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("加载模型中...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
        .frame(width: 400, height: 600)
        .onAppear {
            print("🪟 模型管理窗口已打开，自动加载数据")
            loadPlacedModels()
        }
    }
    
    // MARK: - 计算属性：过滤后的模型
    
    private var filteredModels: [ModelInfo] {
        placedModels.filter { model in
            // 过滤被隐藏的用户
            if let userId = model.userId, hiddenUserIds.contains(userId) {
                return false
            }
            
            // 过滤被隐藏的模型类型
            if hiddenModelTypes.contains(model.type) {
                return false
            }
            
            return true
        }
    }
    
    // MARK: - 数据加载
    
    private func loadPlacedModels() {
        isLoading = true
        print("📋 开始请求场景模型列表...")
        
        // 发送请求
        NotificationCenter.default.post(
            name: NSNotification.Name("RequestPlacedModelsList"),
            object: nil
        )
        
        // 监听返回的模型数据
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PlacedModelsListResponse"),
            object: nil,
            queue: .main
        ) { notification in
            if let models = notification.userInfo?["models"] as? [ModelInfo] {
                self.placedModels = models
                self.isLoading = false
                print("✅ 成功加载 \(models.count) 个模型")
                
                // 打印调试信息
                let uniqueUsers = Set(models.compactMap { $0.userId })
                let uniqueTypes = Set(models.map { $0.type })
                print("📊 统计: \(uniqueUsers.count) 个用户, \(uniqueTypes.count) 种模型类型")
            }
            
            // 移除观察者
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
            }
        }
        
        // 3秒后如果还没有数据，取消加载状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.isLoading {
                self.isLoading = false
                print("⏱️ 模型列表加载超时")
            }
        }
    }
    
    // MARK: - 操作方法
    
    private func toggleModelVisibility(_ modelId: UUID) {
        NotificationCenter.default.post(
            name: NSNotification.Name("ToggleModelVisibility"),
            object: nil,
            userInfo: [
                "modelId": modelId.uuidString,
                "isHidden": true // 这里会被场景根据当前状态切换
            ]
        )
    }
    
    private func toggleUserVisibility(_ userId: Int64) {
        if hiddenUserIds.contains(userId) {
            hiddenUserIds.remove(userId)
            print("👀 显示用户 \(userId) 的所有模型")
        } else {
            hiddenUserIds.insert(userId)
            print("🙈 隐藏用户 \(userId) 的所有模型")
        }
        
        // 批量更新该用户的所有模型可见性
        let userModels = placedModels.filter { $0.userId == userId }
        let isHidden = hiddenUserIds.contains(userId)
        
        for model in userModels {
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleModelVisibility"),
                object: nil,
                userInfo: [
                    "modelId": model.id.uuidString,
                    "isHidden": isHidden
                ]
            )
        }
    }
    
    private func toggleModelTypeVisibility(_ modelType: ModelType) {
        if hiddenModelTypes.contains(modelType) {
            hiddenModelTypes.remove(modelType)
            print("👀 显示所有 \(modelType.displayName)")
        } else {
            hiddenModelTypes.insert(modelType)
            print("🙈 隐藏所有 \(modelType.displayName)")
        }
        
        // 批量更新该类型的所有模型可见性
        let typeModels = placedModels.filter { $0.type == modelType }
        let isHidden = hiddenModelTypes.contains(modelType)
        
        for model in typeModels {
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleModelVisibility"),
                object: nil,
                userInfo: [
                    "modelId": model.id.uuidString,
                    "isHidden": isHidden
                ]
            )
        }
    }
}

// MARK: - 顶部工具栏

struct TopToolbar: View {
    @Binding var currentMode: ViewMode
    let isLoading: Bool
    let modelCount: Int
    let onRefresh: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("场景模型管理")
                    .font(.headline)
                
                Spacer()
                
                // 刷新按钮
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(isLoading ? .gray : .blue)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                
                // 关闭按钮
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width:64,height:64)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .buttonBorderShape(.circle)  // 添加圆形边框
                .hoverEffect(.highlight)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 模式切换按钮
            HStack(spacing: 8) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: currentMode == mode,
                        count: getCount(for: mode)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentMode = mode
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }
    
    private func getCount(for mode: ViewMode) -> Int {
        switch mode {
        case .allModels:
            return modelCount
        case .byUser, .byType:
            return 0 // 不显示数量
        }
    }
}

// MARK: - 模式切换按钮

struct ModeButton: View {
    let mode: ViewMode
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.subheadline)
                
                Text(mode.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 所有模型视图

struct AllModelsView: View {
    let models: [ModelInfo]
    @Binding var selectedModelId: UUID?
    let onToggleVisibility: (UUID) -> Void
    
    var body: some View {
        ScrollView {
            if models.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("暂无模型")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(models) { model in
                        ModelCompactItem(
                            modelInfo: model,
                            isSelected: selectedModelId == model.id,
                            onToggleVisibility: {
                                onToggleVisibility(model.id)
                            },
                            onSelect: {
                                selectedModelId = model.id
                            }
                        )
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - 用户分类视图

struct UserCategoryView: View {
    let models: [ModelInfo]
    @Binding var hiddenUserIds: Set<Int64>
    let currentUserId: Int64
    let onToggleUser: (Int64) -> Void
    
    // 按用户分组
    private var userGroups: [(userId: Int64, username: String, avatarUrl: String?, models: [ModelInfo])] {
        let grouped = Dictionary(grouping: models) { $0.userId ?? -1 }
        return grouped.map { userId, userModels in
            let username = userModels.first?.username ?? "未知用户"
            let avatarUrl = userModels.first?.avatarUrl
            return (userId: userId, username: username, avatarUrl: avatarUrl, models: userModels)
        }.sorted { $0.username < $1.username }
    }
    
    var body: some View {
        ScrollView {
            if userGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("暂无用户")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(userGroups, id: \.userId) { group in
                        UserCategoryCard(
                            userId: group.userId,
                            username: group.username,
                            modelCount: group.models.count,
                            avatarUrl: group.avatarUrl,
                            isHidden: hiddenUserIds.contains(group.userId),
                            isCurrentUser: group.userId == currentUserId,
                            onToggle: {
                                onToggleUser(group.userId)
                            }
                        )
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - 模型分类视图

struct ModelTypeCategoryView: View {
    let models: [ModelInfo]
    @Binding var hiddenModelTypes: Set<ModelType>
    let onToggleType: (ModelType) -> Void
    
    // 按类型分组
    private var typeGroups: [(type: ModelType, models: [ModelInfo])] {
        let grouped = Dictionary(grouping: models) { $0.type }
        return grouped.map { ($0.key, $0.value) }
            .sorted { $0.type.displayName < $1.type.displayName }
    }
    
    var body: some View {
        ScrollView {
            if typeGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("暂无模型类型")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(typeGroups, id: \.type) { group in
                        ModelTypeCategoryCard(
                            modelType: group.type,
                            modelCount: group.models.count,
                            isHidden: hiddenModelTypes.contains(group.type),
                            onToggle: {
                                onToggleType(group.type)
                            }
                        )
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - 紧凑模型列表项

struct ModelCompactItem: View {
    let modelInfo: ModelInfo
    let isSelected: Bool
    let onToggleVisibility: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 3D预览
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(modelInfo.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Model3DPreview(modelType: modelInfo.type)
                        .frame(width: 40, height: 40)
                }
                
                // 模型信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelInfo.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(modelInfo.username)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    
                    if let text = modelInfo.text, !text.isEmpty {
                        Text(text)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 可见性按钮
                Button(action: onToggleVisibility) {
                    Image(systemName: "eye.fill")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : modelInfo.color.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 用户分类卡片

struct UserCategoryCard: View {
    let userId: Int64
    let username: String
    let modelCount: Int
    let avatarUrl: String?
    let isHidden: Bool
    let isCurrentUser: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 头像
                if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                
                // 用户信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if isCurrentUser {
                            Text("(我)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("\(modelCount) 个模型")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 状态图标
                Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                    .font(.title3)
                    .foregroundColor(isHidden ? .gray : .green)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .opacity(isHidden ? 0.5 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHidden ? Color.gray.opacity(0.3) : Color.green.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 模型类型分类卡片

struct ModelTypeCategoryCard: View {
    let modelType: ModelType
    let modelCount: Int
    let isHidden: Bool
    let onToggle: () -> Void
    
    private var typeColor: Color {
        switch modelType {
        case .cube: return Color.blue.opacity(0.2)
        case .sphere: return Color.green.opacity(0.2)
        case .cylinder: return Color.orange.opacity(0.2)
        case .cone: return Color.purple.opacity(0.2)
        case .capsule: return Color.pink.opacity(0.2)
        case .sign: return Color.brown.opacity(0.2)
        }
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 模型预览
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(typeColor)
                        .frame(width: 50, height: 50)
                    
                    Model3DPreview(modelType: modelType)
                        .frame(width: 40, height: 40)
                }
                
                // 类型信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(modelCount) 个模型")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 状态图标
                Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                    .font(.title3)
                    .foregroundColor(isHidden ? .gray : .orange)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .opacity(isHidden ? 0.5 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHidden ? Color.gray.opacity(0.3) : Color.orange.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ModelInfo 结构（保持不变）

struct ModelInfo: Identifiable {
    let id: UUID
    let type: ModelType
    let username: String
    let color: Color
    let text: String?
    let userId: Int64?
    let avatarUrl: String?
    
    init(id: UUID, type: ModelType, username: String, color: Color, text: String? = nil, userId: Int64? = nil, avatarUrl: String? = nil) {
        self.id = id
        self.type = type
        self.username = username
        self.color = color
        self.text = text
        self.userId = userId
        self.avatarUrl = avatarUrl
    }
}
