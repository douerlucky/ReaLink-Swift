//
//  LoginView.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/8/24.
//

// LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isShowingRegister = false
    @State private var rememberMe = true
    @State private var showingLocationPermission = false // 新增
    
    @FocusState private var usernameFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    
    // 动画状态
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var formOffset: CGFloat = 100
    @State private var formOpacity: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 渐变背景
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1),
                        Color.orange.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // 顶部关闭按钮
                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                                .background(.regularMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                        .opacity(formOpacity)
                    }
                    
                    Spacer()
                    
                    // Logo 和标题
                    VStack(spacing: 20) {
                        Image("ReaLinkLogo")
                            .resizable()
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                            .frame(width: 64,height: 64)
                        VStack(spacing: 8) {
                            Text("欢迎来到 ReaLink")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("连接真实世界的每一个问答")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .opacity(logoOpacity)
                    }
                    
                    // 登录表单
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            // 用户名输入框
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                
                                TextField("用户名", text: $username)
                                    .focused($usernameFieldFocused)
                                    .textContentType(.username)
                                    .autocorrectionDisabled()
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(usernameFieldFocused ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            
                            // 密码输入框
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                
                                SecureField("密码", text: $password)
                                    .focused($passwordFieldFocused)
                                    .textContentType(.password)
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(passwordFieldFocused ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        
                        // 记住我选项
                        HStack {
                            Button(action: { rememberMe.toggle() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                        .foregroundColor(rememberMe ? .blue : .secondary)
                                    Text("记住我")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button("忘记密码？") {
                                // TODO: 实现忘记密码功能
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 4)
                        
                        // 错误信息
                        if let errorMessage = userManager.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // 登录按钮
                        Button(action: handleLogin) {
                            HStack {
                                if userManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.right")
                                }
                                Text(userManager.isLoading ? "登录中..." : "登录")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(username.isEmpty || password.isEmpty || userManager.isLoading)
                        .scaleEffect(canLogin ? 1.0 : 0.95)
                        .animation(.easeInOut(duration: 0.2), value: canLogin)
                        
                        // 注册链接
                        HStack {
                            Text("还没有账号？")
                                .foregroundColor(.secondary)
                            
                            Button("立即注册") {
                                isShowingRegister = true
                            }
                            .foregroundColor(.blue)
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: 400)
                    .offset(y: formOffset)
                    .opacity(formOpacity)
                    
                    Spacer()
                    
                    // 底部版权信息
                    Text("© 2025 ReaLink. All rights reserved.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(formOpacity)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            .navigationBarHidden(true)
            .onAppear {
                performAppearAnimation()
            }
            .onSubmit {
                if usernameFieldFocused && password.isEmpty {
                    passwordFieldFocused = true
                } else if passwordFieldFocused && canLogin {
                    handleLogin()
                }
            }
            .sheet(isPresented: $isShowingRegister) {
                RegisterView()
                    .environmentObject(userManager)
            }
            .sheet(isPresented: $showingLocationPermission) {
                           LocationPermissionView()
                       }
        }
    }
    
    // MARK: - 计算属性
    
    private var canLogin: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !userManager.isLoading
    }
    
    // MARK: - 方法
    
    private func handleLogin() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
                    // 使用新的带位置更新的登录方法
                    await userManager.loginWithLocationUpdate(username: trimmedUsername, password: password)
                    
                    // 登录成功后处理
                    if userManager.isLoggedIn {
                        // 检查位置权限状态
                        let locationManager = LocationManager.shared
                        if locationManager.authorizationStatus == .notDetermined {
                            // 延迟一下显示权限请求，让登录完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showingLocationPermission = true
                            }
                        }
                        dismiss()
                    }
        }
    }
    
    private func performAppearAnimation() {
        // Logo 动画
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // 表单动画
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4)) {
            formOffset = 0
            formOpacity = 1.0
        }
        
        // 自动聚焦到用户名输入框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            usernameFieldFocused = true
        }
    }
}

// MARK: - 注册视图
struct RegisterView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var avatarUrl: String = ""
    @State private var showSuccessMessage = false
    
    @FocusState private var focusedField: RegisterField?
    
    enum RegisterField {
        case username, password, confirmPassword, avatarUrl
    }
    
    // 动画状态
    @State private var formOffset: CGFloat = 50
    @State private var formOpacity: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.1),
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // 顶部关闭按钮
                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                                .background(.regularMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                        .opacity(formOpacity)
                    }
                    
                    // 标题
                    VStack(spacing: 8) {
                        Text("创建新账号")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("加入 ReaLink 社区")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .opacity(formOpacity)
                    
                    // 注册表单
                    VStack(spacing: 20) {
                        // 用户名
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            TextField("用户名", text: $username)
                                .focused($focusedField, equals: .username)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(focusedField == .username ? Color.green : Color.clear, lineWidth: 2)
                        )
                        
                        // 密码
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            SecureField("密码（至少6位）", text: $password)
                                .focused($focusedField, equals: .password)
                                .textContentType(.newPassword)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(focusedField == .password ? Color.green : Color.clear, lineWidth: 2)
                        )
                        
                        // 确认密码
                        HStack {
                            Image(systemName: "lock.rectangle.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            SecureField("确认密码", text: $confirmPassword)
                                .focused($focusedField, equals: .confirmPassword)
                                .textContentType(.newPassword)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(focusedField == .confirmPassword ? Color.green : Color.clear, lineWidth: 2)
                        )
                        
                        
                        // 密码匹配提示
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("密码不匹配")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        
                        // 错误信息
                        if let errorMessage = userManager.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        // 成功信息
                        if showSuccessMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("注册成功！请登录")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        // 注册按钮
                        Button(action: handleRegister) {
                            HStack {
                                if userManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                }
                                Text(userManager.isLoading ? "注册中..." : "立即注册")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(!canRegister)
                        .scaleEffect(canRegister ? 1.0 : 0.95)
                        .animation(.easeInOut(duration: 0.2), value: canRegister)
                    }
                    .frame(maxWidth: 400)
                    .offset(y: formOffset)
                    .opacity(formOpacity)
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            .navigationBarHidden(true)
            .onAppear {
                performAppearAnimation()
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var canRegister: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        !userManager.isLoading
    }
    
    
    // MARK: - 方法
    
    private func handleRegister() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAvatarUrl = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            await userManager.register(
                username: trimmedUsername,
                password: password,
                avatarUrl: trimmedAvatarUrl.isEmpty ? nil : trimmedAvatarUrl
            )
            
            // 注册成功后显示成功信息，延迟2秒后关闭
            if userManager.errorMessage == nil {
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        }
    }
    
    private func performAppearAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            formOffset = 0
            formOpacity = 1.0
        }
        
        // 自动聚焦到用户名输入框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            focusedField = .username
        }
    }
}

// MARK: - Preview
#Preview {
    LoginView()
        .environmentObject(UserManager.shared)
}

#Preview {
    RegisterView()
        .environmentObject(UserManager.shared)
}
