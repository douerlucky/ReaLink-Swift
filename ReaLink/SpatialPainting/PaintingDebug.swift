//
//  PaintingDebug.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/8/18.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct PaintingDebug: View {
    @State private var rootEntity = Entity()
    
    // === 绘画相关状态 ===
    @State private var handTracking = PaintingHandTracking()  // 手部追踪
    @State private var canvas = PaintingCanvas()  // 绘画画布
    @State private var lastPinchPosition: SIMD3<Float>?  // 上次捏合位置
    @State private var isPinching = false  // 是否正在捏合
    @State private var isCurrentlyDrawing = false  // 是否正在绘画
    @StateObject private var brushManager = BrushManager.shared  // 使用现有的画笔管理器
    
    var body: some View {
        ZStack {
            // 主绘画视图
            RealityView { content in
                // 创建天空球
                let skybox = await createSkybox(imageName: "docklands_02")
                // 添加天空球和画布到场景
                rootEntity.addChild(skybox)
                rootEntity.addChild(canvas.root)
                content.add(rootEntity)
                
                print("🎨 绘画测试空间已初始化")
                
                // 添加实时更新组件
                rootEntity.components.set(ClosureComponent(closure: { deltaTime in
                    // 只有在绘画开启时才处理手部追踪
                    guard brushManager.isPaintingEnabled else { return }
                    
                    // 处理手部追踪数据
                    handleHandTracking()
                }))
                
            } update: { content in
                // 更新逻辑可以在这里添加
            }
            
            // 简化的状态指示器（右上角）
            VStack {
                HStack {
                    Spacer()
                    statusIndicator
                }
                Spacer()
            }
        }
        .task {
            // 启动手部追踪
            await handTracking.startTracking()
        }
        .onAppear {
            print("🎨 进入绘画测试模式")
            
            // 监听清空画布通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ClearCanvas"),
                object: nil,
                queue: .main
            ) { _ in
                clearCanvas()
            }
            
            // 监听撤回通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UndoLastStroke"),
                object: nil,
                queue: .main
            ) { _ in
                undoLastStroke()
            }
            
            // 【修复】添加云端操作监听器设置
            setupCloudOperationListener()
        }
        .onDisappear {
            print("🎨 退出绘画测试模式")
            // 移除通知监听
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ClearCanvas"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UndoLastStroke"), object: nil)
        }
    }
    
    // MARK: - 状态指示器
    private var statusIndicator: some View {
        VStack(spacing: 8) {
            // 绘画状态
            HStack {
                Circle()
                    .fill(brushManager.isPaintingEnabled ? .green : .red)
                    .frame(width: 12, height: 12)
                Text(brushManager.isPaintingEnabled ? "绘画已启用" : "绘画已禁用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if brushManager.isPaintingEnabled {
                // 操作状态指示
                HStack {
                    Circle()
                        .fill(isPinching ? .blue : .gray)
                        .frame(width: 8, height: 8)
                    Text(isPinching ? "正在绘画" : "等待捏合手势")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.trailing, 20)
        .padding(.top, 60)
    }
    
    // MARK: - 手部追踪处理
    private func handleHandTracking() {
        var detectedPinch = false
        var pinchPosition: SIMD3<Float>?
        var pinchingHand: String = ""
        
        // 检查左手
        if let leftHand = handTracking.latestLeftHand,
           let handSkeleton = leftHand.handSkeleton {
            
            // 检查捏合手势
            let (isPinch2, position2) = checkPinchGesture(for: leftHand, skeleton: handSkeleton)
            let (isPinch3, position3) = checkThreeFingerPinch(for: leftHand, skeleton: handSkeleton)
            
            if isPinch2 || isPinch3 {
                detectedPinch = true
                pinchPosition = isPinch3 ? position3 : position2
                pinchingHand = isPinch3 ? "左手(3指)" : "左手(2指)"
            }
        }
        
        // 检查右手（优先级高于左手）
        if let rightHand = handTracking.latestRightHand,
           let handSkeleton = rightHand.handSkeleton {
            
            // 检查捏合手势
            let (isPinch2, position2) = checkPinchGesture(for: rightHand, skeleton: handSkeleton)
            let (isPinch3, position3) = checkThreeFingerPinch(for: rightHand, skeleton: handSkeleton)
            
            if isPinch2 || isPinch3 {
                detectedPinch = true
                pinchPosition = isPinch3 ? position3 : position2
                
                let rightHandType = isPinch3 ? "右手(3指)" : "右手(2指)"
                let hasLeftHand = pinchingHand.contains("左手")
                
                if detectedPinch && hasLeftHand {
                    pinchingHand = "双手"
                } else {
                    pinchingHand = rightHandType
                }
            }
        }
        
        // 处理捏合状态变化
        let wasPinching = isPinching
        isPinching = detectedPinch
        lastPinchPosition = pinchPosition
        
        // 捏合状态变化处理
        if isPinching && !wasPinching {
            // 刚开始捏合 - 开始绘画
            print("✋ \(pinchingHand)开始捏合")
            startDrawing()
        } else if !isPinching && wasPinching {
            // 结束捏合 - 停止绘画
            print("✋ 结束捏合")
            stopDrawing()
        } else if isPinching && wasPinching && isCurrentlyDrawing {
            // 持续捏合 - 继续绘画
            continueDrawing()
        }
    }
    
    // MARK: - 三指捏合检测
    private func checkThreeFingerPinch(for anchor: HandAnchor, skeleton: HandSkeleton) -> (Bool, SIMD3<Float>?) {
        // 获取拇指、食指、中指尖的变换矩阵
        let thumbTransform = anchor.originFromAnchorTransform * skeleton.joint(.thumbTip).anchorFromJointTransform
        let indexTransform = anchor.originFromAnchorTransform * skeleton.joint(.indexFingerTip).anchorFromJointTransform
        let middleTransform = anchor.originFromAnchorTransform * skeleton.joint(.middleFingerTip).anchorFromJointTransform
        
        // 提取位置
        let thumbPos = SIMD3<Float>(thumbTransform.columns.3.x,
                                     thumbTransform.columns.3.y,
                                     thumbTransform.columns.3.z)
        let indexPos = SIMD3<Float>(indexTransform.columns.3.x,
                                     indexTransform.columns.3.y,
                                     indexTransform.columns.3.z)
        let middlePos = SIMD3<Float>(middleTransform.columns.3.x,
                                      middleTransform.columns.3.y,
                                      middleTransform.columns.3.z)
        
        // 计算三指之间的距离
        let thumbIndexDistance = length(thumbPos - indexPos)
        let thumbMiddleDistance = length(thumbPos - middlePos)
        let indexMiddleDistance = length(indexPos - middlePos)
        
        // 三指捏合的阈值
        let pinchThreshold: Float = 0.015  // 1.5厘米
        
        // 三个距离都小于阈值才算三指捏合
        let allDistancesSmall = thumbIndexDistance < pinchThreshold &&
                               thumbMiddleDistance < pinchThreshold &&
                               indexMiddleDistance < pinchThreshold
        
        if allDistancesSmall {
            // 使用三指的中心点作为绘画位置
            let centerPoint = (thumbPos + indexPos + middlePos) / 3
            return (true, centerPoint)
        }
        
        return (false, nil)
    }
    
    // 开始绘画
    private func startDrawing() {
        guard let position = lastPinchPosition else {
            print("⚠️ 无法获取捏合位置")
            return
        }
        
        isCurrentlyDrawing = true
        let brushConfig = createBrushConfig()
        canvas.addPoint(position, brushConfig: brushConfig)
        print("🎨 开始绘画，位置: x=\(position.x), y=\(position.y), z=\(position.z)")
    }
    
    // 继续绘画
    private func continueDrawing() {
        guard let position = lastPinchPosition else { return }
        
        // 只有移动一定距离才添加新点，避免点过于密集
        if let lastPoint = canvas.currentStroke?.points.last {
            let moveDistance = length(position - lastPoint)
            if moveDistance < 0.001 { // 小于1毫米不添加新点
                return
            }
        }
        
        let brushConfig = createBrushConfig()
        canvas.addPoint(position, brushConfig: brushConfig)
    }
    
    // 停止绘画
    private func stopDrawing() {
        if isCurrentlyDrawing {
            canvas.finishStroke()
            isCurrentlyDrawing = false
            print("🎨 结束绘画，当前笔画总数: \(canvas.getStrokeCount)")
        }
    }
    
    // 两指捏合检测
    private func checkPinchGesture(for anchor: HandAnchor, skeleton: HandSkeleton) -> (Bool, SIMD3<Float>?) {
        // 获取拇指尖和食指尖的变换矩阵
        let thumbTransform = anchor.originFromAnchorTransform * skeleton.joint(.thumbTip).anchorFromJointTransform
        let indexTransform = anchor.originFromAnchorTransform * skeleton.joint(.indexFingerTip).anchorFromJointTransform
        
        // 从变换矩阵提取位置（使用第4列）
        let thumbPos = SIMD3<Float>(thumbTransform.columns.3.x,
                                     thumbTransform.columns.3.y,
                                     thumbTransform.columns.3.z)
        let indexPos = SIMD3<Float>(indexTransform.columns.3.x,
                                     indexTransform.columns.3.y,
                                     indexTransform.columns.3.z)
        
        // 计算距离
        let distance = length(thumbPos - indexPos)
        let pinchThreshold: Float = 0.015  // 1.5厘米
        
        let isPinchDetected = distance < pinchThreshold
        if isPinchDetected {
            // 使用两指中点作为绘画位置，更稳定
            let midPoint = (thumbPos + indexPos) / 2
            return (true, midPoint)
        }
        
        return (false, nil)
    }

    // MARK: - 画笔配置
    private func createBrushConfig() -> BrushConfig {
        var config = BrushConfig()
        config.size = brushManager.brushSize * 0.001  // 转换为米
        config.color = UIColor(brushManager.brushColor)
        return config
    }
    
    // MARK: - 撤回功能
    private func undoLastStroke() {
//d
    }
    
    // MARK: - 清空画布功能
    private func clearCanvas() {
        canvas.clearAllStrokes()
        isPinching = false
        isCurrentlyDrawing = false
        lastPinchPosition = nil
        print("🎨 画布已清空")
    }
    
    // MARK: - Skybox 创建
    private func createSkybox(imageName: String) async -> Entity {
        let texture = try? await TextureResource(named: imageName)

        var material = UnlitMaterial()
        if let texture {
            material.color = .init(texture: .init(texture))
        } else {
            material.color = .init(tint: .blue) // 默认背景
        }

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 50),
            materials: [material]
        )
        sphere.scale = SIMD3<Float>(-1, 1, 1)
        return sphere
    }
}

