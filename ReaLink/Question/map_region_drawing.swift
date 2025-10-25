import SwiftUI
import MapKit

// MARK: - 绘制区域数据模型
struct DrawnRegion {
    let points: [CLLocationCoordinate2D]
    let boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)
    
    init(points: [CLLocationCoordinate2D]) {
        self.points = points
        
        // 计算边界框
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        
        for point in points {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        
        self.boundingBox = (minLat, maxLat, minLon, maxLon)
    }
    
    // 检查点是否在多边形内（射线法）
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard points.count >= 3 else { return false }
        
        var inside = false
        var j = points.count - 1
        
        for i in 0..<points.count {
            let xi = points[i].latitude
            let yi = points[i].longitude
            let xj = points[j].latitude
            let yj = points[j].longitude
            
            let intersect = ((yi > coordinate.longitude) != (yj > coordinate.longitude))
                && (coordinate.latitude < (xj - xi) * (coordinate.longitude - yi) / (yj - yi) + xi)
            
            if intersect {
                inside = !inside
            }
            
            j = i
        }
        
        return inside
    }
}

// MARK: - 增强的 MapView（支持区域绘制）
struct DrawableMapView: UIViewRepresentable {
    // 基础地图参数
    var mapItems: [MKMapItem]
    var defaultMapItem: MKMapItem?
    @Binding var regionSpan: Double
    @Binding var selectedMapItem: MKMapItem?
    
    // 绘制模式参数
    @Binding var isDrawingMode: Bool
    @Binding var drawnPoints: [CLLocationCoordinate2D]
    @Binding var isRegionClosed: Bool
    
    var markerColor: UIColor = .systemBlue
    var centerOffset: CGFloat = 0
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ view: MKMapView, context: Context) {
        // 更新地图标注
        updateAnnotations(view)
        
        // 更新绘制的多边形/折线
        updateDrawnOverlays(view, context: context)
        
        // 更新地图区域
        updateMapRegion(view)
    }
    
    private func updateAnnotations(_ view: MKMapView) {
        // 清除现有标注（保留用户位置）
        view.removeAnnotations(view.annotations.filter { !($0 is MKUserLocation) })
        
        // 添加地点标注
        for item in mapItems {
            let annotation = ReusableAnnotation()
            annotation.title = item.name
            annotation.coordinate = item.placemark.coordinate
            annotation.mapItem = item
            view.addAnnotation(annotation)
        }
        
        // 添加默认位置标注
        if let defaultMapItem = defaultMapItem {
            let annotation = ReusableAnnotation()
            annotation.title = defaultMapItem.name
            annotation.coordinate = defaultMapItem.placemark.coordinate
            annotation.mapItem = defaultMapItem
            view.addAnnotation(annotation)
        }
    }
    
    private func updateDrawnOverlays(_ view: MKMapView, context: Context) {
        // 移除旧的覆盖层
        view.removeOverlays(view.overlays)
        
        guard !drawnPoints.isEmpty else { return }
        
        if isRegionClosed && drawnPoints.count >= 3 {
            // 绘制闭合的多边形
            let polygon = MKPolygon(coordinates: drawnPoints, count: drawnPoints.count)
            view.addOverlay(polygon)
        } else if isDrawingMode {
            // 只在绘制模式下显示折线
            let polyline = MKPolyline(coordinates: drawnPoints, count: drawnPoints.count)
            view.addOverlay(polyline)
            
            // 如果有足够的点，绘制虚线回到起点
            if drawnPoints.count >= 2 {
                var closingLine = drawnPoints
                closingLine.append(drawnPoints[0])
                let dashedPolyline = MKPolyline(coordinates: closingLine, count: closingLine.count)
                view.addOverlay(dashedPolyline)
            }
        }
        
        // ✅ 修改：只在绘制模式下显示点标记，且缩小尺寸
        if isDrawingMode {
            for (index, point) in drawnPoints.enumerated() {
                let circle = MKCircle(center: point, radius: 5) // ✅ 从 20 改为 5 米
                circle.title = "\(index)"
                view.addOverlay(circle)
            }
        }
    }
    
    private func updateMapRegion(_ view: MKMapView) {
        var centerCoordinate: CLLocationCoordinate2D?
        
        if let firstItem = mapItems.first {
            centerCoordinate = firstItem.placemark.coordinate
        } else if let defaultMapItem = defaultMapItem {
            centerCoordinate = defaultMapItem.placemark.coordinate
        }
        
        if let center = centerCoordinate {
            var adjustedCenter = center
            if centerOffset != 0 {
                let offsetRatio = centerOffset / view.bounds.width
                let longitudeOffset = regionSpan * 0.000001 * offsetRatio
                adjustedCenter.longitude += longitudeOffset
            }
            
            let region = MKCoordinateRegion(
                center: adjustedCenter,
                latitudinalMeters: regionSpan,
                longitudinalMeters: regionSpan
            )
            view.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: DrawableMapView
        
        init(_ parent: DrawableMapView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isDrawingMode else { return }
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // 检查是否点击了起点附近（闭合多边形）
            if parent.drawnPoints.count >= 3 {
                let firstPoint = parent.drawnPoints[0]
                let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    .distance(from: CLLocation(latitude: firstPoint.latitude, longitude: firstPoint.longitude))
                
                // 如果距离起点小于100米，闭合多边形
                if distance < 100 {
                    DispatchQueue.main.async {
                        self.parent.isRegionClosed = true
                        self.parent.isDrawingMode = false  // ✅ 自动退出绘制模式
                        print("✅ 区域已闭合，点数：\(self.parent.drawnPoints.count)")
                    }
                    return
                }
            }
            
            // 添加新点
            DispatchQueue.main.async {
                self.parent.drawnPoints.append(coordinate)
                print("📍 添加点 \(self.parent.drawnPoints.count): (\(coordinate.latitude), \(coordinate.longitude))")
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.2)
                renderer.strokeColor = .systemOrange
                renderer.lineWidth = 3
                return renderer
            }
            
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemOrange
                renderer.lineWidth = 3
                
                // 如果是闭合线（回到起点的虚线）
                if polyline.pointCount > parent.drawnPoints.count {
                    renderer.lineDashPattern = [2, 5]
                    renderer.lineWidth = 2
                }
                
                return renderer
            }
            
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                
                // 起点用不同颜色
                if circle.title == "0" {
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.8)
                    renderer.strokeColor = .systemGreen
                } else {
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.8)
                    renderer.strokeColor = .systemOrange
                }
                renderer.lineWidth = 2
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "ReusablePin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                
                let size: CGFloat = 28
                let circleView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circleView.backgroundColor = .clear
                circleView.layer.cornerRadius = size / 2
                circleView.layer.borderColor = UIColor.white.cgColor
                circleView.layer.borderWidth = 3
                circleView.layer.backgroundColor = parent.markerColor.cgColor
                
                annotationView?.frame = CGRect(x: 0, y: 0, width: size, height: size)
                annotationView?.addSubview(circleView)
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}

