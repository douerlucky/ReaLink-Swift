//
//  PaintingSystem.swift
//  ReaLink
//
//  空间绘画系统 - 优化版（平滑、远距离支持）
//

import RealityKit
import SwiftUI
import ARKit

extension BasicPanoramaView {
    
    // MARK: - 位置平滑缓冲区（使用静态变量避免重复初始化）
    private static var smoothedPosition: SIMD3<Float>?  // EMA平滑后的位置
    private static let smoothingFactor: Float = 0.3  // EMA平滑因子（0.1-0.5，越小越平滑）
    
    // MARK: - 上一次有效位置（用于插值）
    private static var lastValidPosition: SIMD3<Float>?
    private static var lastValidTime: Date?
    private static var lastValidVelocity: SIMD3<Float>?  // 记录速度用于预测
    
    // MARK: - 连续丢失计数
    private static var consecutiveLossCount: Int = 0
    private static let maxInterpolationFrames: Int = 10  // 最多插值10帧（约166ms @60fps）
    
    // MARK: - 绘画模式处理
    func handlePaintingModeChange(_ newValue: Bool) {
        print("🎨 绘画模式切换: \(newValue)")
        
        if newValue {
            // 🔥 清空EMA状态和记录
            Self.smoothedPosition = nil
            Self.lastValidPosition = nil
            Self.lastValidTime = nil
            Self.lastValidVelocity = nil
            Self.consecutiveLossCount = 0
            
            Task { @MainActor in
                await self.updatePaintingCanvasInScene()
                await self.handTracking.startTracking()
                
                if !hasTriedLoadingPainting {
                    await self.loadAllPaintingData()
                }
                
                print("🎨 绘画模式启用完成（已重置EMA平滑器）")
            }
        } else {
            stopDrawing()
            
            // 🔥 清空EMA状态和记录
            Self.smoothedPosition = nil
            Self.lastValidPosition = nil
            Self.lastValidTime = nil
            Self.lastValidVelocity = nil
            Self.consecutiveLossCount = 0
            
            Task { @MainActor in
                self.handTracking.stopTracking()
                await self.updatePaintingCanvasInScene()
            }
            
            print("🎨 绘画已禁用（已清空EMA平滑器）")
        }
    }
    
    // MARK: - 更新绘画画布
    @MainActor
    func updatePaintingCanvasInScene() async {
        guard isRootEntityInitialized else {
            print("⚠️ 根实体未初始化，延迟更新绘画画布")
            try? await Task.sleep(nanoseconds: 500_000_000)
            if isRootEntityInitialized {
                await updatePaintingCanvasInScene()
            }
            return
        }
        
        let canvasExists = rootEntity.children.contains { $0 === paintingCanvas.root }
        
        if brushManager.isPaintingEnabled && !canvasExists {
            rootEntity.addChild(paintingCanvas.root)
            print("✅ 绘画画布已添加到场景")
            
        } else if !brushManager.isPaintingEnabled && canvasExists {
            paintingCanvas.root.removeFromParent()
            print("🗑️ 绘画画布已从场景移除")
        }
        
        print("🎨 绘画画布状态更新: enabled=\(brushManager.isPaintingEnabled), exists=\(canvasExists)")
    }
    
    // MARK: - 位置平滑和动态阈值辅助函数
    
    /// 使用指数移动平均（EMA）平滑手部位置 - 比移动平均更好
    private func smoothPosition(_ rawPosition: SIMD3<Float>) -> SIMD3<Float> {
        guard let previousSmoothed = Self.smoothedPosition else {
            // 第一次，直接使用原始位置
            Self.smoothedPosition = rawPosition
            Self.lastValidPosition = rawPosition
            Self.lastValidTime = Date()
            Self.lastValidVelocity = SIMD3<Float>(0, 0, 0)
            Self.consecutiveLossCount = 0
            return rawPosition
        }
        
        // 🔥 EMA公式: smoothed = α × raw + (1-α) × previous_smoothed
        // α越小越平滑但延迟越大，α越大响应越快但越不平滑
        let alpha = Self.smoothingFactor
        let smoothed = alpha * rawPosition + (1 - alpha) * previousSmoothed
        
        // 计算速度（用于预测）
        if let lastTime = Self.lastValidTime, let lastPos = Self.lastValidPosition {
            let deltaTime = Float(Date().timeIntervalSince(lastTime))
            if deltaTime > 0.001 {  // 避免除零
                let velocity = (smoothed - lastPos) / deltaTime
                Self.lastValidVelocity = velocity
            }
        }
        
        // 更新状态
        Self.smoothedPosition = smoothed
        Self.lastValidPosition = smoothed
        Self.lastValidTime = Date()
        Self.consecutiveLossCount = 0
        
        return smoothed
    }
    
