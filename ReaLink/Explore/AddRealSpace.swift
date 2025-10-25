//
//  AddRealSpace.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/9/30.
//

import SwiftUI
import PhotosUI

struct AddRealSpace: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    
    let locationId: Int64
    let locationName: String
    let latitude: Double?    // ✅ 新增
    let longitude: Double?   // ✅ 新增
    let userID = UserManager.shared.getUserId()
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var imageData: Data?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("上传3D全景视图")
                    .font(.title3)
                    .fontWeight(.medium)
                
                Spacer()
                
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            // 主内容区域
            VStack(spacing: 24) {
                // 地点输入框（不可编辑）
                VStack(alignment: .leading, spacing: 8) {
                    Text("地点")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(locationName)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 24)
                
                // 全景图片选择区域
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    if let selectedImage = selectedImage {
                        selectedImage
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("添加全景图片")
                                    .font(.headline)
                                
                                Text("选择 2:1 宽高比的全景照片")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .padding(.horizontal, 24)
                .onChange(of: selectedPhoto) { oldValue, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            imageData = data
                            if let uiImage = UIImage(data: data) {
                                selectedImage = Image(uiImage: uiImage)
                            }
                        }
                    }
                }
                
                // 错误提示
                if let error = uploadError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // 上传按钮
                Button(action: {
                    Task {
                        await uploadPhoto()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isUploading ? "上传中..." : "上传")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(imageData == nil || isUploading)
                .frame(width: 200)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .alert("上传失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(uploadError ?? "未知错误")
        }
    }
    
    private func uploadPhoto() async {
          guard let imageData = imageData else { return }
          
          isUploading = true
          uploadError = nil
          
          do {
              if(userID == nil) {
                  return
              }
              
              // ✅ 修改：传递完整参数
              let success = try await NetworkManager.shared.upload3DPanorama(
                  locationId: locationId,
                  imageData: imageData,
                  userID: userID ?? -1,
                  latitude: latitude,      // ✅ 传递坐标
                  longitude: longitude,    // ✅ 传递坐标
                  locationName: locationName
              )
            
            if success {
                print("✅ 上传成功")
                await MainActor.run {
                    dismiss()
                }
            } else {
                await MainActor.run {
                    uploadError = "上传失败，请重试"
                    showError = true
                    isUploading = false
                }
            }
        } catch NetworkError.serverError(let message) {
            await MainActor.run {
                uploadError = message
                showError = true
                isUploading = false
            }
        } catch {
            await MainActor.run {
                uploadError = "网络错误：\(error.localizedDescription)"
                showError = true
                isUploading = false
            }
        }
    }
}

struct Upload3DPanoramaRequest: Codable {
    let locationId: Int64
    let imageData: String
    let userID: Int64
    let latitude: Double?      // ✅ 新增
    let longitude: Double?     // ✅ 新增
    let locationName: String   // ✅ 新增
}

struct Upload3DPanoramaResponse: Codable {
    let success: Bool
    let message: String
    let real3DViewId: Int64?
    let fileURL: String?
}

extension NetworkManager {
    func upload3DPanorama(
        locationId: Int64,
        imageData: Data,
        userID: Int64,
        latitude: Double?,      // ✅ 新增
        longitude: Double?,     // ✅ 新增
        locationName: String    // ✅ 新增
    ) async throws -> Bool{
        guard let url = URL(string: "\(baseURL)/realspace/upload-panorama") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Image = imageData.base64EncodedString()
        
        let requestBody = Upload3DPanoramaRequest(
            locationId: locationId,
            imageData: base64Image,
            userID: userID,
            latitude: latitude,      // ✅ 添加
            longitude: longitude,    // ✅ 添加
            locationName: locationName  // ✅ 添加
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("📤 上传全景图: locationId=\(locationId), 大小=\(imageData.count) bytes")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📤 上传响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    let errorResponse = try? JSONDecoder().decode(Upload3DPanoramaResponse.self, from: data)
                    throw NetworkError.serverError(errorResponse?.message ?? "HTTP \(httpResponse.statusCode)")
                }
            }
            
            let responseData = try JSONDecoder().decode(Upload3DPanoramaResponse.self, from: data)
            
            if responseData.success {
                print("✅ 全景图上传成功")
                return true
            } else {
                throw NetworkError.serverError(responseData.message)
            }
            
        } catch let error as DecodingError {
            print("❌ 解析上传响应错误: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ 上传全景图失败: \(error)")
            throw NetworkError.serverError(error.localizedDescription)
        }
    }
}

//#Preview {
//    AddRealSpace(locationId: 1, locationName: "测试地点")
//        .environmentObject(UserManager.shared)
//}
