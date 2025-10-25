//
//  PaintingSystem.swift
//  ReaLink
//
//  空间绘画系统
//

import RealityKit
import SwiftUI
import ARKit

extension BasicPanoramaView {
    
    // MARK: - 绘画模式处理
    func handlePaintingModeChange(_ newValue: Bool) {
        print("🎨 绘画模式切换: \(newValue)")
        
        if newValue {
            Task { @MainActor in
                await self.updatePaintingCanvasInScene()
                await self.handTracking.startTracking()
                
                if !hasTriedLoadingPainting {
                    await self.loadAllPaintingData()
                }
                
                print("🎨 绘画模式启用完成")
            }
        } else {
            stopDrawing()
            
            Task { @MainActor in
                self.handTracking.stopTracking()
                await self.updatePaintingCanvasInScene()
            }
            
            print("🎨 绘画已禁用")
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
    
    // MARK: - 手势追踪更新（同步版本）
    func performHandTrackingUpdateSync() {
        var detectedPinch = false
        var pinchPosition: SIMD3<Float>?
        var pinchingHand: String = ""
        
        if let leftHand = handTracking.latestLeftHand,
           let handSkeleton = leftHand.handSkeleton {
            
            let (isPinch2, position2) = checkPinchGesture(for: leftHand, skeleton: handSkeleton)
            let (isPinch3, position3) = checkThreeFingerPinch(for: leftHand, skeleton: handSkeleton)
            
            if isPinch2 || isPinch3 {
                detectedPinch = true
                pinchPosition = isPinch3 ? position3 : position2
                pinchingHand = isPinch3 ? "左手(3指)" : "左手(2指)"
            }
        }
        
        if let rightHand = handTracking.latestRightHand,
           let handSkeleton = rightHand.handSkeleton {
            
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
        
        let wasPinching = isPinching
        let newPinchPosition = pinchPosition
        let newPinchingState = detectedPinch
        
        if newPinchingState != wasPinching {
            DispatchQueue.main.async {
                self.isPinching = newPinchingState
                self.lastPinchPosition = newPinchPosition
                
                if newPinchingState && !wasPinching {
                    self.startDrawing()
                } else if !newPinchingState && wasPinching {
                    self.stopDrawing()
                }
            }
        } else if newPinchingState && wasPinching && isCurrentlyDrawing {
            DispatchQueue.main.async {
                self.lastPinchPosition = newPinchPosition
                self.continueDrawing()
            }
        }
    }
    
    // MARK: - 捏合手势检测
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
        let pinchThreshold: Float = 0.020
        
        let isPinchDetected = distance < pinchThreshold
        if isPinchDetected {
            let midPoint = (thumbPos + indexPos) / 2
            print("✋ 检测到捏合手势: \(anchor.chirality == .left ? "左手" : "右手"), 距离: \(String(format: "%.3f", distance))m")
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
        
        let pinchThreshold: Float = 0.015
        
        let allDistancesSmall = thumbIndexDistance < pinchThreshold &&
                               thumbMiddleDistance < pinchThreshold &&
                               indexMiddleDistance < pinchThreshold
        
        if allDistancesSmall {
            let centerPoint = (thumbPos + indexPos + middlePos) / 3
            return (true, centerPoint)
        }
        
        return (false, nil)
    }
    
    // MARK: - 绘画操作
    func startDrawing() {
            guard let position = lastPinchPosition else {
                print("⚠️ 无法获取捏合位置")
                return
            }
            
            guard brushManager.isPaintingEnabled else {
                print("⚠️ 绘画未启用")
                return
            }
            
            isCurrentlyDrawing = true
            let brushConfig = createBrushConfig()
            
            // 🔥 关键修复：传递当前用户ID
            let currentUserId = userManager.getUserId()
            paintingCanvas.addPoint(position, brushConfig: brushConfig, userId: currentUserId)
            
            print("🎨 开始绘画，位置: (\(String(format: "%.3f", position.x)), \(String(format: "%.3f", position.y)), \(String(format: "%.3f", position.z))), 用户ID: \(currentUserId ?? -1)")
        }
    
    func continueDrawing() {
           guard let position = lastPinchPosition else { return }
           guard isCurrentlyDrawing else { return }
           
           if let lastPoint = paintingCanvas.currentStroke?.points.last {
               let moveDistance = length(position - lastPoint)
               if moveDistance < 0.001 {
                   return
               }
               print("🎨 继续绘画，移动距离: \(String(format: "%.4f", moveDistance))m")
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
