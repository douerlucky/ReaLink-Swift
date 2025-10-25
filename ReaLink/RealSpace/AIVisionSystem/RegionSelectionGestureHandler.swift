//
//  RegionSelectionGestureHandler.swift
//  ReaLink
//
//  区域选择手势处理（基于手部追踪）- Vision OS 2.5 修复版
//

import RealityKit
import SwiftUI
import ARKit

// MARK: - BasicPanoramaView 扩展
extension BasicPanoramaView {
    
    // MARK: - 设置区域选择监听器
    func setupRegionSelectionListeners() {
        print("🎯【开始设置区域圈选监听器】")
        
        // 初始化区域选择管理器（如果还没初始化）
        if regionSelectionManager == nil {
            regionSelectionManager = RegionSelectionManager(rootEntity: rootEntity)
            print("🎯【区域选择管理器已初始化】")
        }
        
        // 启用区域选择
        let enableObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EnableRegionSelection"),
            object: nil,
            queue: .main
        ) { notification in  // 🔥 修复：移除 [weak self]，因为 BasicPanoramaView 是 struct
            print("🎯【收到启用区域圈选通知】")
            
            // 🔥 修复：直接访问当前实例，而不使用self（struct不需要weak）
            if let currentView = notification.object as? BasicPanoramaView {
                currentView.enableRegionSelection()
            } else {
                // 使用通知的方式来处理
                self.enableRegionSelection()
            }
        }
        notificationObservers.append(enableObserver)
        
