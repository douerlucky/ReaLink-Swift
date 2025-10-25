// 修复后的手部追踪类 - PaintingHandTracking.swift

import SwiftUI
import RealityKit
import ARKit

// 🔧 修复：改进的手部追踪类，解决内存泄漏问题
class PaintingHandTracking: ObservableObject {
    @Published var latestLeftHand: HandAnchor?
    @Published var latestRightHand: HandAnchor?
    @Published var isTracking: Bool = false
    
    private var arSession: ARKitSession?
    private var handTrackingProvider: HandTrackingProvider?
    private var trackingTask: Task<Void, Never>?
    
    init() {
        print("🖐️ 初始化手部追踪系统")
    }
    
    deinit {
        print("🖐️ 销毁手部追踪系统")
        // 🔧 修复：确保所有资源都被正确释放
        stopTrackingSync()
    }
    
    // 🔧 修复：添加同步停止方法，避免异步操作导致的循环引用
    private func stopTrackingSync() {
        isTracking = false
        
        // 立即取消任务，避免循环引用
        trackingTask?.cancel()
        trackingTask = nil
        
        // 清理ARKit资源
        arSession?.stop()
        arSession = nil
        handTrackingProvider = nil
        
        // 清理手部数据
        latestLeftHand = nil
        latestRightHand = nil
        
        print("🖐️ 同步停止手部追踪完成")
    }
    
    @MainActor
    func startTracking() async {
        guard !isTracking else {
            print("🖐️ 手部追踪已经在运行")
            return
        }
        
        print("🖐️ 开始启动手部追踪...")
        
        #if targetEnvironment(simulator)
        // 模拟器环境下的模拟追踪
        await startSimulatorTracking()
        #else
        // 真实设备上的手部追踪
        await startRealDeviceTracking()
        #endif
    }
    
    func stopTracking() {
        print("🖐️ 开始异步停止手部追踪")
        
        // 🔧 修复：立即设置标志位，避免新的追踪开始
        isTracking = false
        
        // 使用 Task 来处理异步清理，避免阻塞主线程
        Task { [weak self] in
            guard let self = self else { return }
            
            // 取消追踪任务
            self.trackingTask?.cancel()
            self.trackingTask = nil
            
            // 异步停止ARKit会话
            await self.arSession?.stop()
            
            await MainActor.run {
                self.arSession = nil
                self.handTrackingProvider = nil
                self.latestLeftHand = nil
                self.latestRightHand = nil
                print("🖐️ 异步停止手部追踪完成")
            }
        }
    }
    
    #if targetEnvironment(simulator)
    // 🔧 模拟器环境：创建模拟手部追踪数据
    @MainActor
    private func startSimulatorTracking() async {
        isTracking = true
        print("🖐️ [模拟器] 手部追踪已启动")
        print("🖐️ [模拟器] 使用以下按键模拟手势：")
        print("    • P 键：模拟右手捏合手势")
        print("    • L 键：模拟左手捏合手势")
        print("    • S 键：停止所有手势")
        
        // 设置键盘监听
        setupSimulatorGestureListeners()
    }
    