    /// 根据手部距离计算动态采样阈值
    private func getDynamicSamplingThreshold(handPosition: SIMD3<Float>) -> Float {
        let userHeadPosition = getUserCurrentPosition()
        let distance = length(handPosition - userHeadPosition)
        
        // 🔥 更激进的动态阈值：距离越远，阈值越大
        // 近距离 (0.3-0.5m): 0.15mm (超精细)
        // 中距离 (0.5-1.0m): 0.3mm  (推荐)
        // 远距离 (1.0-2.0m): 0.8mm  (流畅)
        // 超远距离 (>2.0m): 1.5mm  (防断线)
        let baseThreshold: Float = 0.00015  // 0.15mm
        let scaleFactor = max(1.0, pow(distance / 0.5, 1.5))  // 使用1.5次方加速增长
        let threshold = min(baseThreshold * scaleFactor, 0.0015)  // 最大1.5mm
        
        return threshold
    }
    
    /// 预测性插值 - 使用速度预测下一个位置
    private func interpolatePosition() -> SIMD3<Float>? {
        guard let lastPos = Self.lastValidPosition,
              let lastTime = Self.lastValidTime else {
            return nil
        }
        
        let timeSinceLastValid = Date().timeIntervalSince(lastTime)
        Self.consecutiveLossCount += 1
        
        // 🔥 改进1：增加最大插值时间到约166ms（10帧 @ 60fps）
        let maxInterpolationTime: TimeInterval = 0.166
        
        guard timeSinceLastValid < maxInterpolationTime,
              Self.consecutiveLossCount <= Self.maxInterpolationFrames else {
            print("⚠️ 丢失追踪时间过长，停止插值")
            return nil
        }
        
        // 🔥 改进2：使用速度进行预测性插值
        if let velocity = Self.lastValidVelocity {
            let predictedPosition = lastPos + velocity * Float(timeSinceLastValid)
            
            // 🔥 改进3：限制预测距离，避免预测过远
            let maxPredictionDistance: Float = 0.05  // 最多预测5cm
            let actualDistance = length(predictedPosition - lastPos)
            
            if actualDistance > maxPredictionDistance {
                // 预测距离过大，使用限制后的位置
                let direction = normalize(predictedPosition - lastPos)
                let limitedPosition = lastPos + direction * maxPredictionDistance
                print("🔧 使用限制预测位置: \(String(format: "%.3f", actualDistance))m")
                return limitedPosition
            }
            
            print("🔧 使用预测位置继续绘画（帧\(Self.consecutiveLossCount)）")
            return predictedPosition
        } else {
            // 没有速度信息，使用最后位置
            print("🔧 使用最后位置继续绘画（帧\(Self.consecutiveLossCount)）")
            return lastPos
        }
    }
    