        // 禁用区域选择
        let disableObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DisableRegionSelection"),
            object: nil,
            queue: .main
        ) { notification in  // 🔥 修复：移除 [weak self]
            print("❌【收到禁用区域圈选通知】")
            
            if let currentView = notification.object as? BasicPanoramaView {
                currentView.disableRegionSelection()
            } else {
                self.disableRegionSelection()
            }
        }
        notificationObservers.append(disableObserver)
        
        // 区域圈选完成
        let completionObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RegionSelectionCompleted"),
            object: nil,
            queue: .main
        ) { notification in  // 🔥 修复：移除 [weak self]
            if let region = notification.userInfo?["region"] as? SelectionRegion {
                print("✅【区域圈选完成】")
                print("   - 中心: \(region.center)")
                print("   - 尺寸: \(region.size)")
                
                // 🔥 发送AI识别请求
                self.sendRegionForAIRecognition(region)
            }
        }
        notificationObservers.append(completionObserver)
        
     
        // 3️⃣ 监听：拟合球面可视化通知（修复版 - 支持UV跨越边界）
        let visualizationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowFittedSphericalRegion"),
            object: nil,
            queue: .main
        ) {  notification in
            print("🎨【收到显示拟合球面通知】")
            
            guard
                  let userInfo = notification.userInfo,
                  let fittedPoints = userInfo["fittedPoints"] as? [SIMD3<Float>],
                  let radius = userInfo["radius"] as? Float,
                  let averageY = userInfo["averageY"] as? Float else {
                print("❌【拟合球面参数不完整】")
                return
            }
            
            // 🔥 关键修复：检查是否跨越边界
            let isWrapping = userInfo["isWrapping"] as? Bool ?? false
            
            // 清除旧的可视化
            self.rootEntity.children.forEach { child in
                if child.name.hasPrefix("fitted_spherical_region") {
                    child.removeFromParent()
                }
            }
            
            // 🔥 根据是否跨越边界选择不同的创建方法
            let fittedRegion: Entity
            
            if isWrapping {
                print("   🔄【检测到UV跨越边界】使用两段拼接可视化")
                
                let hasSegment1 = userInfo["hasSegment1"] as? Bool ?? false
                let hasSegment2 = userInfo["hasSegment2"] as? Bool ?? false
                
                var segment1Azimuth: (Float, Float)? = nil
                var segment2Azimuth: (Float, Float)? = nil
                
                if hasSegment1, let seg1 = userInfo["segment1Azimuth"] as? [Float], seg1.count == 2 {
                    segment1Azimuth = (seg1[0], seg1[1])
                }
                
                if hasSegment2, let seg2 = userInfo["segment2Azimuth"] as? [Float], seg2.count == 2 {
                    segment2Azimuth = (seg2[0], seg2[1])
                }
                
                guard let elevationRange = userInfo["elevationRange"] as? [Float], elevationRange.count == 2 else {
                    print("❌【缺少仰角范围参数】")
                    return
                }
                
                // 使用修复版方法创建两段拼接可视化
                fittedRegion = TestSphericalRegion.createFittedRegionVisualizationFixed(
                    azimuthRange: (0, 0),  // 占位,不会被使用
                    elevationRange: (elevationRange[0], elevationRange[1]),
                    radius: radius,
                    isWrapping: true,
                    segment1Azimuth: segment1Azimuth,
                    segment2Azimuth: segment2Azimuth
                )
                
            } else {
                print("   ✅【UV未跨越边界】使用单一区域可视化")
                
                guard let azimuthRange = userInfo["azimuthRange"] as? [Float], azimuthRange.count == 2,
                      let elevationRange = userInfo["elevationRange"] as? [Float], elevationRange.count == 2 else {
                    print("❌【球面范围参数格式错误】")
                    return
                }
                
                fittedRegion = TestSphericalRegion.createFittedRegionVisualization(
                    azimuthRange: (azimuthRange[0], azimuthRange[1]),
                    elevationRange: (elevationRange[0], elevationRange[1]),
                    radius: radius
                )
            }
            
            self.rootEntity.addChild(fittedRegion)
            
            print("✅【拟合球面可视化已添加到场景】")
            print("   - 拟合点数: \(fittedPoints.count)")
            print("   - 原始平均高度: \(String(format: "%.2f", averageY))m")
            print("   - 拟合半径: \(radius)m")
            print("   - 是否跨越边界: \(isWrapping ? "是(两段拼接)" : "否(单一区域)")")
        }
        notificationObservers.append(visualizationObserver)
        
        // 1️⃣ 监听：取消区域选择（清除所有可视化）
        let cancelObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CancelRegionSelection"),
            object: nil,
            queue: .main
        ) {  _ in
            print("🧹【收到取消区域选择通知】清除所有可视化")
            
            // 清除 RegionSelectionManager 的可视化
            self.regionSelectionManager?.cancelSelection()
            
            // 🔥 关键：清除拟合球面（黄色区域）
            self.hideTestSphericalRegion()
            
            print("✅【取消完成】用户圈选区域和拟合球面已清除")
        }
        notificationObservers.append(cancelObserver)

        // 2️⃣ 监听：AI助手窗口关闭
        let windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AIAssistantWindowWillClose"),
            object: nil,
            queue: .main
        ) {  _ in
            print("🪟【AI助手窗口即将关闭】清除所有区域选择可视化")

            // 清除 RegionSelectionManager 的可视化
            self.regionSelectionManager?.cleanupOnWindowClose()
            
            // 🔥 关键：清除拟合球面（黄色区域）
            self.hideTestSphericalRegion()
            
            // 禁用区域选择
            NotificationCenter.default.post(
                name: NSNotification.Name("DisableRegionSelection"),
                object: nil
            )
            
            print("✅【窗口关闭清理完成】所有可视化已清除")
        }
        notificationObservers.append(windowCloseObserver)


        print("✅【区域圈选监听器设置完成】（含可视化监听）")
        
        
    }
    
    // MARK: - 🔥 启用区域选择（修复版 - 确保状态正确）
    private func enableRegionSelection() {
        print("🎯【启用区域选择】")
        
        // 🔥 关键修复1:先清理旧实例
        if regionSelectionHandTracking != nil {
            print("   🧹【清理旧的手势追踪实例】")
            regionSelectionHandTracking?.stopTracking()
            regionSelectionHandTracking = nil
        }
        
        // 🔥 关键修复2:设置启用状态
        isRegionSelectionEnabled = true
        
        // 🔥 关键修复3:创建新实例
        regionSelectionHandTracking = RegionSelectionHandTracking()
        regionSelectionHandTracking?.selectionManager = regionSelectionManager
        
        // 🔥 关键修复4:启动追踪
        regionSelectionHandTracking?.startTracking()
        
        print("✅【区域圈选已启用】用户可以双指捏合框选区域")
    }
    
    // MARK: - 🔥 禁用区域选择（修复版 - 确保完全停止）
    private func disableRegionSelection() {
        print("❌【禁用区域选择】")
        
        // 🔥 关键修复1:先设置禁用状态(这样手势不会再触发)
        isRegionSelectionEnabled = false
        
        // 🔥 关键修复2:停止追踪
        regionSelectionHandTracking?.stopTracking()
        
        // 🔥 关键修复3:延迟清理引用(确保deinit正确执行)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.regionSelectionHandTracking = nil
            print("   🧹【手势追踪实例已清理】")
        }
        
        // 🔥 关键修复4:取消当前圈选(这会清除可视化)
        regionSelectionManager?.cancelSelection()
        
        print("✅【区域圈选已完全禁用】不能再进行双指画选")
    }
    // MARK: - 发送AI识别请求
    func sendRegionForAIRecognition(_ region: SelectionRegion) {
        print("🤖【准备发送AI识别】")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: NSNotification.Name("AIRecognitionStarted"),
                object: nil,
                userInfo: ["region": region]
            )
            
            print("🤖【AI识别请求已发送】")
        }
    }
    
    // MARK: - 🔥 手动启动区域选择（用于调试）
    func startRegionSelectionManually() {
        print("🎯【手动启动区域选择】")
        
        // 确保管理器已初始化
        if regionSelectionManager == nil {
            regionSelectionManager = RegionSelectionManager(rootEntity: rootEntity)
        }
        
        // 确保手势追踪已创建
        if regionSelectionHandTracking == nil {
            regionSelectionHandTracking = RegionSelectionHandTracking()
            regionSelectionHandTracking?.selectionManager = regionSelectionManager
        }
        
        // 启用并开始追踪
        isRegionSelectionEnabled = true
        regionSelectionHandTracking?.startTracking()
        
        print("✅【手动启动完成】现在可以进行区域圈选")
    }
    
    // MARK: - 🔥 手动停止区域选择（用于调试）
    func stopRegionSelectionManually() {
        print("🎯【手动停止区域选择】")
        
        isRegionSelectionEnabled = false
        regionSelectionHandTracking?.stopTracking()
        regionSelectionManager?.cancelSelection()
        
        print("✅【手动停止完成】")
    }
    
    
}