// MARK: - 修改后的 QuestionView（集成绘制功能）
struct QuestionViewWithDrawing: View {
    // 原有状态
    @State private var selectedMapItem: MKMapItem?
    @State private var mapItems: [MKMapItem] = []
    @State private var defaultMapItem: MKMapItem?
    @State private var regionSpan: Double = 500
    @State private var enableGeoRange: Bool = false
    
    // 绘制相关状态
    @State private var isDrawingMode: Bool = false
    @State private var drawnPoints: [CLLocationCoordinate2D] = []
    @State private var isRegionClosed: Bool = false
    @State private var drawnRegion: DrawnRegion?
    
    var body: some View {
        ZStack {
            // 地图层
            DrawableMapView(
                mapItems: mapItems,
                defaultMapItem: defaultMapItem,
                regionSpan: $regionSpan,
                selectedMapItem: $selectedMapItem,
                isDrawingMode: $isDrawingMode,
                drawnPoints: $drawnPoints,
                isRegionClosed: $isRegionClosed,
                markerColor: .systemGreen,
                centerOffset: -5000
            )
            
            // 右下角绘制控制按钮
            if enableGeoRange {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        drawingControlButton
                            .padding(32)
                    }
                }
            }
            
            // 左上角信息提示
            if isDrawingMode {
                VStack {
                    drawingInfoPanel
                        .padding(32)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - 绘制控制按钮
    private var drawingControlButton: some View {
        VStack(spacing: 12) {
            if !isDrawingMode {
                // 开始绘制
                Button(action: startDrawing) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                        Text("开始绘制推送区域")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else if isRegionClosed {

            } else {
                // 绘制中
                VStack(spacing: 8) {
                    Button(action: cancelDrawing) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                            Text("取消绘制")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
    
    // MARK: - 绘制信息面板
    private var drawingInfoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("绘制推送区域")
                    .font(.headline)
            }
            
            if !isRegionClosed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• 点击地图添加区域顶点")
                    Text("• 至少需要3个点形成区域")
                    Text("• 点击起点附近（绿色）闭合区域")
                    Text("• 或点击\"完成绘制\"手动闭合")
                    
                    if drawnPoints.count > 0 {
                        Divider()
                        Text("已添加 \(drawnPoints.count) 个点")
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("区域已闭合")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    if let region = drawnRegion {
                        Divider()
                        Text("覆盖范围:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("纬度: \(String(format: "%.6f", region.boundingBox.minLat)) ~ \(String(format: "%.6f", region.boundingBox.maxLat))")
                            .font(.caption2)
                        Text("经度: \(String(format: "%.6f", region.boundingBox.minLon)) ~ \(String(format: "%.6f", region.boundingBox.maxLon))")
                            .font(.caption2)
                    }
                }
                .font(.caption)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
    
    // MARK: - 绘制控制方法
    private func startDrawing() {
        withAnimation {
            isDrawingMode = true
            drawnPoints = []
            isRegionClosed = false
            drawnRegion = nil
        }
        print("🎨 开始绘制区域")
    }
    
    private func cancelDrawing() {
        withAnimation {
            isDrawingMode = false
            drawnPoints = []
            isRegionClosed = false
            drawnRegion = nil
        }
        print("❌ 取消绘制")
    }
}

// MARK: - Preview
#Preview {
    QuestionViewWithDrawing()
}
