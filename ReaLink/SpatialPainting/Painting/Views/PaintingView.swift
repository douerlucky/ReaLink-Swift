/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that starts a new painting session and starts hand tracking with drag gestures.
*/

// 导入必要的框架
import SwiftUI      // Apple的声明式UI框架
import RealityKit   // 用于3D渲染和AR体验
import ARKit        // Apple的增强现实框架，提供手部追踪功能
import Foundation   // 用于Timer等基础功能

/// 这是一个包含手部追踪和现实视图的SwiftUI视图
/// 当用户使用拖拽手势时，会创建笔触网格
struct PaintingView: View {
    
    // MARK: - 属性定义
    
    /// 手部追踪的实例，负责检测和追踪用户的手部动作
    var paintingHandTracking = PaintingHandTracking()

    /// 绘画画布的实例，使用@State装饰器让SwiftUI管理其状态
    /// @State意味着当这个值改变时，视图会重新渲染
    @State var canvas = PaintingCanvas()

    /// 存储上次捏合手势时食指的3D位置
    /// SIMD3<Float>表示一个包含x,y,z坐标的3D向量
    /// 可选类型(?）表示可能为nil
    @State var lastIndexPose: SIMD3<Float>?
    
    /// 获取绘画配置对象
    @EnvironmentObject var paintingConfig: PaintingConfig
    
    /// 记录当前哪只手正在捏合（用于传统绘画模式）
    @State var pinchingHand: HandAnchor.Chirality?
    
    /// 左手相关状态（仅用于捏合检测）
    @State var leftHandIndexPose: SIMD3<Float>?
    
    /// 右手相关状态
    @State var rightHandIndexPose: SIMD3<Float>?
    @State var previousRightHandIndexPose: SIMD3<Float>?
    @State var isRightHandAutoDrawing: Bool = false
    @State var rightHandAutoDrawingTimer: Timer?

    // MARK: - 视图主体
    