    // MARK: - 手势追踪更新（同步版本 - 优化版）
    func performHandTrackingUpdateSync() {
        var detectedPinch = false
        var pinchPosition: SIMD3<Float>?
        var pinchingHand: String = ""
        
        // 🔥 只识别右手，完全忽略左手
        if let rightHand = handTracking.latestRightHand,
           let handSkeleton = rightHand.handSkeleton {
            
            let (isPinch2, position2) = checkPinchGesture(for: rightHand, skeleton: handSkeleton)
            let (isPinch3, position3) = checkThreeFingerPinch(for: rightHand, skeleton: handSkeleton)
            
            if isPinch2 || isPinch3 {
                detectedPinch = true
                // 🔥 使用EMA平滑后的位置
                let rawPosition = isPinch3 ? position3 : position2
                pinchPosition = rawPosition != nil ? smoothPosition(rawPosition!) : nil
                pinchingHand = isPinch3 ? "右手(3指)" : "右手(2指)"
            }
        } else if isPinching && isCurrentlyDrawing {
            // 🔥 已经在绘画中，且短暂丢失追踪，尝试预测性插值
            if let interpolated = interpolatePosition() {
                detectedPinch = true
                pinchPosition = interpolated
                pinchingHand = "预测插值"
                // 不打印过多日志，避免刷屏
            }
        }
        
        let wasPinching = isPinching
        let newPinchPosition = pinchPosition
        let newPinchingState = detectedPinch
        
        // 🔥 流畅的绘画触发逻辑
        if newPinchingState && !wasPinching {
            // 🔥 检测到新的捏合 - 记录开始时间和位置
            DispatchQueue.main.async {
                self.pinchStartTime = Date()
                self.pinchStartPosition = newPinchPosition
                self.isPinchStable = false
                self.hasMoved = false
                self.isPinching = true
                self.lastPinchPosition = newPinchPosition
            }
            
        } else if newPinchingState && wasPinching {
            // 🔥 持续捏合中 - 检查是否满足绘画条件
            DispatchQueue.main.async {
                self.lastPinchPosition = newPinchPosition
                
                guard let startTime = self.pinchStartTime,
                      let startPos = self.pinchStartPosition else {
                    return
                }
                
                // 计算捏合持续时间
                let duration = Date().timeIntervalSince(startTime)
                
                // 计算移动距离
                if let currentPos = newPinchPosition {
                    let moveDistance = length(currentPos - startPos)
                    
                    // 🔥 流畅：极低的延迟和移动要求
                    // 条件1：捏合持续超过0.03秒（极快响应）
                    let hasStableDuration = duration >= 0.03
                    
                    // 条件2：移动距离超过0.3厘米（极易触发）
                    let hasMovedEnough = moveDistance >= 0.003
                    
                    // 🔥 必须同时满足两个条件才开始绘画
                    if !self.isCurrentlyDrawing && hasStableDuration && hasMovedEnough {
                        self.startDrawing()
                        print("🎨 开始绘画 - 持续:\(String(format: "%.2f", duration))秒, 移动:\(String(format: "%.3f", moveDistance))米")
                    } else if self.isCurrentlyDrawing {
                        // 已经开始绘画，继续绘画
                        self.continueDrawing()
                    }
                }
            }
            
        } else if !newPinchingState && wasPinching {
            // 🔥 捏合结束
            DispatchQueue.main.async {
                self.isPinching = false
                self.pinchStartTime = nil
                self.pinchStartPosition = nil
                self.isPinchStable = false
                self.hasMoved = false
                
                if self.isCurrentlyDrawing {
                    self.stopDrawing()
                }
                
                // 重置EMA状态，准备下次绘画
                Self.smoothedPosition = nil
                Self.consecutiveLossCount = 0
            }
        }
    }
    
    // MARK: - 捏合手势检测（流畅版本）
    func checkPinchGesture(for anchor: HandAnchor, skeleton: HandSkeleton) -> (Bool, SIMD3<Float>?) {
        let thumbTransform = anchor.originFromAnchorTransform * skeleton.joint(.thumbTip).anchorFromJointTransform
        let indexTransform = anchor.originFromAnchorTransform * skeleton.joint(.indexFingerTip).anchorFromJointTransform
        
        let thumbPos = SIMD3<Float>(thumbTransform.columns.3.x,
                                     thumbTransform.columns.3.y,
                                     thumbTransform.columns.3.z)
        let indexPos = SIMD3<Float>(indexTransform.columns.3.x,
                                     indexTransform.columns.3.y,
                                     indexTransform.columns.3.z)
        
        let distance = length(thumbPos - indexPos)
        
        // 🔥 流畅：放宽阈值到 2.0cm（原来1.2cm）
        let pinchThreshold: Float = 0.020  // 2.0cm
        
        let isPinchDetected = distance < pinchThreshold
        if isPinchDetected {
            // ✅ 正确位置：使用拇指和食指的中点
            let midPoint = (thumbPos + indexPos) / 2
            return (true, midPoint)
        }
        
        return (false, nil)
    }
    
