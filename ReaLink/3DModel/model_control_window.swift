//
//  ModelControlWindow.swift
//  ReaLink
//
//  Created by Assistant on 2025/8/20.
//

import SwiftUI

struct ModelControlWindow: View {
    @StateObject private var modelManager = ModelManager.shared
    @Environment(\.dismissWindow) private var dismissWindow
    
    // 云端功能状态
    @State private var isUploadingToCloud = false
    @State private var isDownloadingFromCloud = false
    @State private var cloudOperationStatus = ""
    @State private var hasCloudModels = false
    
    // 位置/问题/答案ID输入
    @State private var inputLocationId: String = "1"
    @State private var inputQuestionId: String = "1"
    @State private var inputAnswerId: String = "1"
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                Label("3D模型控制", systemImage: "cube.fill")
                    .font(.headline)
                Spacer()
                Button(action: {
                    dismissWindow(id: "ModelControlWindow")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)
            
            // 模型测试开关
            Toggle(isOn: $modelManager.isModelTestingEnabled) {
                Label("启用3D模型测试", systemImage: modelManager.isModelTestingEnabled ? "cube.fill" : "cube")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            
            // 测试状态指示
            if modelManager.isModelTestingEnabled {
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                        Text("3D模型测试已启用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("操作方法:")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 点击按钮放置模型")
                        Text("• 空间点击也可放置模型")
                        Text("• 双指捏合缩放模型大小")
                        Text("• 使用清空按钮删除所有模型")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
            
            // 模型属性设置区域
            if modelManager.isModelTestingEnabled {
                // 立方体颜色选择
                VStack(alignment: .leading, spacing: 12) {
                    Text("立方体颜色")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    
                    // 自定义颜色选择器
                    ColorPicker("自定义颜色", selection: $modelManager.cubeColor)
                        .padding(.top, 5)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                
                // 立方体大小设置
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("立方体大小")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f cm", modelManager.cubeSize * 100))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    HStack(spacing: 15) {
                        Image(systemName: "cube")
                            .font(.caption)
                        Slider(value: $modelManager.cubeSize, in: 0.05...0.5)
                        Image(systemName: "cube.fill")
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                
                // 透明度设置
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("透明度")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", modelManager.modelOpacity * 100))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Slider(value: $modelManager.modelOpacity, in: 0.1...1.0)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                
                // 云端存储功能区域
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Label("云端存储", systemImage: "icloud")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if hasCloudModels {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    // 位置/问题/答案ID输入
                    VStack(spacing: 8) {
                        HStack {
                            Text("位置ID:")
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            TextField("位置ID", text: $inputLocationId)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .keyboardType(.numberPad)
                        }
                        
                        HStack {
                            Text("问题ID:")
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            TextField("问题ID", text: $inputQuestionId)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .keyboardType(.numberPad)
                        }
                        
                        HStack {
                            Text("答案ID:")
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            TextField("答案ID", text: $inputAnswerId)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .keyboardType(.numberPad)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // 云端操作按钮
                    HStack(spacing: 12) {
                        // 保存到云端按钮
                        Button(action: {
                            saveModelsToCloud()
                        }) {
                            HStack {
                                if isUploadingToCloud {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "icloud.and.arrow.up")
                                }
                                Text("保存到云端")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUploadingToCloud || isDownloadingFromCloud || !modelManager.isModelTestingEnabled)
                        
                        // 从云端加载按钮
                        Button(action: {
                            loadModelsFromCloud()
                        }) {
                            HStack {
                                if isDownloadingFromCloud {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "icloud.and.arrow.down")
                                }
                                Text("从云端加载")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUploadingToCloud || isDownloadingFromCloud || !modelManager.isModelTestingEnabled)
                    }
                    
                    // 操作状态显示
                    if !cloudOperationStatus.isEmpty {
                        Text(cloudOperationStatus)
                            .font(.caption2)
                            .foregroundColor(cloudOperationStatus.contains("成功") ? .green :
                                           cloudOperationStatus.contains("失败") ? .red : .blue)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
            
            Spacer()
            
            // 底部按钮
            if modelManager.isModelTestingEnabled {
                VStack(spacing: 15) {
                    // 添加模型按钮
                    Button(action: {
                        addCube()
                    }) {
                        Label("添加立方体", systemImage: "plus.square.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    // 控制按钮行
                    HStack(spacing: 15) {
                        Button(action: {
                            modelManager.reset()
                        }) {
                            Label("重置", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            clearAllModels()
                        }) {
                            Label("清空所有", systemImage: "trash.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }
        }
        .padding(25)
        .frame(width: 400)
        .background(.regularMaterial)
        .onAppear {
            checkCloudModelsExists()
            setupCloudOperationResultListener()
        }
    }
    
    // MARK: - 云端功能实现
    
    /// 检查云端模型是否存在
    private func checkCloudModelsExists() {
        Task {
            let locationId = Int64(inputLocationId) ?? 1
            let questionId = Int64(inputQuestionId) ?? 1
            let answerId = Int64(inputAnswerId) ?? 1
            
            print("检查云端模型存在性: locationId=\(locationId), questionId=\(questionId), answerId=\(answerId)")
            
            let userInfo: [String: Any] = [
                "action": "checkCloudModels",
                "locationId": locationId,
                "questionId": questionId,
                "answerId": answerId
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudModelOperation"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    /// 保存模型到云端
    private func saveModelsToCloud() {
        isUploadingToCloud = true
        cloudOperationStatus = "正在保存到云端..."
        
        print("开始保存模型到云端")
        
        Task {
            let locationId = Int64(inputLocationId) ?? 1
            let questionId = Int64(inputQuestionId) ?? 1
            let answerId = Int64(inputAnswerId) ?? 1
            
            print("保存参数: locationId=\(locationId), questionId=\(questionId), answerId=\(answerId)")
            
            let userInfo: [String: Any] = [
                "action": "saveModelsToCloud",
                "locationId": locationId,
                "questionId": questionId,
                "answerId": answerId
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudModelOperation"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    /// 从云端加载模型
    private func loadModelsFromCloud() {
        isDownloadingFromCloud = true
        cloudOperationStatus = "正在从云端加载..."
        
        print("开始从云端加载模型")
        
        Task {
            let locationId = Int64(inputLocationId) ?? 1
            let questionId = Int64(inputQuestionId) ?? 1
            let answerId = Int64(inputAnswerId) ?? 1
            
            print("加载参数: locationId=\(locationId), questionId=\(questionId), answerId=\(answerId)")
            
            let userInfo: [String: Any] = [
                "action": "loadModelsFromCloud",
                "locationId": locationId,
                "questionId": questionId,
                "answerId": answerId
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudModelOperation"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    /// 监听云端操作结果
    private func setupCloudOperationResultListener() {
        // 监听操作结果通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudModelOperationResult"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let success = userInfo["success"] as? Bool,
               let message = userInfo["message"] as? String {
                
                // 更新UI状态
                isUploadingToCloud = false
                isDownloadingFromCloud = false
                cloudOperationStatus = message
                
                print("云端模型操作结果: \(success ? "成功" : "失败") - \(message)")
                
                // 3秒后清除状态信息
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    cloudOperationStatus = ""
                }
            }
        }
        
        // 监听检查结果通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudModelsExistsResult"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let exists = userInfo["exists"] as? Bool {
                hasCloudModels = exists
                print("云端模型存在性: \(exists)")
            }
        }
    }
    
    // MARK: - 功能方法
    private func addCube() {
        // 通过通知中心发送添加立方体信号
        NotificationCenter.default.post(name: NSNotification.Name("AddCube"), object: nil)
        print("🧊 发送添加立方体指令")
    }
    
    private func clearAllModels() {
        // 通过通知中心发送清空所有模型信号
        NotificationCenter.default.post(name: NSNotification.Name("ClearAllModels"), object: nil)
        print("🧊 发送清空所有模型指令")
    }
}

#Preview(windowStyle: .automatic) {
    ModelControlWindow()
}