    var body: some View {
        ZStack {
            // RealityView是RealityKit提供的视图，用于显示3D内容
            RealityView { content in
            
            // 从画布获取根实体（3D场景的根节点）
            let root = canvas.root

            // 将画布添加到现实视图中显示
            content.add(root)

            // 给根实体添加一个闭包组件，用于处理实时更新
            // ClosureComponent允许我们在每一帧都执行自定义代码
            root.components.set(ClosureComponent(closure: { deltaTime in
                
                // deltaTime是自上一帧以来经过的时间
                
                // 创建一个数组来存储检测到的手部锚点
                var anchors = [HandAnchor]()

                // 如果检测到左手，将其添加到锚点集合
                if let latestLeftHand = paintingHandTracking.latestLeftHand {
                    anchors.append(latestLeftHand)
                }

                // 如果检测到右手，将其添加到锚点集合
                if let latestRightHand = paintingHandTracking.latestRightHand {
                    anchors.append(latestRightHand)
                }

                // 遍历所有检测到的手部锚点
                for anchor in anchors {
                    
                    // 尝试获取手部骨骼数据，如果失败则跳过这只手
                    guard let handSkeleton = anchor.handSkeleton else {
                        continue // 跳到下一次循环
                    }

                    // 计算拇指尖的3D位置
                    // 通过矩阵变换将关节位置从手部坐标系转换到世界坐标系
                    let thumbPos = (anchor.originFromAnchorTransform * handSkeleton.joint(.thumbTip).anchorFromJointTransform).translation()

                    // 计算食指尖的3D位置
                    let indexPos = (anchor.originFromAnchorTransform * handSkeleton.joint(.indexFingerTip).anchorFromJointTransform).translation()

                    // 设置捏合手势的阈值（5厘米）
                    let pinchThreshold: Float = 0.05

                    // 根据手部类型（左手或右手）分别处理
                    switch anchor.chirality {
                    case .left:
                        handleLeftHand(thumbPos: thumbPos, indexPos: indexPos, pinchThreshold: pinchThreshold)
                    case .right:
                        handleRightHand(thumbPos: thumbPos, indexPos: indexPos, pinchThreshold: pinchThreshold)
                    }
                }
            }))
        }
        // 添加拖拽手势识别（只用于捏合绘画模式）
        .gesture(
            DragGesture(minimumDistance: 0) // 最小拖拽距离为0，即立即响应
                .targetedToAnyEntity()      // 手势可以作用于任何3D实体
                .onChanged({ _ in           // 当拖拽发生变化时执行
                    // 只在非自动绘画模式下处理拖拽手势
                    if !paintingConfig.isAutoPaintingEnabled {
                        // 捏合绘画模式：使用捏合时的食指位置
                        if let pos = lastIndexPose {
                            // 在画布上添加当前位置作为绘画点
                            canvas.addPoint(pos, brushConfig: paintingConfig.brushConfig)
                        }
                    }
                })
                .onEnded({ _ in             // 当拖拽手势结束时执行
                    // 只在非自动绘画模式下结束笔画
                    if !paintingConfig.isAutoPaintingEnabled {
                        // 结束当前笔触
                        canvas.finishStroke()
                    }
                })
        )
        // .task修饰符在视图出现时执行异步任务
        .task {
            // 开始手部追踪（这是一个异步操作）
            await paintingHandTracking.startTracking()
        }
        // 监听清除触发器
        .onChange(of: paintingConfig.clearTrigger) { _ in
            canvas.clearAllStrokes()
        }
        // 视图消失时清理资源
        .onDisappear {
            rightHandAutoDrawingTimer?.invalidate()
            rightHandAutoDrawingTimer = nil
        }
        
        // 显示绘画模式指示器
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack {
                    Text(paintingConfig.isAutoPaintingEnabled ? "自动绘画模式" : "捏合绘画模式")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if paintingConfig.isAutoPaintingEnabled {
                        VStack {
                            Text("右手自动绘画")
                                .font(.caption)
                            Text(isRightHandAutoDrawing ? "绘画中" : "待机")
                                .font(.caption2)
                                .foregroundColor(isRightHandAutoDrawing ? .yellow : .white.opacity(0.7))
                        }
                        
                        Text("移动右手食指开始绘画")
                            .font(.caption)
                            .opacity(0.8)
                    } else {
                        HStack {
                            Text("捏合拇指和食指后拖拽绘画")
                                .font(.caption)
                                .opacity(0.8)
                            
                            if let pinching = pinchingHand {
                                Text("(\(pinching == .left ? "左手" : "右手")捏合中)")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(paintingConfig.isAutoPaintingEnabled ? Color.green.opacity(0.8) : Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(20)
                .padding(.trailing, 30)
                .padding(.bottom, 50)
            }
        }
        } // ZStack结束
    }
    
    // MARK: - 辅助函数
    
    /// 处理左手的绘画逻辑（仅用于捏合检测）
    private func handleLeftHand(thumbPos: SIMD3<Float>, indexPos: SIMD3<Float>, pinchThreshold: Float) {
        // 更新左手食指位置
        leftHandIndexPose = indexPos
        
        // 检查是否捏合（用于传统绘画模式）
        let isLeftHandPinching = length(thumbPos - indexPos) < pinchThreshold
        
        if isLeftHandPinching {
            // 如果左手正在捏合，且没有其他手在捏合，则设置为当前捏合手
            if pinchingHand == nil || pinchingHand == .left {
                pinchingHand = .left
                lastIndexPose = indexPos
            }
        } else {
            // 如果左手不在捏合，且当前捏合手是左手，则清除
            if pinchingHand == .left {
                pinchingHand = nil
                lastIndexPose = nil
            }
        }
        
        // 左手不参与自动绘画，只在非自动模式下清理状态
        if !paintingConfig.isAutoPaintingEnabled {
            // 确保左手不会有残留的自动绘画状态
        }
    }
    
    /// 处理右手的绘画逻辑
    private func handleRightHand(thumbPos: SIMD3<Float>, indexPos: SIMD3<Float>, pinchThreshold: Float) {
        // 更新右手食指位置
        rightHandIndexPose = indexPos
        
        // 检查是否捏合（用于传统绘画模式）
        let isRightHandPinching = length(thumbPos - indexPos) < pinchThreshold
        
        if isRightHandPinching {
            // 如果右手正在捏合，且没有其他手在捏合，则设置为当前捏合手
            if pinchingHand == nil || pinchingHand == .right {
                pinchingHand = .right
                lastIndexPose = indexPos
            }
        } else {
            // 如果右手不在捏合，且当前捏合手是右手，则清除
            if pinchingHand == .right {
                pinchingHand = nil
                lastIndexPose = nil
            }
        }
        
        // 自动绘画模式逻辑（只有右手参与）
        if paintingConfig.isAutoPaintingEnabled {
            handleAutoDrawing(
                for: .right,
                currentPos: indexPos,
                previousPos: &previousRightHandIndexPose,
                isDrawing: &isRightHandAutoDrawing,
                timer: &rightHandAutoDrawingTimer
            )
        } else {
            // 非自动模式下重置状态
            cleanupAutoDrawing(
                for: .right,
                previousPos: &previousRightHandIndexPose,
                isDrawing: &isRightHandAutoDrawing,
                timer: &rightHandAutoDrawingTimer
            )
        }
    }
    
    /// 处理自动绘画逻辑
    private func handleAutoDrawing(
        for hand: HandAnchor.Chirality,
        currentPos: SIMD3<Float>,
        previousPos: inout SIMD3<Float>?,
        isDrawing: inout Bool,
        timer: inout Timer?
    ) {
        if let prevPos = previousPos {
            let moveDistance = length(currentPos - prevPos)
            
            // 如果移动距离超过阈值，开始或继续绘画
            if moveDistance > 0.005 { // 5毫米的移动阈值
                if !isDrawing {
                    // 开始新的笔画
                    isDrawing = true
                }
                // 添加点到画布
                canvas.addPoint(currentPos, brushConfig: paintingConfig.brushConfig)
                
                // 重置计时器
                timer?.invalidate()
                
                // 创建新的计时器，只处理右手
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    self.endRightHandDrawing()
                }
            }
        } else {
            // 第一次检测到食指位置，开始绘画
            if !isDrawing {
                isDrawing = true
            }
            canvas.addPoint(currentPos, brushConfig: paintingConfig.brushConfig)
        }
        
        // 更新上一帧位置
        previousPos = currentPos
    }
    
    /// 结束右手绘画
    private func endRightHandDrawing() {
        if isRightHandAutoDrawing {
            canvas.finishStroke()
            isRightHandAutoDrawing = false
        }
    }
    
    /// 清理自动绘画状态
    private func cleanupAutoDrawing(
        for hand: HandAnchor.Chirality,
        previousPos: inout SIMD3<Float>?,
        isDrawing: inout Bool,
        timer: inout Timer?
    ) {
        timer?.invalidate()
        timer = nil
        if isDrawing {
            canvas.finishStroke()
            isDrawing = false
        }
        previousPos = nil
    }
}