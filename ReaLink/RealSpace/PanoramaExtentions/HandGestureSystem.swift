//
//  HandGestureSystem.swift
//  ReaLink
//
//  手势检测和追踪系统
//

import RealityKit
import SwiftUI
import ARKit

// MARK: - 手势管理器协议
protocol HandGestureManagerDelegate: AnyObject {
    func didDetectOpenHandGesture(chirality: OpenHandGestureDetector.OpenHandDetectionResult.HandChirality)
    func didUpdateLeftHandOpen(isOpen: Bool, confidence: Float)
    func didUpdateRightHandOpen(isOpen: Bool, confidence: Float)
}

// MARK: - 手势管理器
class HandGestureManager: ObservableObject {
    @Published var isMenuTriggerGestureDetected = false
    @Published var leftHandOpenDetected = false
    @Published var rightHandOpenDetected = false
    @Published var leftHandConfidence: Float = 0.0
    @Published var rightHandConfidence: Float = 0.0
    
    private var handTracker: HandTracker?
    private let openHandDetector = OpenHandGestureDetector()
    
    init() {
        setupHandTracking()
    }
    
    private func setupHandTracking() {
        handTracker = HandTracker(openHandDetector: openHandDetector)
        handTracker?.delegate = self
    }
    
    func startTracking() {
        handTracker?.startTracking()
    }
    
    func stopTracking() {
        handTracker?.stopTracking()
    }
    
    func resetOpenHandDetection() {
        openHandDetector.resetDetectionState()
        leftHandOpenDetected = false
        rightHandOpenDetected = false
        leftHandConfidence = 0.0
        rightHandConfidence = 0.0
    }
    
    // 🌟 新增：获取 ARKitSession 用于设备位置追踪
    #if !targetEnvironment(simulator)
    func getARKitSession() -> ARKitSession? {
        return handTracker?.getARKitSession()
    }
    #endif
}

// MARK: - 手势管理器代理实现
extension HandGestureManager: HandGestureManagerDelegate {
    func didDetectOpenHandGesture(chirality: OpenHandGestureDetector.OpenHandDetectionResult.HandChirality) {
        Task { @MainActor in
            if !self.isMenuTriggerGestureDetected {
                self.isMenuTriggerGestureDetected = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isMenuTriggerGestureDetected = false
                }
            }
        }
    }
    
    func didUpdateLeftHandOpen(isOpen: Bool, confidence: Float) {
        Task { @MainActor in
            self.leftHandOpenDetected = isOpen
            self.leftHandConfidence = confidence
        }
    }
    
    func didUpdateRightHandOpen(isOpen: Bool, confidence: Float) {
        Task { @MainActor in
            self.rightHandOpenDetected = isOpen
            self.rightHandConfidence = confidence
        }
    }
}

// MARK: - 手部追踪器
class HandTracker: NSObject, ObservableObject {
    weak var delegate: HandGestureManagerDelegate?
    private var isTracking = false
    private let openHandDetector: OpenHandGestureDetector
    
    init(openHandDetector: OpenHandGestureDetector) {
        self.openHandDetector = openHandDetector
        super.init()
    }
    
    #if !targetEnvironment(simulator)
    private var arSession = ARKitSession()
    private var handTrackingProvider: HandTrackingProvider?
    
    // 🌟 新增：提供 ARKitSession 访问接口
    func getARKitSession() -> ARKitSession {
        return arSession
    }
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        
        Task {
            await setupHandTracking()
        }
        
        print("开始摊开手势追踪")
    }
    
    func stopTracking() {
        isTracking = false
        Task {
            await arSession.stop()
        }
        handTrackingProvider = nil
        print("停止摊开手势追踪")
    }
    
    @MainActor
    private func setupHandTracking() async {
        do {
            let authorized = await HandTrackingProvider.requestUserAuthorization() == .allowed
            guard authorized else {
                print("手势追踪权限被拒绝")
                return
            }
            
            handTrackingProvider = HandTrackingProvider()
            try await arSession.run([handTrackingProvider!])
            
            for await update in handTrackingProvider!.anchorUpdates {
                processHandUpdate(update)
            }
        } catch {
            print("手势追踪初始化失败: \(error)")
        }
    }
    
    private func processHandUpdate(_ update: AnchorUpdate<HandAnchor>) {
        switch update.event {
        case .added, .updated:
            let handAnchor = update.anchor
            
            switch handAnchor.chirality {
            case .left:
                let result = openHandDetector.detectLeftHandOpen(handAnchor)
                handleOpenHandDetection(result: result)
                
            case .right:
                let result = openHandDetector.detectRightHandOpen(handAnchor)
                handleOpenHandDetection(result: result)
            }
            
        case .removed:
            print("手部追踪丢失")
        }
    }
    
    private func handleOpenHandDetection(result: OpenHandGestureDetector.OpenHandDetectionResult) {
        DispatchQueue.main.async {
            switch result.chirality {
            case .left:
                self.delegate?.didUpdateLeftHandOpen(isOpen: result.isOpenHand, confidence: result.confidence)
                
            case .right:
                self.delegate?.didUpdateRightHandOpen(isOpen: result.isOpenHand, confidence: result.confidence)
            }
            
            if result.isOpenHand && result.confidence > 0.6 {
                print("检测到摊开手势! (\(result.chirality == .left ? "左手" : "右手"), 置信度: \(String(format: "%.2f", result.confidence)))")
                self.delegate?.didDetectOpenHandGesture(chirality: result.chirality)
            }
        }
    }
    
    #else
    // 模拟器版本
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        print("[模拟器] 开始摊开手势追踪")
        print("[模拟器] 使用键盘快捷键：")
        print("    • L 键：模拟左手摊开")
        print("    • R 键：模拟右手摊开")
        print("    • F 键：模拟双手摊开")
        
        setupKeyboardListener()
    }
    
    func stopTracking() {
        isTracking = false
        removeKeyboardListener()
        print("[模拟器] 停止摊开手势追踪")
    }
    
    private func setupKeyboardListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SimulatorLeftFistKey"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.simulateLeftOpenGesture()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SimulatorRightFistKey"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.simulateRightOpenGesture()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SimulatorBothFistsKey"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.simulateBothOpenGesture()
        }
    }
    
    private func removeKeyboardListener() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SimulatorLeftFistKey"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SimulatorRightFistKey"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SimulatorBothFistsKey"), object: nil)
    }
    
    private func simulateLeftOpenGesture() {
        print("[模拟器] 模拟左手摊开手势!")
        delegate?.didUpdateLeftHandOpen(isOpen: true, confidence: 0.95)
        delegate?.didDetectOpenHandGesture(chirality: .left)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.delegate?.didUpdateLeftHandOpen(isOpen: false, confidence: 0.0)
        }
    }
    
    private func simulateRightOpenGesture() {
        print("[模拟器] 模拟右手摊开手势!")
        delegate?.didUpdateRightHandOpen(isOpen: true, confidence: 0.95)
        delegate?.didDetectOpenHandGesture(chirality: .right)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.delegate?.didUpdateRightHandOpen(isOpen: false, confidence: 0.0)
        }
    }
    
    private func simulateBothOpenGesture() {
        print("[模拟器] 模拟双手摊开手势!")
        delegate?.didUpdateLeftHandOpen(isOpen: true, confidence: 0.98)
        delegate?.didUpdateRightHandOpen(isOpen: true, confidence: 0.98)
        delegate?.didDetectOpenHandGesture(chirality: .left)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.delegate?.didUpdateLeftHandOpen(isOpen: false, confidence: 0.0)
            self.delegate?.didUpdateRightHandOpen(isOpen: false, confidence: 0.0)
        }
    }
    #endif
}

