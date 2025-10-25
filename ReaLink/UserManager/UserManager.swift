import Foundation
import SwiftUI
import UIKit
import CoreLocation

@MainActor
class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    static let shared = UserManager()
    
    private let userDefaultsKey = "saved_user_data"
    private let userIdKey = "saved_user_id"
    
    private init() {
        loadSavedUser()
    }
    
    // MARK: - 持久化方法（简化版）
    
    private func saveUser(_ user: User) {
        // 保存用户信息到 UserDefaults（简化版，不使用加密）
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userDefaultsKey)
            UserDefaults.standard.set(user.id, forKey: userIdKey)
            UserDefaults.standard.set(true, forKey: "is_user_logged_in")
            print("✅ 用户信息已保存到本地: \(user.username) (ID: \(user.id))")
        }
    }
    
    // 在 UserManager.swift 的 loadSavedUser 方法中添加调试
    private func loadSavedUser() {
        guard UserDefaults.standard.bool(forKey: "is_user_logged_in") else {
            print("❌ 用户未登录")
            return
        }
        
        guard let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            print("❌ 未找到保存的用户信息")
            clearSavedUser()
            return
        }
        
        // 验证保存的用户ID是否一致
        let savedUserId = UserDefaults.standard.object(forKey: userIdKey) as? Int64
        if savedUserId != user.id {
            print("⚠️ 保存的用户ID不一致，清除数据")
            clearSavedUser()
            return
        }
        
        self.currentUser = user
        self.isLoggedIn = true
        
        // 🔍 添加调试信息
        print("✅ 自动登录成功: \(user.username) (ID: \(user.id))")
        print("📷 用户头像URL: '\(user.avatarUrl ?? "无")'")
        
        // 🔥 添加这行：立即刷新用户信息
           Task {
               await refreshUserInfo()
           }
        
        // 验证用户信息是否仍然有效
        Task {
            await validateUserToken(user.id)
        }
    }
    private func clearSavedUser() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.set(false, forKey: "is_user_logged_in")
        self.currentUser = nil
        self.isLoggedIn = false
        self.errorMessage = nil
        print("🗑️ 已清除保存的用户信息")
    }
    
    // MARK: - 用户信息验证（后台静默验证）
    
    private func validateUserToken(_ userId: Int64) async {
        // 静默验证用户信息是否仍然有效，不影响UI状态
        do {
            let response = try await NetworkManager.shared.getUserInfo(userId: userId)
            if response.success, let serverUser = response.user {
                // 🔥 关键修改：无论本地数据是否一致，都强制使用服务器最新数据
                self.currentUser = serverUser
                saveUser(serverUser)
                print("🔄 用户信息已从服务器同步更新")
                print("   旧头像URL: \(self.currentUser?.avatarUrl ?? "无")")
                print("   新头像URL: \(serverUser.avatarUrl ?? "无")")
            } else {
                // 服务器验证失败，可能用户已被删除或禁用
                print("⚠️ 服务器用户验证失败，保持本地状态")
            }
        } catch {
            // 网络错误或服务器错误，保持本地状态
            print("⚠️ 用户信息验证失败（网络错误）: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 登录方法
    
    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await NetworkManager.shared.login(username: username, password: password)
            
            if response.success, let user = response.user {
                // 保存用户信息
                saveUser(user)
                
                // 更新当前状态
                self.currentUser = user
                self.isLoggedIn = true
                
                // 添加调试信息
                print("登录成功，用户数据:")
                print("  ID: \(user.id)")
                print("  用户名: \(user.username)")
                print("  头像URL: '\(user.avatarUrl ?? "无")'")
                print("  创建时间: \(user.createdAt ?? "无")")
    
                
                print("✅ 登录成功: \(user.username) (ID: \(user.id))")
            } else {
                self.errorMessage = response.message ?? "登录失败"
                print("❌ 登录失败: \(response.message ?? "未知错误")")
            }
        } catch {
            self.errorMessage = "网络错误: \(error.localizedDescription)"
            print("❌ 登录网络错误: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 注册方法
    
    func register(username: String, password: String, avatarUrl: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await NetworkManager.shared.register(
                username: username,
                password: password,
                avatarUrl: avatarUrl
            )
            
            if response.success {
                self.errorMessage = nil
                print("✅ 注册成功，请登录")
            } else {
                self.errorMessage = response.message ?? "注册失败"
                print("❌ 注册失败: \(response.message ?? "未知错误")")
            }
        } catch {
            self.errorMessage = "网络错误: \(error.localizedDescription)"
            print("❌ 注册网络错误: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 登出方法
    
    func logout() {
        clearSavedUser()
        print("👋 用户已登出")
    }
    
    // MARK: - 用户信息更新
    func updateUser(_ updatedUser: User) {
        let oldAvatarUrl = self.currentUser?.avatarUrl
        self.currentUser = updatedUser
        saveUser(updatedUser)
        
        print("✅ 用户信息已更新: \(updatedUser.username)")
        print("   头像URL变化: \(oldAvatarUrl ?? "无") -> \(updatedUser.avatarUrl ?? "无")")
        
        // 发送通知强制UI更新
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - 更新用户资料（通过网络）
    
    func updateUserProfile(username: String, avatarUrl: String? = nil) async {
        guard let currentUser = self.currentUser else {
            self.errorMessage = "用户未登录"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await NetworkManager.shared.updateUserProfile(
                userId: currentUser.id,
                username: username,
                avatarUrl: avatarUrl
            )
            
            if response.success, let updatedUser = response.user {
                // 更新本地用户信息
                self.currentUser = updatedUser
                saveUser(updatedUser)
                print("✅ 用户资料更新成功: \(updatedUser.username)")
            } else {
                self.errorMessage = response.message ?? "更新失败"
                print("❌ 用户资料更新失败: \(response.message ?? "未知错误")")
            }
        } catch {
            self.errorMessage = "网络错误: \(error.localizedDescription)"
            print("❌ 用户资料更新网络错误: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 新增：检查用户名可用性
    
    func checkUsernameAvailability(username: String) async -> CheckUsernameResponse? {
        do {
            let response = try await NetworkManager.shared.checkUsernameAvailability(
                username: username,
                currentUserId: currentUser?.id
            )
            return response
        } catch {
            print("❌ 检查用户名可用性失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 新增：上传头像
    
    func uploadAvatar(image: UIImage) async -> Bool {
        guard let currentUser = self.currentUser else {
            self.errorMessage = "用户未登录"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🔄 开始上传头像，用户ID: \(currentUser.id)")
        print("🔄 当前头像URL: \(currentUser.avatarUrl ?? "无")")
        
        do {
            let response = try await NetworkManager.shared.uploadAvatar(
                image: image,
                userId: currentUser.id
            )
            
            print("🔄 收到上传响应:")
            print("   成功: \(response.success)")
            print("   消息: \(response.message ?? "无")")
            print("   新头像URL: \(response.user?.avatarUrl ?? "无")")
            
            if response.success, let updatedUser = response.user {
                // 更新本地用户信息
                let oldAvatarUrl = self.currentUser?.avatarUrl
                self.currentUser = updatedUser
                saveUser(updatedUser)
                
                print("✅ 头像上传成功")
                print("   旧URL: \(oldAvatarUrl ?? "无")")
                print("   新URL: \(updatedUser.avatarUrl ?? "无")")
                
                isLoading = false
                return true
            } else {
                self.errorMessage = response.message ?? "头像上传失败"
                print("❌ 头像上传失败: \(response.message ?? "未知错误")")
                isLoading = false
                return false
            }
        } catch {
            self.errorMessage = "头像上传失败: \(error.localizedDescription)"
            print("❌ 头像上传网络错误: \(error)")
            isLoading = false
            return false
        }
    }

    // 添加刷新用户信息的方法
    func refreshUserInfo() async {
        guard let currentUser = self.currentUser else { return }
        
        print("🔄 开始刷新用户信息...")
        
        do {
            let response = try await NetworkManager.shared.getUserInfo(userId: currentUser.id)
            if response.success, let refreshedUser = response.user {
                self.currentUser = refreshedUser
                saveUser(refreshedUser)
                
                print("✅ 用户信息已刷新")
                print("   新头像URL: \(refreshedUser.avatarUrl ?? "无")")
            }
        } catch {
            print("⚠️ 刷新用户信息失败: \(error.localizedDescription)")
        }
    }

    
    // MARK: - 手动设置用户（用于测试或特殊场景）
    
    func setUser(_ user: User) {
        saveUser(user)
        self.currentUser = user
        self.isLoggedIn = true
        self.errorMessage = nil
        print("✅ 手动设置用户: \(user.username) (ID: \(user.id))")
    }
    
    // MARK: - 检查登录状态
    
    func checkLoginStatus() -> Bool {
        return isLoggedIn && currentUser != nil
    }
    
    // MARK: - 获取用户信息的便捷方法
    
    func getUserId() -> Int64? {
        return currentUser?.id
    }
    
    func getUsername() -> String? {
        return currentUser?.username
    }
    
    func getAvatarUrl() -> String? {
        return currentUser?.avatarUrl
    }
    
    func getCreatedAt() -> String? {
        return currentUser?.createdAt
    }
    
    func getUpdatedAt() -> String? {
        return currentUser?.updatedAt
    }
}

// 在 UserManager.swift 中优化位置更新方法

extension UserManager {
    
    // 优化后的登录+位置更新方法
    func loginWithLocationUpdate(username: String, password: String) async {
        // 先进行正常登录
        await login(username: username, password: password)
        
        // 登录成功后尝试上报位置
        if isLoggedIn, let userId = getUserId() {
            await updateUserLocationOnLogin(userId: userId)
        }
    }
    
    // 应用启动时的位置更新（优化版）
    func updateLocationOnAppStart() async {
        guard isLoggedIn, let userId = getUserId() else {
            print("用户未登录，跳过位置更新")
            return
        }
        
        print("📍 开始应用启动时的位置更新流程")
        await updateUserLocationOnLogin(userId: userId)
    }
    
    // 核心位置更新逻辑（重构后的版本）
    private func updateUserLocationOnLogin(userId: Int64) async {
        print("🚀 开始位置上报流程 - 用户ID: \(userId)")
        
        let locationManager = LocationManager.shared
        
        // 步骤1: 检查并请求位置权限
        await requestLocationPermissionIfNeeded(locationManager: locationManager)
        
        // 步骤2: 尝试获取位置（如果有权限）
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            await attemptLocationUpdate(locationManager: locationManager, userId: userId)
        } else {
            print("⚠️ 没有位置权限，跳过位置上报。当前状态: \(locationManager.authorizationStatus.rawValue)")
        }
    }
    
    // 请求位置权限（如果需要）
    private func requestLocationPermissionIfNeeded(locationManager: LocationManager) async {
        if locationManager.authorizationStatus == .notDetermined {
            print("📍 请求位置权限...")
            locationManager.requestLocationPermission()
            
            // 等待权限响应（最多5秒）
            var waitTime = 0
            while locationManager.authorizationStatus == .notDetermined && waitTime < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                waitTime += 1
            }
            
            print("📍 权限请求结果: \(locationManager.authorizationStatus.rawValue)")
        }
    }
    
    // 尝试获取并上报位置
    private func attemptLocationUpdate(locationManager: LocationManager, userId: Int64) async {
        // 检查是否已有有效位置
        if !locationManager.hasValidLocation {
            print("📍 请求当前位置...")
            locationManager.requestLocationOnce()
            
            // 等待位置更新（最多10秒）
            var waitTime = 0
            while !locationManager.hasValidLocation && waitTime < 100 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                waitTime += 1
            }
        }
        
        // 上报位置到服务器
        if let location = locationManager.currentLocation, locationManager.hasValidLocation {
            await uploadLocationToServer(location: location, userId: userId)
        } else {
            let errorMessage = locationManager.locationError ?? "未知原因"
            print("⚠️ 无法获取有效位置，跳过上报。错误: \(errorMessage)")
        }
    }
    
    // 上报位置到服务器
    private func uploadLocationToServer(location: CLLocation, userId: Int64) async {
        print("📤 准备上报位置: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("📤 位置精度: \(location.horizontalAccuracy)米")
        
        do {
            let response = try await NetworkManager.shared.updateUserLocation(
                userId: userId,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy
            )
            
            if response.success {
                print("✅ 位置上报成功")
                
                // 可选：保存最后上报时间到UserDefaults
                UserDefaults.standard.set(Date(), forKey: "last_location_update")
            } else {
                print("❌ 位置上报失败: \(response.message ?? "未知错误")")
            }
        } catch {
            print("❌ 位置上报网络错误: \(error.localizedDescription)")
        }
    }
    
    // 检查是否需要更新位置（避免频繁请求）
    func shouldUpdateLocation() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: "last_location_update") as? Date else {
            return true // 从未更新过
        }
        
        // 如果上次更新超过30分钟，则需要更新
        let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
        return lastUpdate < thirtyMinutesAgo
    }
    
    // 手动刷新位置（用户主动触发）
    func refreshUserLocation() async {
        guard let userId = getUserId() else {
            print("❌ 无法刷新位置：用户未登录")
            return
        }
        
        print("🔄 用户手动刷新位置")
        await updateUserLocationOnLogin(userId: userId)
    }
}
