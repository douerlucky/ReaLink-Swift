// LocationManager.swift
import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isRequestingLocation = false
    @Published var lastLocationUpdate: Date?
    
    static let shared = LocationManager()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 10米变化才更新
        authorizationStatus = locationManager.authorizationStatus
        
        print("初始化位置管理器，当前权限状态: \(authorizationStatus.rawValue)")
    }
    
    // 请求位置权限
    func requestLocationPermission() {
        print("请求位置权限，当前状态: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "位置权限被拒绝。请在设置中开启位置服务以获取附近问题通知。"
            print("位置权限被拒绝")
        case .authorizedWhenInUse:
            print("已有位置权限，尝试获取位置")
            requestLocationOnce()
        @unknown default:
            locationError = "未知的位置权限状态"
        }
    }
    
    // 一次性获取位置
    func requestLocationOnce() {
        guard authorizationStatus == .authorizedWhenInUse else {
            locationError = "没有位置权限"
            print("请求位置失败：没有权限")
            return
        }
        
        guard !isRequestingLocation else {
            print("正在请求位置中，跳过重复请求")
            return
        }
        
        isRequestingLocation = true
        locationError = nil
        
        print("开始请求位置...")
        
        // 设置超时机制
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isRequestingLocation {
                self.isRequestingLocation = false
                self.locationError = "位置请求超时。请检查网络连接和WiFi信号。"
                print("位置请求超时")
            }
        }
        
        locationManager.requestLocation()
    }
    
    // 检查位置是否可用
    var hasValidLocation: Bool {
        guard let location = currentLocation else { return false }
        
        // 检查位置是否过期（超过10分钟）
        let isRecent = location.timestamp.timeIntervalSinceNow > -600
        
        // 检查精度是否可接受（小于1000米）
        let isAccurate = location.horizontalAccuracy > 0 && location.horizontalAccuracy < 1000
        
        return isRecent && isAccurate
    }
    
    // 获取位置状态描述
    var locationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未请求位置权限"
        case .denied:
            return "位置权限被拒绝"
        case .restricted:
            return "位置服务受限"
        case .authorizedWhenInUse:
            if hasValidLocation {
                return "位置可用"
            } else if isRequestingLocation {
                return "正在获取位置..."
            } else {
                return "位置不可用"
            }
        @unknown default:
            return "未知状态"
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isRequestingLocation = false
        
        guard let location = locations.last else {
            print("位置更新但没有有效位置数据")
            return
        }
        
        // 检查位置精度
        if location.horizontalAccuracy < 0 {
            print("位置精度无效: \(location.horizontalAccuracy)")
            locationError = "位置精度不可用"
            return
        }
        
        if location.horizontalAccuracy > 1000 {
            print("位置精度过低: \(location.horizontalAccuracy)米")
            locationError = "位置精度过低（\(Int(location.horizontalAccuracy))米），可能影响通知准确性"
        }
        
        currentLocation = location
        lastLocationUpdate = Date()
        locationError = nil
        
        print("位置更新成功: (\(location.coordinate.latitude), \(location.coordinate.longitude)), 精度: \(location.horizontalAccuracy)米")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequestingLocation = false
        
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                locationError = "无法确定位置。请确保WiFi连接正常。"
                print("位置未知错误")
            case .denied:
                locationError = "位置访问被拒绝"
                print("位置权限被拒绝")
            case .network:
                locationError = "网络错误，无法获取位置"
                print("位置服务网络错误")
            case .headingFailure:
                locationError = "方向服务不可用"
                print("方向服务错误")
            case .rangingUnavailable, .rangingFailure:
                locationError = "测距服务不可用"
                print("测距服务错误")
            default:
                locationError = "位置服务错误: \(clError.localizedDescription)"
                print("其他位置错误: \(clError)")
            }
        } else {
            locationError = "未知位置错误: \(error.localizedDescription)"
            print("未知位置错误: \(error)")
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("位置权限状态变更为: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .authorizedWhenInUse:
            print("获得位置权限，自动请求位置")
            requestLocationOnce()
        case .denied, .restricted:
            locationError = "位置权限被拒绝或受限"
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}


// 位置调试视图
struct LocationDebugView: View {
    @StateObject private var locationManager = LocationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("位置服务调试")
                .font(.title)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("权限状态: \(locationManager.authorizationStatus.rawValue)")
                Text("状态描述: \(locationManager.locationStatusDescription)")
                
                if let location = locationManager.currentLocation {
                    Text("纬度: \(location.coordinate.latitude, specifier: "%.6f")")
                    Text("经度: \(location.coordinate.longitude, specifier: "%.6f")")
                    Text("精度: \(location.horizontalAccuracy, specifier: "%.1f")米")
                    if let lastUpdate = locationManager.lastLocationUpdate {
                        Text("更新时间: \(lastUpdate.formatted())")
                    }
                } else {
                    Text("暂无位置数据")
                }
                
                if let error = locationManager.locationError {
                    Text("错误: \(error)")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            VStack(spacing: 12) {
                Button("请求位置权限") {
                    locationManager.requestLocationPermission()
                }
                .disabled(locationManager.authorizationStatus == .authorizedWhenInUse)
                
                Button("获取当前位置") {
                    locationManager.requestLocationOnce()
                }
                .disabled(locationManager.authorizationStatus != .authorizedWhenInUse || locationManager.isRequestingLocation)
                
                if locationManager.isRequestingLocation {
                    ProgressView("正在获取位置...")
                }
            }
        }
        .padding()
    }
}