#if !targetEnvironment(simulator)
import ARKit

@available(visionOS 1.0, *)
extension HandTrackingProvider {
    enum AuthorizationStatus {
        case notDetermined
        case denied
        case allowed
    }
    
    static func requestUserAuthorization() async -> AuthorizationStatus {
        return .allowed
    }
}
#endif

// MARK: - 模拟器手势辅助器
#if targetEnvironment(simulator)
struct SimulatorGestureHelper: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = GestureDetectorView()
        
        DispatchQueue.main.async {
            view.becomeFirstResponder()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }
}

class GestureDetectorView: UIView {
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        becomeFirstResponder()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            becomeFirstResponder()
            print("[模拟器] 手势检测器已获得父视图")
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
            print("[模拟器] 手势检测器已获得窗口焦点")
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        becomeFirstResponder()
        print("[模拟器] 检测到触摸事件")
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        print("[模拟器] pressesBegan 被调用，按键数量：\(presses.count)")
        
        var handled = false
        
        for press in presses {
            guard let key = press.key else {
                print("[模拟器] 无法获取按键信息")
                continue
            }
            
            let keyChar = key.charactersIgnoringModifiers.lowercased()
            print("[模拟器] 检测到按键：'\(keyChar)'")
            
            switch keyChar {
            case "l":
                print("[模拟器] L键被按下，发送左手拳头通知")
                NotificationCenter.default.post(name: NSNotification.Name("SimulatorLeftFistKey"), object: nil)
                handled = true
                
            case "r":
                print("[模拟器] R键被按下，发送右手拳头通知")
                NotificationCenter.default.post(name: NSNotification.Name("SimulatorRightFistKey"), object: nil)
                handled = true
                
            case "f":
                print("[模拟器] F键被按下，发送双手拳头通知")
                NotificationCenter.default.post(name: NSNotification.Name("SimulatorBothFistsKey"), object: nil)
                handled = true
                
            case " ":
                print("[模拟器] 空格键被按下，退出沉浸式空间")
                NotificationCenter.default.post(name: NSNotification.Name("ExitImmersiveSpace"), object: nil)
                handled = true
                
            default:
                print("[模拟器] 未处理的按键：'\(keyChar)'")
            }
        }
        
        if !handled {
            super.pressesBegan(presses, with: event)
        } else {
            print("[模拟器] 按键事件已处理")
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        print("[模拟器] pressesEnded 被调用")
        super.pressesEnded(presses, with: event)
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: "l", modifierFlags: [], action: #selector(leftFistCommand)),
            UIKeyCommand(input: "r", modifierFlags: [], action: #selector(rightFistCommand)),
            UIKeyCommand(input: "f", modifierFlags: [], action: #selector(bothFistsCommand)),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(exitSpaceCommand))
        ]
    }
    
    @objc private func leftFistCommand() {
        print("[模拟器] 键盘命令：左手拳头")
        NotificationCenter.default.post(name: NSNotification.Name("SimulatorLeftFistKey"), object: nil)
    }
    
    @objc private func rightFistCommand() {
        print("[模拟器] 键盘命令：右手拳头")
        NotificationCenter.default.post(name: NSNotification.Name("SimulatorRightFistKey"), object: nil)
    }
    
    @objc private func bothFistsCommand() {
        print("[模拟器] 键盘命令：双手拳头")
        NotificationCenter.default.post(name: NSNotification.Name("SimulatorBothFistsKey"), object: nil)
    }
    
    @objc private func exitSpaceCommand() {
        print("[模拟器] 键盘命令：退出空间")
        NotificationCenter.default.post(name: NSNotification.Name("ExitImmersiveSpace"), object: nil)
    }
}
#endif
