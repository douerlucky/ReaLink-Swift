//
//  EditProfileModal.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/9/1.
//

import SwiftUI
import PhotosUI

struct EditProfileModal: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    
    // 编辑状态
    @State private var editedUsername: String = ""
    @State private var originalUsername: String = ""
    @State private var isEditingUsername = false
    @State private var usernameCheckTimer: Timer?
    @State private var isCheckingUsername = false
    @State private var usernameValidationMessage: String?
    @State private var isUsernameValid = false
    
    // 头像选择和上传
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isUploadingAvatar = false
    @State private var uploadProgress: Double = 0
    
    // UI状态
    @State private var showingSaveAlert = false
    @State private var showingDiscardAlert = false
    @State private var contentScale: CGFloat = 0.95
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
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
                
                VStack(spacing: 0) {
                    // 头部
                    headerView
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    
                    // 内容区域
                    ScrollView {
                        VStack(spacing: 32) {
                            // 头像区域
                            avatarSection
                            
                            // 用户信息区域
                            userInfoSection
                            
                            // 底部间距
                            Spacer()
                                .frame(height: 40)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                    }
                }
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
            .onAppear {
                setupInitialData()
                performAppearAnimation()
            }
            .alert("保存更改？", isPresented: $showingSaveAlert) {
                Button("取消", role: .cancel) { }
                Button("保存") {
                    saveChanges()
                }
            } message: {
                Text("确定要保存对个人资料的更改吗？")
            }
            .alert("放弃更改？", isPresented: $showingDiscardAlert) {
                Button("取消", role: .cancel) { }
                Button("放弃", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("您的更改将不会被保存")
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    // MARK: - 头部视图
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            // 关闭按钮
            Button(action: handleCloseButtonTap) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 标题
            Text("编辑资料")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            // 保存按钮
            Button(action: {
                showingSaveAlert = true
            }) {
                if userManager.isLoading || isUploadingAvatar {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("保存")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges || userManager.isLoading || isUploadingAvatar || !canSave)
            .frame(width: 60, height: 36)
            .background(
                hasChanges && canSave ? .blue.opacity(0.1) : .clear,
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
    }
    
    // MARK: - 头像区域
    
    @ViewBuilder
    private var avatarSection: some View {
        VStack(spacing: 20) {
            // 头像显示
            ZStack {
                // 头像图片
                Group {
                    if let selectedImage = selectedImage {
                        // 显示新选择的图片
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // 显示当前用户头像，添加id来强制刷新
                        AsyncImage(url: URL(string: userManager.currentUser?.avatarUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 120))
                                .foregroundColor(.secondary)
                        }
                        .id(userManager.currentUser?.avatarUrl ?? "default") // 强制刷新
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                
                // 上传进度指示器
                if isUploadingAvatar {
                    Circle()
                        .fill(.black.opacity(0.5))
                        .overlay {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text("\(Int(uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                }
            }
            
            // 头像按钮
            Button(action: {
                showingImagePicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 16, weight: .medium))
                    Text("更换头像")
                        .font(.headline)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isUploadingAvatar)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - 用户信息区域
    
    @ViewBuilder
    private var userInfoSection: some View {
        VStack(spacing: 24) {
            // 用户昵称
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("用户昵称")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isEditingUsername {
                        Button("完成") {
                            finishEditingUsername()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    } else {
                        Button("编辑") {
                            startEditingUsername()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                
                if isEditingUsername {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("输入用户昵称", text: $editedUsername)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onChange(of: editedUsername) { _, newValue in
                                    validateUsername(newValue)
                                }
                            
                            if isCheckingUsername {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if !editedUsername.isEmpty && editedUsername != originalUsername {
                                Image(systemName: isUsernameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isUsernameValid ? .green : .red)
                            }
                        }
                        
                        if let message = usernameValidationMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(isUsernameValid ? .green : .red)
                        }
                    }
                } else {
                    Text(editedUsername)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // 用户ID（只读）
            VStack(alignment: .leading, spacing: 8) {
                Text("用户ID")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("#\(userManager.currentUser?.id ?? 0)")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // 加入时间（只读）
            VStack(alignment: .leading, spacing: 8) {
                Text("加入时间")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(formatJoinDate(userManager.currentUser?.createdAt ?? ""))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // 错误信息显示
            if let errorMessage = userManager.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var hasChanges: Bool {
        let usernameChanged = editedUsername != originalUsername
        let avatarChanged = selectedImage != nil
        
        return usernameChanged || avatarChanged
    }
    
    private var canSave: Bool {
        if editedUsername != originalUsername && !isUsernameValid {
            return false
        }
        
        if editedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        
        return true
    }
    
    // MARK: - 方法
    
    private func setupInitialData() {
        guard let user = userManager.currentUser else { return }
        editedUsername = user.username
        originalUsername = user.username
        isUsernameValid = true
    }
    
    private func performAppearAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            contentScale = 1.0
            contentOpacity = 1.0
        }
    }
    
    private func handleCloseButtonTap() {
        if hasChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    private func startEditingUsername() {
        isEditingUsername = true
        isUsernameValid = true
        usernameValidationMessage = nil
    }
    
    private func finishEditingUsername() {
        isEditingUsername = false
        
        // 如果用户名为空，恢复原用户名
        if editedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editedUsername = originalUsername
        }
    }
    
    private func validateUsername(_ username: String) {
        // 取消之前的定时器
        usernameCheckTimer?.invalidate()
        
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 基本验证
        if trimmedUsername.isEmpty {
            usernameValidationMessage = "用户名不能为空"
            isUsernameValid = false
            return
        }
        
        if trimmedUsername.count < 2 {
            usernameValidationMessage = "用户名至少需要2个字符"
            isUsernameValid = false
            return
        }
        
        if trimmedUsername.count > 50 {
            usernameValidationMessage = "用户名不能超过50个字符"
            isUsernameValid = false
            return
        }
        
        // 如果和原用户名相同，直接通过
        if trimmedUsername == originalUsername {
            usernameValidationMessage = nil
            isUsernameValid = true
            return
        }
        
        // 延迟检查用户名可用性
        usernameCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task {
                await checkUsernameAvailability(trimmedUsername)
            }
        }
    }
    
    @MainActor
    private func checkUsernameAvailability(_ username: String) async {
        isCheckingUsername = true
        
        do {
            let response = try await NetworkManager.shared.checkUsernameAvailability(
                username: username,
                currentUserId: userManager.currentUser?.id
            )
            
            if response.success {
                isUsernameValid = response.available
                usernameValidationMessage = response.available ? "用户名可用" : "用户名已被使用"
            } else {
                isUsernameValid = false
                usernameValidationMessage = response.message ?? "检查用户名时发生错误"
            }
        } catch {
            isUsernameValid = false
            usernameValidationMessage = "网络错误，无法验证用户名"
        }
        
        isCheckingUsername = false
    }
    
    private func saveChanges() {
        Task {
            // 如果有选择新头像，先上传头像
            if let selectedImage = selectedImage {
                await uploadAvatar(selectedImage)
            }
            
            // 如果用户名有变化，更新用户信息
            if editedUsername != originalUsername {
                await updateUserProfile()
            }
            
            if userManager.errorMessage == nil {
                // 保存成功，关闭modal
                dismiss()
            }
        }
    }
    
    // 修复上传头像的方法
    @MainActor
    private func uploadAvatar(_ image: UIImage) async {
        guard let userId = userManager.currentUser?.id else { return }
        
        isUploadingAvatar = true
        uploadProgress = 0
        
        // 模拟上传进度
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if uploadProgress < 0.9 {
                uploadProgress += 0.1
            } else {
                timer.invalidate()
            }
        }
        
        do {
            let response = try await NetworkManager.shared.uploadAvatar(image: image, userId: userId)
            
            progressTimer.invalidate()
            uploadProgress = 1.0
            
            if response.success, let updatedUser = response.user {
                // 更新用户信息
                userManager.updateUser(updatedUser)
                
                // 清除选择的图片，强制显示新头像
                selectedImage = nil
                
                // 添加一个小延迟确保UI更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // 可以在这里添加成功提示
                }
                
                print("✅ 头像上传成功，新URL: \(updatedUser.avatarUrl ?? "无")")
            } else {
                userManager.errorMessage = response.message ?? "头像上传失败"
            }
        } catch {
            progressTimer.invalidate()
            userManager.errorMessage = "头像上传失败: \(error.localizedDescription)"
            print("❌ 头像上传错误: \(error)")
        }
        
        isUploadingAvatar = false
    }
    
    @MainActor
    private func updateUserProfile() async {
        guard let userId = userManager.currentUser?.id else { return }
        
        do {
            let response = try await NetworkManager.shared.updateUserProfile(
                userId: userId,
                username: editedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            if response.success, let updatedUser = response.user {
                userManager.updateUser(updatedUser)
                originalUsername = editedUsername
            } else {
                userManager.errorMessage = response.message ?? "更新用户信息失败"
            }
        } catch {
            userManager.errorMessage = "更新用户信息失败: \(error.localizedDescription)"
        }
    }
    
    private func formatJoinDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        
        guard let date = formatter.date(from: dateString) else {
            let alternativeFormatter = DateFormatter()
            alternativeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            alternativeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let parsedDate = alternativeFormatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "yyyy年MM月dd日"
                displayFormatter.timeZone = TimeZone.current
                return displayFormatter.string(from: parsedDate)
            }
            
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy年MM月dd日"
        displayFormatter.timeZone = TimeZone.current
        return displayFormatter.string(from: date)
    }
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    let userManager = UserManager.shared
    let testUser = User(
        id: 1,
        username: "测试用户",
        avatarUrl: "https://example.com/avatar.jpg",
        createdAt: "2025-01-15T10:30:00Z",
        updatedAt: "2025-01-15T10:30:00Z"
    )
    userManager.setUser(testUser)
    
    return EditProfileModal()
        .environmentObject(userManager)
}