    private func setupSimulatorGestureListeners() {
        // 🔧 修复：使用 weak self 避免循环引用
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SimulatorPinchGesture"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSimulatorPinchGesture(notification)
        }
    }
    
    private func handleSimulatorPinchGesture(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hand = userInfo["hand"] as? String,
              let isPinching = userInfo["isPinching"] as? Bool else {
            return
        }
        
        print("🖐️ [模拟器] \(hand)手\(isPinching ? "开始" : "结束")捏合")
    }
    
    #else
    // 🔧 真实设备：使用ARKit的手部追踪
    @MainActor
    private func startRealDeviceTracking() async {
        do {
            // 请求手部追踪权限
            let authorizationStatus = await HandTrackingProvider.requestUserAuthorization()
            guard authorizationStatus == .allowed else {
                print("🖐️ 手部追踪权限被拒绝")
                return
            }
            
            print("🖐️ 手部追踪权限获取成功")
            
            // 创建ARKit会话和手部追踪提供者
            arSession = ARKitSession()
            handTrackingProvider = HandTrackingProvider()
            
            guard let arSession = arSession,
                  let handTrackingProvider = handTrackingProvider else {
                print("🖐️ 创建ARKit组件失败")
                return
            }
            
            // 启动ARKit会话
            try await arSession.run([handTrackingProvider])
            isTracking = true
            
            print("🖐️ ARKit会话启动成功")
            
            // 🔧 修复：创建追踪任务时使用 weak self
            trackingTask = Task { [weak self] in
                await self?.processHandTrackingUpdates(handTrackingProvider)
            }
            
        } catch {
            print("🖐️ 启动手部追踪失败: \(error)")
            isTracking = false
        }
    }
    
    // 🔧 修复：添加取消检查，确保任务可以正确停止
    private func processHandTrackingUpdates(_ provider: HandTrackingProvider) async {
        print("🖐️ 开始处理手部追踪更新")
        
        do {
            for await update in provider.anchorUpdates {
                // 🔧 修复：检查任务是否被取消
                if Task.isCancelled {
                    print("🖐️ 手部追踪任务被取消")
                    break
                }
                
                await handleHandUpdate(update)
            }
        } catch {
            if !Task.isCancelled {
                print("🖐️ 处理手部追踪更新时出错: \(error)")
            }
        }
        
        print("🖐️ 手部追踪更新处理结束")
    }
    
    @MainActor
    private func handleHandUpdate(_ update: AnchorUpdate<HandAnchor>) async {
        // 🔥 修复：检查任务是否被取消
        guard !Task.isCancelled && isTracking else {
            return
        }
        
        switch update.event {
        case .added:
            print("🖐️ 检测到新的手部: \(update.anchor.chirality)")
            // 🔥 修复：使用异步调度修改状态
            DispatchQueue.main.async {
                self.updateHandAnchor(update.anchor)
            }
            
        case .updated:
            // 🔥 修复：使用异步调度修改状态
            DispatchQueue.main.async {
                self.updateHandAnchor(update.anchor)
            }
            
        case .removed:
            print("🖐️ 手部追踪丢失: \(update.anchor.chirality)")
            // 🔥 修复：使用异步调度修改状态
            DispatchQueue.main.async {
                self.removeHandAnchor(update.anchor.chirality)
            }
        }
    }
    
    @MainActor
    private func updateHandAnchor(_ handAnchor: HandAnchor) {
        switch handAnchor.chirality {
        case .left:
            latestLeftHand = handAnchor
        case .right:
            latestRightHand = handAnchor
        }
    }
    @MainActor
    private func removeHandAnchor(_ chirality: HandAnchor.Chirality) {
        switch chirality {
        case .left:
            latestLeftHand = nil
        case .right:
            latestRightHand = nil
        }
    }
    #endif
}

// 🔧 修复：改进的手势检测方法
extension PaintingHandTracking {
    
    // 两指捏合检测 - 在真实设备上使用
    func checkPinchGesture(for anchor: HandAnchor, skeleton: HandSkeleton) -> (Bool, SIMD3<Float>?) {
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
    
    // 三指捏合检测
    func checkThreeFingerPinch(for anchor: HandAnchor, skeleton: HandSkeleton) -> (Bool, SIMD3<Float>?) {
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
}

// 🔧 模拟器手势支持（简化版本，避免复杂的UI组件）
#if targetEnvironment(simulator)
struct SimulatorPaintingGestureHelper: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = PaintingGestureDetectorView()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class PaintingGestureDetectorView: UIView {
    override var canBecomeFirstResponder: Bool { return true }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        becomeFirstResponder()
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            
            let keyChar = key.charactersIgnoringModifiers.lowercased()
            
            switch keyChar {
            case "p":
                print("🖐️ [模拟器] 检测到 P 键，模拟右手捏合")
                NotificationCenter.default.post(
                    name: NSNotification.Name("SimulatorPinchGesture"),
                    object: nil,
                    userInfo: ["hand": "右", "isPinching": true]
                )
                
            case "l":
                print("🖐️ [模拟器] 检测到 L 键，模拟左手捏合")
                NotificationCenter.default.post(
                    name: NSNotification.Name("SimulatorPinchGesture"),
                    object: nil,
                    userInfo: ["hand": "左", "isPinching": true]
                )
                
            case "s":
                print("🖐️ [模拟器] 检测到 S 键，停止所有手势")
                NotificationCenter.default.post(
                    name: NSNotification.Name("SimulatorPinchGesture"),
                    object: nil,
                    userInfo: ["hand": "所有", "isPinching": false]
                )
                
            default:
                break
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

#endif