// MARK: - 🔥 新增：用于测试的便捷方法
extension BasicPanoramaView {
    
    // 测试区域选择功能
    func testRegionSelection() {
        print("🧪【开始测试区域选择功能】")
        
        // 模拟启用通知
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationCenter.default.post(
                name: NSNotification.Name("EnableRegionSelection"),
                object: self
            )
        }
        
        // 10秒后自动禁用
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            NotificationCenter.default.post(
                name: NSNotification.Name("DisableRegionSelection"),
                object: self
            )
        }
    }
    
    // 检查区域选择状态
    func checkRegionSelectionStatus() -> String {
        var status = "🔍【区域选择状态检查】\n"
        
        status += "- 是否启用: \(isRegionSelectionEnabled)\n"
        status += "- 管理器状态: \(regionSelectionManager != nil ? "已创建" : "未创建")\n"
        status += "- 手势追踪状态: \(regionSelectionHandTracking != nil ? "已创建" : "未创建")\n"
        
        if let manager = regionSelectionManager {
            status += "- 是否正在选择: \(manager.isSelecting)\n"
        }
        
        if let tracking = regionSelectionHandTracking {
            status += "- 是否正在追踪: \(tracking.isTracking)\n"
        }
        
        print(status)
        return status
    }
}

// MARK: - 🔥 修复版本信息
/*
 修复内容：
 1. ❌ 移除了 [weak self] - BasicPanoramaView 是 struct，不支持 weak 引用
 2. ✅ 改用直接的 self 访问或通过 notification.object 传递实例
 3. ✅ 分离了启用/禁用方法，避免在闭包中重复代码
 4. ✅ 新增了手动测试方法，便于调试
 5. ✅ 新增了状态检查方法，便于诊断问题
 
 使用方法：
 - 通过通知启用: NotificationCenter.default.post(name: NSNotification.Name("EnableRegionSelection"), object: nil)
 - 手动启用: view.startRegionSelectionManually()
 - 检查状态: view.checkRegionSelectionStatus()
 */