    func checkThreeFingerPinch(for anchor: HandAnchor, skeleton: HandSkeleton) -> (Bool, SIMD3<Float>?) {
        let thumbTransform = anchor.originFromAnchorTransform * skeleton.joint(.thumbTip).anchorFromJointTransform
        let indexTransform = anchor.originFromAnchorTransform * skeleton.joint(.indexFingerTip).anchorFromJointTransform
        let middleTransform = anchor.originFromAnchorTransform * skeleton.joint(.middleFingerTip).anchorFromJointTransform
        
        let thumbPos = SIMD3<Float>(thumbTransform.columns.3.x,
                                     thumbTransform.columns.3.y,
                                     thumbTransform.columns.3.z)
        let indexPos = SIMD3<Float>(indexTransform.columns.3.x,
                                     indexTransform.columns.3.y,
                                     indexTransform.columns.3.z)
        let middlePos = SIMD3<Float>(middleTransform.columns.3.x,
                                      middleTransform.columns.3.y,
                                      middleTransform.columns.3.z)
        
        let thumbIndexDistance = length(thumbPos - indexPos)
        let thumbMiddleDistance = length(thumbPos - middlePos)
        let indexMiddleDistance = length(indexPos - middlePos)
        
        // 🔥 流畅：放宽阈值到 2.5cm（原来1.8cm）
        let pinchThreshold: Float = 0.025  // 2.5cm
        
        // 三个距离都小于阈值才算三指捏合
        let allDistancesSmall = thumbIndexDistance < pinchThreshold &&
                               thumbMiddleDistance < pinchThreshold &&
                               indexMiddleDistance < pinchThreshold
        
        if allDistancesSmall {
            // ✅ 使用拇指和食指的中点
            let correctMidPoint = (thumbPos + indexPos) / 2
            return (true, correctMidPoint)
        }
        
        return (false, nil)
    }
    
    // MARK: - 绘画操作
    func startDrawing() {
        guard let position = lastPinchPosition else {
            print("⚠️ 无法获取捏合位置")
            return
        }
        
        // ✅ 检查总开关
        guard brushManager.isPaintingEnabled else {
            print("⚠️ 空间绘画未启用")
            return
        }
        
        // ✅ 检查用户绘画权限
        guard brushManager.canUserDraw else {
            print("⚠️ 用户绘画权限未开启")
            return
        }
        
        isCurrentlyDrawing = true
        let brushConfig = createBrushConfig()
        let currentUserId = userManager.getUserId()
        paintingCanvas.addPoint(position, brushConfig: brushConfig, userId: currentUserId)
        
        print("🎨 开始绘画，位置: (\(position)), 用户ID: \(currentUserId ?? -1)")
    }
    
    func continueDrawing() {
           guard let position = lastPinchPosition else { return }
           guard isCurrentlyDrawing else { return }
        
        guard brushManager.canUserDraw else {
              stopDrawing()
              return
          }
           
           if let lastPoint = paintingCanvas.currentStroke?.points.last {
               let moveDistance = length(position - lastPoint)
               
               // 🔥 使用动态阈值 - 根据手部距离自适应
               let dynamicThreshold = getDynamicSamplingThreshold(handPosition: position)
               
               if moveDistance < dynamicThreshold {
                   return
               }
               
               // 只在关键时刻打印，避免刷屏
               if moveDistance > dynamicThreshold * 2 {
                   print("🎨 继续绘画，移动距离: \(String(format: "%.4f", moveDistance))m, 阈值: \(String(format: "%.4f", dynamicThreshold))m")
               }
           }
           
           let brushConfig = createBrushConfig()
           
           // 🔥 关键修复：传递当前用户ID
           let currentUserId = userManager.getUserId()
           paintingCanvas.addPoint(position, brushConfig: brushConfig, userId: currentUserId)
       }
    
