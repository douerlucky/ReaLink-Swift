//
//  AppModel.swift
//  ReaLink
//
//  Created by douer_lucky on 2025.06.18.
//
//  🎯 移动应用创新赛演示版本
//  默认地图中心已修改为固定演示坐标：
//  - 纬度: 30.477018
//  - 经度: 114.354233
//

import SwiftUI
import MapKit

enum ImmersiveSpaceState {
    case closed
    case inTransition
    case open
}

enum NavigationDestination: Hashable {
    case fullscreenMap
}

enum WindowType {
    case main
    case fullscreenMap
}

// MARK: - 地图状态保存结构
struct SavedMapState {
    let selectedAddressId: UUID?
    let mapPosition: MapCameraPosition
    let currentCenter: CLLocationCoordinate2D
    let currentSpan: MKCoordinateSpan
    let isQuestionsPanelVisible: Bool
    let currentQuestionIndex: Int
    
    init(
        selectedAddressId: UUID? = nil,
        mapPosition: MapCameraPosition = .automatic,
        currentCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 30.477018, longitude: 114.354233),  // 🎯 演示固定坐标
        currentSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01),
        isQuestionsPanelVisible: Bool = false,
        currentQuestionIndex: Int = 0
    ) {
        self.selectedAddressId = selectedAddressId
        self.mapPosition = mapPosition
        self.currentCenter = currentCenter
        self.currentSpan = currentSpan
        self.isQuestionsPanelVisible = isQuestionsPanelVisible
        self.currentQuestionIndex = currentQuestionIndex
    }
}

@Observable
class AppModel {
    var immersiveSpaceState = ImmersiveSpaceState.closed
    var immersiveSpaceID = "ImmersiveSpace"
    var isMainWindowVisible = true
    var isQuestionsPanelVisible = false
    
    // 导航状态
    var selectedTab = 0
    var navigationPath = NavigationPath()
    var shouldNavigateToFullscreenMap = false
    
    // 新增：控制是否显示全屏地图overlay
    var shouldShowFullscreenMap = false
    
    // 保存进入沉浸式空间前的状态
    var wasQuestionsPanelVisibleBeforeImmersive = false
    var wasInFullscreenMapBeforeImmersive = false
    var previousWindowType: WindowType = .main  // 记录进入前的窗口类型
    var previousSelectedTab = 0  // 记录进入前的选中tab
    
    // 场景标识符相关属性
    var currentSceneIdentifier: String?
    
    // MARK: - 新增：完整的地图状态保存
    var savedMapState: SavedMapState?
    
    // MARK: - 地图状态管理方法
    func saveMapState(
        selectedAddressId: UUID?,
        mapPosition: MapCameraPosition,
        currentCenter: CLLocationCoordinate2D,
        currentSpan: MKCoordinateSpan,
        isQuestionsPanelVisible: Bool,
        currentQuestionIndex: Int = 0
    ) {
        savedMapState = SavedMapState(
            selectedAddressId: selectedAddressId,
            mapPosition: mapPosition,
            currentCenter: currentCenter,
            currentSpan: currentSpan,
            isQuestionsPanelVisible: isQuestionsPanelVisible,
            currentQuestionIndex: currentQuestionIndex
        )
        
        print("💾 保存地图状态:")
        print("   选中地址ID: \(selectedAddressId?.uuidString ?? "无")")
        print("   问题面板可见: \(isQuestionsPanelVisible)")
        print("   问题索引: \(currentQuestionIndex)")
    }
    
    // 进入沉浸式空间前保存状态（修改版本 - 支持场景标识符）
    func prepareForImmersiveSpace(from window: WindowType = .fullscreenMap, sceneId: String? = nil) {
        // 保存当前状态
        wasQuestionsPanelVisibleBeforeImmersive = isQuestionsPanelVisible
        wasInFullscreenMapBeforeImmersive = shouldShowFullscreenMap
        previousWindowType = window
        previousSelectedTab = selectedTab
        
        // 保存场景标识符
        currentSceneIdentifier = sceneId
        
        // 进入沉浸式空间时隐藏UI元素
        isQuestionsPanelVisible = false
        shouldShowFullscreenMap = false // 进入沉浸式空间时关闭地图overlay
        
        print("🎬 准备进入沉浸式空间")
        print("📍 来源窗口: \(window)")
        print("🌐 场景ID: \(sceneId ?? "默认场景")")
        print("🗺 之前地图状态: \(wasInFullscreenMapBeforeImmersive)")
        print("📋 之前面板状态: \(wasQuestionsPanelVisibleBeforeImmersive)")
        print("🏷 之前选中tab: \(previousSelectedTab)")
        print("💾 保存的地图状态: \(savedMapState != nil ? "已保存" : "未保存")")
    }
    
    // 退出沉浸式空间后恢复状态（增强版本）
    func restoreAfterImmersiveSpace() {
        print("🔄 开始恢复沉浸式空间后的状态...")
        
        // 确保回到正确的 tab（ExploreView 是 tab 0）
        selectedTab = 0
        
        // 如果之前是从 fullscreenMap 进入的，恢复地图显示
        if previousWindowType == .fullscreenMap && wasInFullscreenMapBeforeImmersive {
            // 延迟一点恢复，确保窗口已经完全加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { // 增加延迟
                print("🗺 恢复全屏地图显示...")
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    self.shouldShowFullscreenMap = true
                }
                
                // 如果有保存的地图状态且之前问题面板可见，恢复问题面板
                if let mapState = self.savedMapState, mapState.isQuestionsPanelVisible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("📋 恢复问题面板显示...")
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            self.isQuestionsPanelVisible = true
                        }
                    }
                }
            }
        }
        
        print("🔄 沉浸式空间状态已恢复")
        print("🗺 恢复地图状态: \(shouldShowFullscreenMap)")
        print("🏷 当前选中tab: \(selectedTab)")
        print("💾 将要恢复的地图状态: \(savedMapState != nil ? "有保存状态" : "无保存状态")")
    }
    
    // 手动设置显示全屏地图的方法（用于ExploreView中的按钮）
    func showFullscreenMap() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldShowFullscreenMap = true
        }
    }
    
    // 关闭全屏地图的方法
    func hideFullscreenMap() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldShowFullscreenMap = false
            isQuestionsPanelVisible = false // 同时关闭问题面板
        }
        // 清理保存的地图状态
        savedMapState = nil
    }
    
    // MARK: - 问题面板控制方法
    func showQuestionsPanel() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isQuestionsPanelVisible = true
        }
    }
    
    func hideQuestionsPanel() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isQuestionsPanelVisible = false
        }
    }
    
    // 清理场景标识符
    func clearSceneIdentifier() {
        currentSceneIdentifier = nil
        print("🧹 已清理场景标识符")
    }
    
    // 重置状态
    func reset() {
        isQuestionsPanelVisible = false
        shouldShowFullscreenMap = false
        wasQuestionsPanelVisibleBeforeImmersive = false
        wasInFullscreenMapBeforeImmersive = false
        shouldNavigateToFullscreenMap = false
        selectedTab = 0
        previousSelectedTab = 0
        savedMapState = nil
        
        // 重置时也清理场景标识符
        clearSceneIdentifier()
        
        print("🔄 AppModel 状态已重置")
    }
    
    
    // 新增：强制切换到 ExploreView 并显示全屏地图
    func forceShowExploreWithFullscreenMap() {
        selectedTab = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.showFullscreenMap()
        }
    }
}
