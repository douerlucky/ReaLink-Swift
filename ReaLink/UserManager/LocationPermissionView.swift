//
//  LocationPermissionView.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/9/22.
//

// 创建一个专门的位置权限请求视图
import SwiftUI
import CoreLocation

struct LocationPermissionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager.shared
    @State private var animationOffset: CGFloat = 100
    @State private var animationOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.green.opacity(0.1),
                    Color.orange.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // 位置图标
                VStack(spacing: 20) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: 12) {
                        Text("获取位置权限")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("ReaLink需要获取您的位置信息来：")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            PermissionReasonRow(
                                icon: "questionmark.bubble.fill",
                                text: "为您推荐附近的问题和回答"
                            )
                            PermissionReasonRow(
                                icon: "bell.fill",
                                text: "发送位置相关的智能通知"
                            )
                            PermissionReasonRow(
                                icon: "map.fill",
                                text: "在地图上显示问题的准确位置"
                            )
                        }
                        .padding(.top, 8)
                    }
                }
                .offset(y: animationOffset)
                .opacity(animationOpacity)
                
                // 按钮区域
                VStack(spacing: 16) {
                    Button(action: {
                        locationManager.requestLocationPermission()
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("允许位置访问")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(locationManager.authorizationStatus == .authorizedWhenInUse)
                    
                    Button("稍后设置") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .font(.headline)
                }
                .frame(maxWidth: 300)
                .opacity(animationOpacity)
                
                Spacer()
                
                // 隐私说明
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("隐私保护")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Text("您的位置信息仅用于提供个性化服务，不会被用于其他目的。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 40)
                .opacity(animationOpacity)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
        }
        .onAppear {
            performAppearAnimation()
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            if newStatus == .authorizedWhenInUse {
                // 权限获取成功，延迟关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
    
    private func performAppearAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
            animationOffset = 0
            animationOpacity = 1.0
        }
    }
}

struct PermissionReasonRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

#Preview {
    LocationPermissionView()
}