    func stopDrawing() {
        if isCurrentlyDrawing {
            paintingCanvas.finishStroke()
            isCurrentlyDrawing = false
            
            // 🔥 添加统计信息
            let currentUserId = userManager.getUserId()
            let userStrokeCount = paintingCanvas.getUserStrokeCount(userId: currentUserId)
            let totalStrokeCount = paintingCanvas.getStrokeCount()
            
            print("🎨 结束绘画")
            print("   - 当前用户笔画数: \(userStrokeCount)")
            print("   - 总笔画数: \(totalStrokeCount)")
        }
    }
    
    func createBrushConfig() -> BrushConfig {
        var config = BrushConfig()
        config.size = brushManager.brushSize * 0.001
        config.color = UIColor(brushManager.brushColor)
        return config
    }
    
    // MARK: - 加载绘画数据
    func loadAllPaintingData() async {
        guard !hasTriedLoadingPainting else {
            print("🎨 绘画数据已经尝试过加载，跳过重复加载")
            return
        }
        
        isLoadingPainting = true
        hasTriedLoadingPainting = true
        print("🎨 开始按需加载绘画数据")
        
        do {
            try await paintingCanvas.loadPaintingFromCloud(
                locationId: targetQuesionManager.currentQuestion.locationID,
                questionId: targetQuesionManager.currentQuestion.id,
                userId: nil
            )
            
            await MainActor.run {
                isPaintingLoaded = true
                paintingLoadError = nil
                isLoadingPainting = false
                print("🎨 绘画数据按需加载成功，笔画数: \(paintingCanvas.getStrokeCount())")
            }
        } catch {
            await MainActor.run {
                isPaintingLoaded = true
                paintingLoadError = error.localizedDescription
                isLoadingPainting = false
                print("🎨 绘画数据按需加载失败: \(error)")
            }
        }
    }
    
    // MARK: - 绘画通知监听
    func setupPaintingNotificationListeners() {
           NotificationCenter.default.addObserver(
               forName: NSNotification.Name("RefreshPainting"),
               object: nil,
               queue: .main
           ) { _ in
               print("🎨【收到刷新绘画指令】")
               Task {
                   await self.loadAllPaintingData()
               }
           }
           
           // 🔥 修复：清空画布 - 只清空当前用户的笔画
           NotificationCenter.default.addObserver(
               forName: NSNotification.Name("ClearCanvas"),
               object: nil,
               queue: .main
           ) { _ in
               print("🎨【收到清空画布指令】")
               
               // 获取当前用户ID
               let currentUserId = self.userManager.getUserId()
               
               if let userId = currentUserId {
                   // 清空当前用户的笔画
                   self.paintingCanvas.clearUserStrokes(userId: userId)
                   print("✅ 已清空用户 \(userId) 的画布")
               } else {
                   print("⚠️ 无法清空画布：未获取到用户ID")
               }
           }
           
           // 🔥 修复：撤回笔画 - 只撤回当前用户的最后一个笔画
           NotificationCenter.default.addObserver(
               forName: NSNotification.Name("UndoLastStroke"),
               object: nil,
               queue: .main
           ) { _ in
               print("🎨【收到撤回笔画指令】")
               
               // 获取当前用户ID
               let currentUserId = self.userManager.getUserId()
               
               if let userId = currentUserId {
                   let success = self.paintingCanvas.undoLastStroke(userId: userId)
                   if success {
                       print("✅ 成功撤回用户 \(userId) 的最后一个笔画")
                   } else {
                       print("⚠️ 没有可撤回的笔画（用户ID: \(userId)）")
                   }
               } else {
                   print("⚠️ 无法撤回笔画：未获取到用户ID")
               }
           }
           
           print("✅ 绘画通知监听器设置完成")
       }
}