class BrushManager: ObservableObject {
    @Published var brushColor: Color = .blue
    @Published var brushSize: Float = 2.0
    @Published var opacity: Float = 1.0
    @Published var isPaintingEnabled: Bool = false  // 绘画开关状态
    
    static let shared = BrushManager()
    private init() {}
    
    // 预设颜色
    let presetColors: [Color] = [
        .red, .blue, .green, .yellow,
        .orange, .purple, .pink, .cyan,
        .black, .white, .gray, .brown
    ]
    
    func reset() {
        brushColor = .blue
        brushSize = 2.0
        opacity = 1.0
        isPaintingEnabled = false  // 重置时也关闭绘画
    }
}

struct BrushControlWindow: View {
    @StateObject private var brushManager = BrushManager.shared
    @Environment(\.dismissWindow) private var dismissWindow
    
    // 云端功能状态
    @State private var isUploadingToCloud = false
    @State private var isDownloadingFromCloud = false
    @State private var cloudOperationStatus = ""
    @State private var hasCloudPainting = false
    @State private var showLocationInput = false
    
    // 【修复】类型改为 String，方便用户输入
    @State private var inputLocationId: String = "1"
    @State private var inputQuestionId: String = "1"
    @State private var inputAnswerId: String = "1"
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                Label("画笔控制", systemImage: "paintbrush.pointed")
                    .font(.headline)
                Spacer()
                Button(action: {
                    dismissWindow(id: "BrushControlWindow")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)
            
            // 绘画开关
            Toggle(isOn: $brushManager.isPaintingEnabled) {
                Label("启用空间绘画", systemImage: brushManager.isPaintingEnabled ? "paintbrush.fill" : "paintbrush")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            
            // 颜色选择区域
            VStack(alignment: .leading, spacing: 12) {
                Text("画笔颜色")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(brushManager.presetColors, id: \.self) { color in
                        ColorButton(
                            color: color,
                            isSelected: brushManager.brushColor == color,
                            action: {
                                brushManager.brushColor = color
                            }
                        )
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            
            // 画笔大小控制
            VStack(alignment: .leading, spacing: 8) {
                Text("画笔大小: \(String(format: "%.1f", brushManager.brushSize))mm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Slider(value: $brushManager.brushSize, in: 0.5...10.0, step: 0.1)
                    .tint(brushManager.brushColor)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            
            // 云端存储功能区域
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Label("云端存储", systemImage: "icloud")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if hasCloudPainting {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                // 【修复】位置/问题/答案ID输入 - 使用TextField
                VStack(spacing: 8) {
                    HStack {
                        Text("位置ID:")
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                        TextField("位置ID", text: $inputLocationId)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Text("问题ID:")
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                        TextField("问题ID", text: $inputQuestionId)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Text("答案ID:")
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                        TextField("答案ID", text: $inputAnswerId)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .keyboardType(.numberPad)
                    }
                }
                .padding(.horizontal, 8)
                
                // 云端操作按钮
                HStack(spacing: 12) {
                    // 保存到云端按钮
                    Button(action: {
                        savePaintingToCloud()
                    }) {
                        HStack {
                            if isUploadingToCloud {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                            }
                            Text("保存到云端")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUploadingToCloud || isDownloadingFromCloud || !brushManager.isPaintingEnabled)
                    
                    // 从云端加载按钮
                    Button(action: {
                        loadPaintingFromCloud()
                    }) {
                        HStack {
                            if isDownloadingFromCloud {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "icloud.and.arrow.down")
                            }
                            Text("从云端加载")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUploadingToCloud || isDownloadingFromCloud || !brushManager.isPaintingEnabled)
                }
                
                // 操作状态显示
                if !cloudOperationStatus.isEmpty {
                    Text(cloudOperationStatus)
                        .font(.caption2)
                        .foregroundColor(cloudOperationStatus.contains("成功") ? .green :
                                       cloudOperationStatus.contains("失败") ? .red : .blue)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            
            Spacer()
            
            // 底部按钮区域
            HStack(spacing: 15) {
                Button(action: {
                    undoLastStroke()
                }) {
                    Label("撤回", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    brushManager.reset()
                }) {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    clearCanvas()
                }) {
                    Label("清空画布", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(25)
        .frame(width: 400)
        .background(.regularMaterial)
        .onAppear {
            checkCloudPaintingExists()
            setupCloudOperationResultListener() // 【新增】监听操作结果
        }
    }
    
    // MARK: - 云端功能实现
    
    /// 检查云端画作是否存在
    private func checkCloudPaintingExists() {
        Task {
            // 【修复】转换为 Int64
            let locationId = Int64(inputLocationId) ?? 1
            let questionId = Int64(inputQuestionId) ?? 1
            let answerId = Int64(inputAnswerId) ?? 1
            
            print("检查云端画作存在性: locationId=\(locationId), questionId=\(questionId), answerId=\(answerId)")
            
            // 通过通知中心请求检查
            let userInfo: [String: Any] = [
                "action": "checkCloudPainting",
                "locationId": locationId,
                "questionId": questionId,
                "answerId": answerId
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudPaintingOperation"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    /// 保存画作到云端
    private func savePaintingToCloud() {
        isUploadingToCloud = true
        cloudOperationStatus = "正在保存到云端..."
        
        print("开始保存画作到云端")
        
        Task {
            // 【修复】转换为 Int64
            let locationId = Int64(inputLocationId) ?? 1
            let questionId = Int64(inputQuestionId) ?? 1
            let answerId = Int64(inputAnswerId) ?? 1
            
            print("保存参数: locationId=\(locationId), questionId=\(questionId), answerId=\(answerId)")
            
            // 通过通知中心发送保存请求
            let userInfo: [String: Any] = [
                "action": "savePaintingToCloud",
                "locationId": locationId,
                "questionId": questionId,
                "answerId": answerId
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudPaintingOperation"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    /// 从云端加载画作
    private func loadPaintingFromCloud() {
        isDownloadingFromCloud = true
        cloudOperationStatus = "正在从云端加载..."
        
        print("开始从云端加载画作")
        
        Task {
            // 【修复】转换为 Int64
            let locationId = Int64(inputLocationId) ?? 1
            let questionId = Int64(inputQuestionId) ?? 1
            let answerId = Int64(inputAnswerId) ?? 1
            
            print("加载参数: locationId=\(locationId), questionId=\(questionId), answerId=\(answerId)")
            
            // 通过通知中心发送加载请求
            let userInfo: [String: Any] = [
                "action": "loadPaintingFromCloud",
                "locationId": locationId,
                "questionId": questionId,
                "answerId": answerId
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudPaintingOperation"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    /// 【新增】监听云端操作结果
    private func setupCloudOperationResultListener() {
        // 监听操作结果通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudOperationResult"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let success = userInfo["success"] as? Bool,
               let message = userInfo["message"] as? String {
                
                // 更新UI状态
                isUploadingToCloud = false
                isDownloadingFromCloud = false
                cloudOperationStatus = message
                
                print("云端操作结果: \(success ? "成功" : "失败") - \(message)")
                
                // 3秒后清除状态信息
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    cloudOperationStatus = ""
                }
            }
        }
        
        // 监听检查结果通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudPaintingExistsResult"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let exists = userInfo["exists"] as? Bool {
                hasCloudPainting = exists
                print("云端画作存在性: \(exists)")
            }
        }
    }
    
    // 其他方法保持不变...
    private func undoLastStroke() {
        NotificationCenter.default.post(name: NSNotification.Name("UndoLastStroke"), object: nil)
        print("发送撤回指令")
    }
    
    private func clearCanvas() {
        NotificationCenter.default.post(name: NSNotification.Name("ClearCanvas"), object: nil)
        print("发送清空画布指令")
    }
}

// 在 PaintingDebug.swift 中添加/修复云端操作监听

extension PaintingDebug {
    
    /// 设置云端操作监听器
    private func setupCloudOperationListener() {
        print("设置云端操作监听器")
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudPaintingOperation"),
            object: nil,
            queue: .main
        ) { notification in
            print("收到云端操作通知")
            self.handleCloudOperation(notification.userInfo)
        }
    }
    
    /// 处理云端操作
    private func handleCloudOperation(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
              let action = userInfo["action"] as? String else {
            print("无效的云端操作通知")
            return
        }
        
        print("处理云端操作: \(action)")
        
        let locationId = userInfo["locationId"] as? Int64
        let questionId = userInfo["questionId"] as? Int64
        let answerId = userInfo["answerId"] as? Int64
        
        print("操作参数: locationId=\(locationId ?? 0), questionId=\(questionId ?? 0), answerId=\(answerId ?? 0)")
        
        Task {
            switch action {
            case "savePaintingToCloud":
                await savePaintingToCloud(locationId: locationId, questionId: questionId, answerId: answerId)
            case "loadPaintingFromCloud":
                await loadPaintingFromCloud(locationId: locationId, questionId: questionId, answerId: answerId)
            case "checkCloudPainting":
                await checkCloudPaintingExists(locationId: locationId, questionId: questionId, answerId: answerId)
            default:
                print("未知的云端操作: \(action)")
                break
            }
        }
    }
    
    /// 保存画作到云端
    private func savePaintingToCloud(locationId: Int64?, questionId: Int64?, answerId: Int64?) async {
        print("开始执行云端保存操作")
        
        do {
            try await canvas.savePaintingToCloud(locationId: locationId, questionId: questionId, userId: answerId)
            print("画作保存到云端成功")
            
            // 发送成功通知
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": true, "message": "画作保存成功"]
                )
            }
        } catch {
            print("画作保存到云端失败: \(error.localizedDescription)")
            
            // 发送失败通知
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": false, "message": "保存失败: \(error.localizedDescription)"]
                )
            }
        }
    }
    
    /// 从云端加载画作
    private func loadPaintingFromCloud(locationId: Int64?, questionId: Int64?, answerId: Int64?) async {
        print("开始执行云端加载操作")
        
        do {
            try await canvas.loadPaintingFromCloud(locationId: locationId, questionId: questionId, userId: answerId)
            print("从云端加载画作成功")
            
            // 发送成功通知
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": true, "message": "画作加载成功"]
                )
            }
        } catch {
            print("从云端加载画作失败: \(error.localizedDescription)")
            
            // 发送失败通知
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudOperationResult"),
                    object: nil,
                    userInfo: ["success": false, "message": "加载失败: \(error.localizedDescription)"]
                )
            }
        }
    }
    
    /// 检查云端画作是否存在
    private func checkCloudPaintingExists(locationId: Int64?, questionId: Int64?, answerId: Int64?) async {
        print("检查云端画作存在性")
        
        let exists = await canvas.checkCloudPaintingExists(locationId: locationId, questionId: questionId, userId: answerId)
        
        print("云端画作存在性检查结果: \(exists)")
        
        // 发送检查结果通知
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudPaintingExistsResult"),
                object: nil,
                userInfo: ["exists": exists]
            )
        }
    }
}
// 颜色按钮组件
//struct ColorButton: View {
//    let color: Color
//    let isSelected: Bool
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            RoundedRectangle(cornerRadius: 8)
//                .fill(color)
//                .frame(width: 40, height: 40)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 8)
//                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
//                )
//                .overlay(
//                    Image(systemName: "checkmark")
//                        .foregroundColor(.white)
//                        .font(.caption)
//                        .opacity(isSelected ? 1 : 0)
//                )
//                .shadow(radius: isSelected ? 3 : 1)
//        }
//        .buttonStyle(.plain)
//    }
//}

// MARK: - 预览
#Preview(immersionStyle: .full) {
    PaintingDebug()
}

