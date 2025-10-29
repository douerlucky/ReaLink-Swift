import CoreLocation
import Foundation
import MapKit
import SwiftUI

// MARK: - 增强的地图项模型

struct MapItem: Identifiable
{
    let id = UUID()
    let mapItem: MKMapItem
    let hasQuestions: Bool
    let questionCount: Int
    let isAnimated: Bool

    var coordinate: CLLocationCoordinate2D
    {
        mapItem.placemark.coordinate
    }

    var name: String?
    {
        mapItem.name
    }
}

// MARK: - 测试数据

let user1 = user_1
let user2 = user_2
let user3 = user_3

let location1 = hzau_musuem
let location2 = wutongSteet
let locations = [location1, location2]

let question1 = Question_1
let question2 = Question_2
let question3 = Question_3

let reality1 = hzau_musuem_3D
let reality2 = wutongStreet_3D
let realities = [reality1, reality2]

// MARK: - 主视图

struct ExploreView: View
{
    @StateObject private var networkManager = NetworkManager()
    @StateObject private var locationManager = LocationManager.shared

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @EnvironmentObject var vrManager: VRSessionManager
    @EnvironmentObject var userManager: UserManager // ✅ 添加这一行

    @State private var searchQuery = ""
    @State private var enhancedMapItems: [MapItem] = []
    @State private var regionSpan: Double = 500
    @State private var isLoading = false
    @State private var isManualSearch = false

    @State private var selectedMapItem: MKMapItem?
    @State private var showLocationDetail = false
    @State private var selectedQuestion: Question?
    @State private var showQuestionDetail = false

    @State private var currentMapCenter: CLLocationCoordinate2D?
    @State private var currentMapSpan: MKCoordinateSpan?
    @State private var autoSearchTask: Task<Void, Never>?
    @State private var lastSearchCenter: CLLocationCoordinate2D?
    @State private var lastSearchSpan: MKCoordinateSpan?

    @State private var isAnnotationSelected = false
    @State private var suppressAutoSearch = false
    @State private var mapUpdateTrigger = UUID()
    @State private var targetMapCenter: CLLocationCoordinate2D?
    @State private var shouldUpdateMapCenter = false
    @State private var shouldDeselectAnnotation = false

    @State private var locationToUpload: Location?

    // 控制是否隐藏其他标记
    @State private var hideOtherMarkers = false

    // 🔧 添加防护标志
    @State private var hasInitializedLocation = false
    @State private var isViewActive = false

    // 默认位置（作为后备）
    private let defaultLocation = CLLocationCoordinate2D(
        latitude: 30.4747,
        longitude: 114.3489
    )

    private var mapItemsWithColors: [(MKMapItem, UIColor)]
    {
        enhancedMapItems.map
        { enhanced in
            let color = enhanced.hasQuestions ? MapMarkerColor.orange.uiColor : UIColor.gray
            return (enhanced.mapItem, color)
        }
    }

    // 在 ExploreView 中修改这个方法
    private func handle3DViewRequest(for location: Location) async
    {
        do
        {
            await MainActor.run
            {
                vrManager.setLoadingState(true)
            }

            print("请求3D视图数据，位置ID: \(location.id)")

            let view3DData = try await NetworkManager.shared.fetch3DView(for: location.id)

            await MainActor.run
            {
                vrManager.updateLocationInfoWithURL(
                    title: location.name, locationId: location.id, // ✅ 直接使用 location.name
                    panoramaImageURL: view3DData.fileURL
                )

                print("获取3D视图数据: \(view3DData.name)")
                print("全景图URL: \(view3DData.fileURL)")
            }

            await openImmersiveSpace(id: "Realistic3DScene")
            await MainActor.run
            {
                dismissWindow(id: "MainWindow")
            }
        }
        catch NetworkError.no3DView
        {
            await MainActor.run
            {
                vrManager.setLoadingState(false)
                print("该位置暂无3D视图数据")
            }
        }
        catch
        {
            await MainActor.run
            {
                vrManager.setLoadingState(false)
                print("获取3D视图失败: \(error.localizedDescription)")

                // ✅ 修复：使用 realities 数组查找本地备份
                if let view3D = realities.first(where: { $0.locationID == location.id })
                {
                    vrManager.updateLocationInfo(
                        title: location.name, locationId: location.id, // ✅ 使用 location.name
                        panoramaImage: view3D.filename
                    )

                    Task
                    {
                        await openImmersiveSpace(id: "Realistic3DScene")
                        await MainActor.run
                        {
                            dismissWindow(id: "MainWindow")
                        }
                    }
                }
            }
        }
    }

    var body: some View
    {
        ZStack
        {
            VStack
            {
                ExploreMapView(
                    mapItemsWithColors: mapItemsWithColors,
                    targetCenter: shouldUpdateMapCenter ? targetMapCenter : nil,
                    regionSpan: $regionSpan,
                    selectedMapItem: $selectedMapItem,
                    updateTrigger: mapUpdateTrigger,
                    enableSelection: !isLoading,
                    centerOffset: 300,
                    showPopup: $showLocationDetail,
                    hideOtherMarkers: hideOtherMarkers, // ✅ 传递状态
                    onAnnotationSelected: { mapItem in
                        handleAnnotationSelected(mapItem)
                    },
                    onRegionChange: { center, span in
                        handleMapRegionChange(center: center, span: span)
                    },
                    onMapCenterUpdated: {
                        shouldUpdateMapCenter = false
                        targetMapCenter = nil
                    },
                    shouldDeselectAnnotation: shouldDeselectAnnotation
                )
                .onAppear
                {
                    // 🔧 只在首次加载时获取位置
                    if !hasInitializedLocation
                    {
                        print("📍 首次加载，开始获取用户位置")
                        loadUserLocation()
                        hasInitializedLocation = true
                    }
                    else
                    {
                        print("📍 已有位置数据，跳过重复加载")
                    }
                    isViewActive = true
                }
                .onDisappear
                {
                    isViewActive = false
                    // 取消自动搜索任务
                    autoSearchTask?.cancel()
                }
                .overlay(
                    VStack
                    {
                        ExploreSearchBar(
                            searchText: $searchQuery,
                            isLoading: $isLoading,
                            onLocationSelected: { mapItem in
                                focusOnMapItem(mapItem)
                                performManualSearch()
                            },
                            onManualSearch: {
                                performManualSearch()
                            }
                        )
                        .padding()

                        // 显示定位状态或错误
                        if locationManager.isRequestingLocation
                        {
                            HStack
                            {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("正在获取位置...")
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        else if let error = locationManager.locationError
                        {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }

                        Spacer()
                    }
                )
            }

            if showLocationDetail, let mapItem = selectedMapItem
            {
                LocationDetailSidebar(
                    mapItem: mapItem,
                    isPresented: $showLocationDetail,
                    onSelectQuestion: { question in
                        selectedQuestion = question
                        showQuestionDetail = true
                    },
                    onClose: {
                        closeLocationDetail()
                    }
                )
                .zIndex(10)
            }

            if selectedMapItem != nil
            {
                VStack
                {
                    Spacer()
                    HStack
                    {
                        ThreeDViewThumbnailButton(
                            selectedMapItem: selectedMapItem,
                            onEnter3DView: { location in
                                Task
                                {
                                    await handle3DViewRequest(for: location)
                                }
                            },
                            onAddPanorama: { location in
                                print("🎬 触发添加全景图: \(location.name)")
                                locationToUpload = location // ✅ 改成这个
                            }
                        )
                        Spacer()
                    }
                    .padding(20)
                }
                .zIndex(15)
            }

            if showQuestionDetail, let question = selectedQuestion
            {
                QuestionDetailModal(
                    question: question,
                    isPresented: $showQuestionDetail,
                    onClose: {
                        showQuestionDetail = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)
                        {
                            selectedQuestion = nil
                        }
                    }
                )
                .zIndex(20)
            }
        }
        .background(.regularMaterial)
        .cornerRadius(32)
        .sheet(item: $locationToUpload)
        { location in
            AddRealSpace(
                locationId: location.id,
                locationName: location.name,
                latitude: location.latitude, // ✅ 传递坐标
                longitude: location.longitude // ✅ 传递坐标
            )
            .environmentObject(userManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onDisappear
        {
            autoSearchTask?.cancel()
        }
    }

    // MARK: - 加载用户位置

    private func loadUserLocation()
    {
        // 🔧 如果正在加载或已完成加载，跳过
        guard !hasInitializedLocation
        else
        {
            print("⚠️ 位置已初始化，跳过重复加载")
            return
        }

        print("🗺️ 开始获取用户位置用于探索...")
        locationManager.requestLocationPermission()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5)
        {
            // 🔧 再次检查是否仍需要更新
            guard self.isViewActive
            else
            {
                print("⚠️ 视图已不活跃，取消位置更新")
                return
            }

            if let location = locationManager.currentLocation
            {
                print("✅ 使用用户位置: \(location.coordinate)")
                self.targetMapCenter = location.coordinate
                self.shouldUpdateMapCenter = true
                self.mapUpdateTrigger = UUID()
            }
            else
            {
                print("⚠️ 无法获取用户位置，使用默认位置")
                self.targetMapCenter = self.defaultLocation
                self.shouldUpdateMapCenter = true
                self.mapUpdateTrigger = UUID()
            }
        }
    }

    // MARK: - 标记点选中处理

    private func handleAnnotationSelected(_ mapItem: MKMapItem)
    {
        print("处理标记点选中: \(mapItem.name ?? "未知位置")")
        isAnnotationSelected = true
        suppressAutoSearch = true
        autoSearchTask?.cancel()

        // ✅ 设置隐藏其他标记
        hideOtherMarkers = true

        print("自动搜索已暂停,标记点选中状态已设置")
    }

    // MARK: - 关闭位置详情

    private func closeLocationDetail()
    {
        print("开始关闭位置详情...")
        showLocationDetail = false
        shouldDeselectAnnotation = true
        mapUpdateTrigger = UUID()

        // ✅ 恢复显示其他标记
        hideOtherMarkers = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
        {
            self.shouldDeselectAnnotation = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)
        {
            print("重置选中状态...")
            self.selectedMapItem = nil
            self.isAnnotationSelected = false
            self.suppressAutoSearch = false
            print("状态已重置,地图交互恢复正常")
        }
    }

    // MARK: - 地图区域变化处理

    private func handleMapRegionChange(center: CLLocationCoordinate2D, span: MKCoordinateSpan)
    {
        currentMapCenter = center
        currentMapSpan = span

        if !isManualSearch && !suppressAutoSearch && !isLoading
        {
            autoSearchTask?.cancel()
            autoSearchTask = Task
            {
                try? await Task.sleep(nanoseconds: 1000000000)
                if !Task.isCancelled && !isLoading && !suppressAutoSearch
                {
                    await performAutoSearch(center: center, span: span)
                }
            }
        }
    }

    // MARK: - 自动搜索功能

    private func performAutoSearch(center: CLLocationCoordinate2D, span: MKCoordinateSpan) async
    {
        if let lastCenter = lastSearchCenter, let lastSpan = lastSearchSpan
        {
            let centerDistance = sqrt(pow(lastCenter.latitude - center.latitude, 2) +
                pow(lastCenter.longitude - center.longitude, 2))
            let spanDifference = abs(lastSpan.latitudeDelta - span.latitudeDelta) +
                abs(lastSpan.longitudeDelta - span.longitudeDelta)

            if centerDistance < 0.001 && spanDifference < 0.001
            {
                print("跳过重复搜索")
                return
            }
        }

        let radiusMeters = max(span.latitudeDelta, span.longitudeDelta) * 111000 / 2
        let clampedRadius = min(max(radiusMeters, 100), 5000)

        do
        {
            await MainActor.run { isLoading = true }

            let response = try await NetworkManager.shared.searchNearbyQuestions(
                centerLatitude: center.latitude,
                centerLongitude: center.longitude,
                radiusMeters: clampedRadius
            )

            if Task.isCancelled { return }

            await MainActor.run
            {
                lastSearchCenter = center
                lastSearchSpan = span

                let newMapItems = response.locationsWithQuestions.map
                { location in
                    let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    ))
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = location.name

                    return MapItem(
                        mapItem: mapItem,
                        hasQuestions: true,
                        questionCount: location.questionCount,
                        isAnimated: true
                    )
                }

                enhancedMapItems = newMapItems
                isLoading = false
                print("自动搜索完成，找到 \(newMapItems.count) 个有问题的地点")
            }
        }
        catch
        {
            print("自动搜索失败: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - 手动搜索功能

    private func performManualSearch()
    {
        guard !searchQuery.isEmpty else { return }

        print("开始手动搜索: \(searchQuery)")
        isManualSearch = true
        isLoading = true
        suppressAutoSearch = true
        autoSearchTask?.cancel()

        searchLocation(query: searchQuery)
        { items in
            Task
            {
                await checkLocationsAndUpdate(items)
                DispatchQueue.main.async
                {
                    self.isLoading = false
                    if let firstItem = items.first
                    {
                        self.focusOnMapItem(firstItem)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)
                    {
                        self.isManualSearch = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
                        {
                            self.suppressAutoSearch = false
                            print("手动搜索完成，重新启用自动搜索")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 定位到指定地图项

    private func focusOnMapItem(_ mapItem: MKMapItem)
    {
        print("定位到: \(mapItem.name ?? "未知位置")")
        targetMapCenter = mapItem.placemark.coordinate
        regionSpan = 1000
        shouldUpdateMapCenter = true
        mapUpdateTrigger = UUID()
        print("目标坐标: \(mapItem.placemark.coordinate)")
    }

    // 搜索位置
    private func searchLocation(query: String, completion: @escaping ([MKMapItem]) -> Void)
    {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        search.start
        { response, error in
            guard error == nil
            else
            {
                print("搜索错误: \(error!.localizedDescription)")
                completion([])
                return
            }
            print("搜索到 \(response?.mapItems.count ?? 0) 个结果")
            completion(response?.mapItems ?? [])
        }
    }

    // 检查位置并更新地图
    private func checkLocationsAndUpdate(_ mapItems: [MKMapItem]) async
    {
        let coordinates = mapItems.map
        { item in
            LocationCoordinate(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude,
                name: item.name
            )
        }

        do
        {
            let response = try await NetworkManager.shared.checkLocationsForQuestions(coordinates: coordinates)

            DispatchQueue.main.async
            {
                self.enhancedMapItems = mapItems.compactMap
                { mapItem in
                    let coordinate = mapItem.placemark.coordinate
                    if let result = response.results.first(where: { result in
                        abs(result.latitude - coordinate.latitude) < 0.0001 &&
                            abs(result.longitude - coordinate.longitude) < 0.0001
                    })
                    {
                        return MapItem(
                            mapItem: mapItem,
                            hasQuestions: result.hasQuestions,
                            questionCount: 0,
                            isAnimated: false
                        )
                    }
                    else
                    {
                        return MapItem(
                            mapItem: mapItem,
                            hasQuestions: false,
                            questionCount: 0,
                            isAnimated: false
                        )
                    }
                }
            }
        }
        catch
        {
            print("网络请求失败: \(error)")
            DispatchQueue.main.async
            {
                self.enhancedMapItems = mapItems.map
                { mapItem in
                    MapItem(
                        mapItem: mapItem,
                        hasQuestions: false,
                        questionCount: 0,
                        isAnimated: false
                    )
                }
            }
        }
    }
}

// MARK: - 地图视图组件

struct ExploreMapView: UIViewRepresentable
{
    var mapItemsWithColors: [(MKMapItem, UIColor)]
    var targetCenter: CLLocationCoordinate2D?

    @Binding var regionSpan: Double
    @Binding var selectedMapItem: MKMapItem?

    var updateTrigger: UUID
    var enableSelection: Bool = true
    var centerOffset: CGFloat = 0
    var showPopup: Binding<Bool>? = nil
    var hideOtherMarkers: Bool = false // ✅ 新增参数
    var onAnnotationSelected: ((MKMapItem) -> Void)? = nil
    var onRegionChange: ((CLLocationCoordinate2D, MKCoordinateSpan) -> Void)? = nil
    var onMapCenterUpdated: (() -> Void)? = nil
    var shouldDeselectAnnotation: Bool = false

    func makeUIView(context: Context) -> MKMapView
    {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none

        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true

        mapView.pointOfInterestFilter = .includingAll

        if #available(iOS 16.0, *)
        {
            mapView.selectableMapFeatures = [.pointsOfInterest]
        }

        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context)
    {
        print("更新地图视图")

        // 处理取消选择标注
        if shouldDeselectAnnotation
        {
            let selectedAnnotations = view.selectedAnnotations
            for annotation in selectedAnnotations
            {
                if !(annotation is MKUserLocation)
                {
                    view.deselectAnnotation(annotation, animated: false)
                    print("取消标注选择: \(String(describing: annotation.title ?? "未知"))")
                }
            }
        }

        // 只在明确需要时更新目标中心点
        if let targetCenter = targetCenter
        {
            print("🗺️ 设置目标中心点: \(targetCenter)")
            let region = MKCoordinateRegion(
                center: targetCenter,
                latitudinalMeters: regionSpan,
                longitudinalMeters: regionSpan
            )
            view.setRegion(region, animated: true)

            DispatchQueue.main.async
            {
                self.onMapCenterUpdated?()
            }
        }

        // 获取当前已有的标注（除了用户位置）
        let existingAnnotations = view.annotations.filter { !($0 is MKUserLocation) }

        // 创建新的标注数据映射
        let newAnnotationsData = mapItemsWithColors.map
        { mapItem, color in
            (coordinate: mapItem.placemark.coordinate, name: mapItem.name, color: color, mapItem: mapItem)
        }

        // 检查是否需要添加/删除标注
        let needsUpdate = existingAnnotations.count != newAnnotationsData.count ||
            !existingAnnotations.allSatisfy
            { existing in
                newAnnotationsData.contains
                { new in
                    abs(existing.coordinate.latitude - new.coordinate.latitude) < 0.000001 &&
                        abs(existing.coordinate.longitude - new.coordinate.longitude) < 0.000001
                }
            }

        // ✅ 关键：只在标注数量或位置真正变化时才更新
        if needsUpdate
        {
            print("标注需要更新：移除 \(existingAnnotations.count) 个，添加 \(newAnnotationsData.count) 个")

            // 清除现有标注
            view.removeAnnotations(existingAnnotations)

            // 添加新的标注
            for (mapItem, color) in mapItemsWithColors
            {
                let annotation = ColoredAnnotation()
                annotation.title = mapItem.name
                annotation.coordinate = mapItem.placemark.coordinate
                annotation.mapItem = mapItem
                annotation.markerColor = color
                annotation.needsAnimation = true
                view.addAnnotation(annotation)
            }
        }

        // ✅ 核心逻辑：控制标注的可见性（不移除）
        if hideOtherMarkers
        {
            print("🎯 隐藏其他标记模式")
            // 遍历所有标注，隐藏非选中的
            for annotation in view.annotations
            {
                if annotation is MKUserLocation { continue }

                guard let coloredAnnotation = annotation as? ColoredAnnotation,
                      let annotationView = view.view(for: annotation)
                else
                {
                    continue
                }

                // 判断是否是选中的标记
                let isSelected = selectedMapItem.map
                { selected in
                    coloredAnnotation.mapItem?.name == selected.name &&
                        abs(coloredAnnotation.coordinate.latitude - selected.placemark.coordinate.latitude) < 0.000001 &&
                        abs(coloredAnnotation.coordinate.longitude - selected.placemark.coordinate.longitude) < 0.000001
                } ?? false

                // 使用动画隐藏/显示
                UIView.animate(withDuration: 0.3)
                {
                    annotationView.alpha = isSelected ? 1.0 : 0.0
                }
            }
        }
        else
        {
            print("🎯 显示所有标记")
            // 恢复所有标注的可见性
            for annotation in view.annotations
            {
                if annotation is MKUserLocation { continue }

                guard let annotationView = view.view(for: annotation)
                else
                {
                    continue
                }

                UIView.animate(withDuration: 0.3)
                {
                    annotationView.alpha = 1.0
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator
    {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate
    {
        var parent: ExploreMapView

        init(_ parent: ExploreMapView)
        {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
        {
            if annotation is MKUserLocation
            {
                return nil
            }
            if let featureAnnotation = annotation as? MKMapFeatureAnnotation
            {
                let identifier = "SystemPOI"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil
                {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true

                    // 关键：添加右侧附加按钮
                    let button = UIButton(type: .detailDisclosure)
                    button.setImage(UIImage(systemName: "plus.message.fill"), for: .normal)
                    button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
                    annotationView?.rightCalloutAccessoryView = button

                    // 可选：添加左侧图标
                    let imageView = UIImageView(image: UIImage(systemName: "mappin.circle.fill"))
                    imageView.tintColor = .systemBlue
                    imageView.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                    annotationView?.leftCalloutAccessoryView = imageView
                }
                else
                {
                    annotationView?.annotation = annotation
                }

                return annotationView
            }

            let identifier = "ColoredPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView

            if annotationView == nil
            {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                // 确保可以交互
                annotationView?.isUserInteractionEnabled = true

                // 添加点击手势识别器
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(annotationTapped(_:)))
                tapGesture.numberOfTapsRequired = 1
                tapGesture.numberOfTouchesRequired = 1
                // 设置手势优先级，不干扰地图的手势
                tapGesture.cancelsTouchesInView = false
                annotationView?.addGestureRecognizer(tapGesture)
            }
            else
            {
                annotationView?.annotation = annotation
            }

            // 获取颜色
            let coloredAnnotation = annotation as? ColoredAnnotation
            let color = coloredAnnotation?.markerColor ?? .gray
            let needsAnimation = coloredAnnotation?.needsAnimation ?? false

            // 清除之前的子视图
            annotationView?.subviews.forEach { $0.removeFromSuperview() }

            // 创建自定义标记
            let size: CGFloat = 28
            let circleView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            circleView.backgroundColor = .clear
            circleView.layer.cornerRadius = size / 2
            circleView.layer.borderColor = UIColor.white.cgColor
            circleView.layer.borderWidth = 3
            circleView.layer.backgroundColor = color.cgColor

            // 确保交互
            circleView.isUserInteractionEnabled = false // 让点击事件穿透到annotationView

            annotationView?.frame = CGRect(x: 0, y: 0, width: size, height: size)
            annotationView?.addSubview(circleView)

            // 添加动画效果
            if needsAnimation
            {
                circleView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                circleView.alpha = 0

                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseOut)
                {
                    circleView.transform = CGAffineTransform.identity
                    circleView.alpha = 1.0
                } completion: { _ in
                    // 动画完成后重置标志
                    coloredAnnotation?.needsAnimation = false
                }
            }

            print("创建/更新标注视图: \(annotation.title ?? "未知"), 可交互: \(annotationView?.isUserInteractionEnabled ?? false)")

            return annotationView
        }

        // 新增：处理标注点击手势
        @objc func annotationTapped(_ gesture: UITapGestureRecognizer)
        {
            guard let annotationView = gesture.view as? MKAnnotationView,
                  let coloredAnnotation = annotationView.annotation as? ColoredAnnotation,
                  let mapItem = coloredAnnotation.mapItem,
                  parent.enableSelection
            else
            {
                print("手势点击处理失败")
                return
            }

            print("手势识别到标注点击: \(mapItem.name ?? "未知位置")")

            // 检查当前是否已经选中了这个标注
            let isCurrentlySelected = parent.selectedMapItem?.name == mapItem.name
            print("当前标注是否已选中: \(isCurrentlySelected)")

            // 无论是否已选中都处理点击逻辑
            DispatchQueue.main.async
            {
                self.parent.selectedMapItem = mapItem
                self.parent.onAnnotationSelected?(mapItem)

                if let showPopupBinding = self.parent.showPopup
                {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
                    {
                        showPopupBinding.wrappedValue = true
                        print("通过手势显示侧边栏")
                    }
                }
            }

            // 执行地图移动（和didSelect中的逻辑一致）
            if let mapView = annotationView.superview as? MKMapView
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
                {
                    var targetCoordinate = coloredAnnotation.coordinate

                    if self.parent.centerOffset != 0
                    {
                        let offsetRatio = self.parent.centerOffset / mapView.bounds.width
                        let region = mapView.region
                        let longitudeOffset = region.span.longitudeDelta * offsetRatio
                        targetCoordinate.longitude += longitudeOffset
                    }

                    let currentSpan = mapView.region.span
                    let newSpan = MKCoordinateSpan(
                        latitudeDelta: min(currentSpan.latitudeDelta * 0.8, 0.01),
                        longitudeDelta: min(currentSpan.longitudeDelta * 0.8, 0.01)
                    )

                    let newRegion = MKCoordinateRegion(center: targetCoordinate, span: newSpan)
                    mapView.setRegion(newRegion, animated: true)
                    print("通过手势移动地图到目标位置")
                }
            }
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl)
        {
            guard let annotation = view.annotation else { return }

            print("点击了'在此提问'按钮")

            var mapItem: MKMapItem?

            // 处理系统 POI
            if let featureAnnotation = annotation as? MKMapFeatureAnnotation
            {
                let placemark = MKPlacemark(coordinate: featureAnnotation.coordinate)
                mapItem = MKMapItem(placemark: placemark)
                mapItem?.name = featureAnnotation.title

                print("系统 POI: \(featureAnnotation.title ?? "未知")")
            }
            // 处理自定义标记
            else if let coloredAnnotation = annotation as? ColoredAnnotation
            {
                mapItem = coloredAnnotation.mapItem

                print("自定义标记: \(coloredAnnotation.mapItem?.name ?? "未知")")
            }

            // 发送通知到 QuestionView
            if let mapItem = mapItem
            {
                DispatchQueue.main.async
                {
                    // 🔧 重要：先切换到 QuestionView 的 tab
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SwitchToQuestionTab"),
                        object: nil
                    )

                    // 然后发送位置信息
                    // 延迟一点，确保 tab 切换完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
                    {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToQuestionWithLocation"),
                            object: nil,
                            userInfo: ["mapItem": mapItem]
                        )
                    }
                }
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView)
        {
            print("地图标注被点击")

            guard let annotation = view.annotation else { return }

            // 🔧 修改：点击系统 POI 时，什么都不做，让系统自动显示 callout
            if let featureAnnotation = annotation as? MKMapFeatureAnnotation
            {
                print("✨ 点击了系统 POI: \(featureAnnotation.title ?? "未知地点")")
                // 不执行任何操作，让 MapKit 自动显示 callout
                // callout 上的按钮点击由 calloutAccessoryControlTapped 处理
                return
            }

            // 处理自定义 annotation（你原有的逻辑保持不变）
            guard parent.enableSelection,
                  let coloredAnnotation = annotation as? ColoredAnnotation,
                  let mapItem = coloredAnnotation.mapItem
            else
            {
                print("标记点选择失败 - enableSelection: \(parent.enableSelection)")
                return
            }

            print("标记点被选中: \(mapItem.name ?? "未知位置")")

            // 自定义标记仍然显示 sidebar
            DispatchQueue.main.async
            {
                print("更新选中状态...")
                self.parent.selectedMapItem = mapItem
                self.parent.onAnnotationSelected?(mapItem)

                if let showPopupBinding = self.parent.showPopup
                {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
                    {
                        showPopupBinding.wrappedValue = true
                        print("侧边栏已显示")
                    }
                }
            }

            guard parent.enableSelection,
                  let coloredAnnotation = view.annotation as? ColoredAnnotation,
                  let mapItem = coloredAnnotation.mapItem
            else
            {
                print("标记点选择失败 - enableSelection: \(parent.enableSelection)")
                return
            }

            print("标记点被选中: \(mapItem.name ?? "未知位置")")

            // 立即更新选中状态和回调
            DispatchQueue.main.async
            {
                print("更新选中状态...")
                self.parent.selectedMapItem = mapItem
                self.parent.onAnnotationSelected?(mapItem)

                // 显示侧边栏
                if let showPopupBinding = self.parent.showPopup
                {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
                    {
                        showPopupBinding.wrappedValue = true
                        print("侧边栏已显示")
                    }
                }
            }

            // 延迟执行地图移动，确保侧边栏先显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
            {
                // 计算目标坐标（考虑侧边栏偏移）
                var targetCoordinate = coloredAnnotation.coordinate

                if self.parent.centerOffset != 0
                {
                    let offsetRatio = self.parent.centerOffset / mapView.bounds.width
                    let region = mapView.region
                    let longitudeOffset = region.span.longitudeDelta * offsetRatio
                    targetCoordinate.longitude += longitudeOffset
                }

                // 适当放大并移动到目标位置
                let currentSpan = mapView.region.span
                let newSpan = MKCoordinateSpan(
                    latitudeDelta: min(currentSpan.latitudeDelta * 0.8, 0.01), // 放大但不要过度
                    longitudeDelta: min(currentSpan.longitudeDelta * 0.8, 0.01)
                )

                let newRegion = MKCoordinateRegion(center: targetCoordinate, span: newSpan)
                mapView.setRegion(newRegion, animated: true)
                print("地图已移动到目标位置")
            }
        }

        // 新增：处理标注取消选择
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView)
        {
            print("标注被取消选择")
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
        {
            // 只有在不是程序控制地图移动时才通知区域变化
            // 如果有 targetCenter，说明是程序控制的移动，不需要触发自动搜索
            if parent.targetCenter == nil
            {
                parent.onRegionChange?(mapView.region.center, mapView.region.span)
            }
        }
    }
}

// MARK: - 自定义带颜色的标注类

class ColoredAnnotation: NSObject, MKAnnotation
{
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var title: String?
    var subtitle: String?
    var mapItem: MKMapItem?
    var markerColor: UIColor = .gray
    var needsAnimation: Bool = false
}

// MARK: - 地点详情侧边栏

struct LocationDetailSidebar: View
{
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @EnvironmentObject var vrManager: VRSessionManager
    @EnvironmentObject var userManager: UserManager // ✅ 添加这一行

    let mapItem: MKMapItem
    @Binding var isPresented: Bool
    let onSelectQuestion: (Question) -> Void
    let onClose: () -> Void

    @State private var animationOffset: CGFloat = 400
    @State private var animationOpacity: Double = 0

    // 修复：新增状态管理真实数据
    @State private var questions: [Question] = []
    @State private var isLoadingQuestions = false
    @State private var loadingError: String?
    @State private var nearestLocationInfo: NearestLocationInfo?

    // 🔧 修复：新增3D视图存在性检查状态
    @State private var has3DView = false
    @State private var isChecking3DView = false
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false

    // 🆕 新增：AI总结相关状态
    @State private var locationSummary: String?
    @State private var isLoadingSummary = false
    @State private var summaryError: String?

    // 获取当前位置对应的数据
    var currentLocation: Location?
    {
        // 如果已经通过坐标匹配到了位置信息，转换为Location对象
        if let nearestInfo = nearestLocationInfo
        {
            return Location(
                id: nearestInfo.id,
                name: nearestInfo.name,
                longitude: nearestInfo.longitude,
                latitude: nearestInfo.latitude,
                questionCount: questions.count
            )
        }
        return nil
    }

    var view3D: Real3DViewSpace?
    {
        guard let location = currentLocation else { return nil }
        return realities.first { $0.locationID == location.id }
    }

    private func check3DViewExists(for location: Location) async
    {
        print("🎯 [LocationDetailSidebar] 开始检查3D视图: \(location.name)")

        await MainActor.run
        {
            isChecking3DView = true
        }

        do
        {
            let exists = try await NetworkManager.shared.checkLocationHas3DView(locationId: location.id)

            print("🎯 [LocationDetailSidebar] 检查结果: exists=\(exists)")

            await MainActor.run
            {
                self.has3DView = exists
                self.isChecking3DView = false
            }

            // ❌ 删除下面这整段 if exists 代码块
            // if exists {
            //     print("🎯 [ThreeDViewThumbnailButton] 准备调用 loadThumbnail")
            //     await loadThumbnail(for: location)
            //     print("🎯 [ThreeDViewThumbnailButton] loadThumbnail 调用完成")
            // }
        }
        catch
        {
            print("🎯 [LocationDetailSidebar] 检查异常: \(error)")
            await MainActor.run
            {
                self.has3DView = false
                self.isChecking3DView = false
            }
        }
    }

    // 加载问题数据
    private func loadQuestions()
    {
        isLoadingQuestions = true
        loadingError = nil

        let coordinate = mapItem.placemark.coordinate

        print("🔍 开始通过坐标加载问题: (\(coordinate.latitude), \(coordinate.longitude))")

        Task
        {
            do
            {
                // 调用新的后端API：根据坐标查找最近位置及其问题
                let response = try await NetworkManager.shared.findNearestLocationQuestions(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    maxDistance: 100 // 🔧 限制为100米范围内搜索
                )

                await MainActor.run
                {
                    self.isLoadingQuestions = false

                    if response.success, let nearestLocation = response.nearestLocation
                    {
                        // ✅ 找到了匹配的位置
                        self.nearestLocationInfo = nearestLocation
                        self.questions = response.questions
                        self.loadingError = nil

                        print("✅ 通过坐标找到位置: \(nearestLocation.name), \(response.questions.count)个问题")

                        // 🔧 修复：找到位置后立即检查3D视图存在性
                        Task
                        {
                            if let location = self.currentLocation
                            {
                                await self.check3DViewExists(for: location)
                            }
                        }
                    }
                    else
                    {
                        // ❌ 没有找到匹配的位置（距离超过100米）
                        self.nearestLocationInfo = nil
                        self.questions = []
                        self.loadingError = nil // 🔧 不设为错误，而是正常的空状态
                        self.has3DView = false

                        print("ℹ️ 在100米范围内未找到相关位置: \(response.message ?? "未知原因")")
                    }
                }
            }
            catch NetworkError.decodingError
            {
                await MainActor.run
                {
                    self.isLoadingQuestions = false
                    self.loadingError = nil // 🔧 解析错误也当作空状态处理
                    self.questions = []
                    self.nearestLocationInfo = nil
                    self.has3DView = false
                    print("⚠️ 数据解析问题，显示为空状态")
                }
            }
            catch let NetworkError.serverError(message)
            {
                await MainActor.run
                {
                    self.isLoadingQuestions = false

                    // 🔧 区分真正的服务器错误和"未找到"响应
                    if message.contains("未找到") || message.contains("范围内")
                    {
                        // 这是正常的"未找到"响应，不是错误
                        self.loadingError = nil
                        self.questions = []
                        self.nearestLocationInfo = nil
                        self.has3DView = false
                        print("ℹ️ 正常的未找到响应: \(message)")
                    }
                    else
                    {
                        // 这是真正的服务器错误
                        self.loadingError = "服务器错误: \(message)"
                        self.questions = []
                        self.nearestLocationInfo = nil
                        self.has3DView = false
                        print("❌ 服务器错误: \(message)")
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoadingQuestions = false
                    self.loadingError = "网络连接问题，请检查网络后重试"
                    self.questions = []
                    self.nearestLocationInfo = nil
                    self.has3DView = false
                    print("❌ 网络错误: \(error)")
                }
            }
        }
    }

    var body: some View
    {
        HStack
        {
            Spacer()

            VStack(spacing: 0)
            {
                // 头部 - 显示实际匹配到的位置名称
                HStack
                {
                    VStack(alignment: .leading, spacing: 4)
                    {
                        Text("选择位置详情")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // 显示匹配到的位置名称和距离信息
                        if let nearestInfo = nearestLocationInfo
                        {
                            Text("\(nearestInfo.name)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .lineLimit(2)

                            if nearestInfo.distance > 0
                            {
                                Text("距离约 \(nearestInfo.distance) 米")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        else
                        {
                            Text("\(mapItem.name ?? "未知位置") 附近")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Button(action: onClose)
                    {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width:64,height:64)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                    .buttonBorderShape(.circle)  // 添加圆形边框
                    .hoverEffect(.highlight)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                // ScrollView内容保持不变，会显示通过坐标匹配到的实际问题
                ScrollView
                {
                    VStack(spacing: 24)
                    {
                        // 地址信息部分 - 显示搜索坐标和匹配结果
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Label("地址", systemImage: "location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4)
                            {
                                if let name = mapItem.name
                                {
                                    Text(name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }

                                // 显示匹配结果信息
                                if let nearestInfo = nearestLocationInfo
                                {
                                    HStack
                                    {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("匹配到: \(nearestInfo.name)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }

                                    if nearestInfo.distance > 0
                                    {
                                        HStack
                                        {
                                            Image(systemName: "ruler")
                                                .foregroundColor(.orange)
                                                .font(.caption2)
                                            Text("距离: \(nearestInfo.distance) 米")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                else if !isLoadingQuestions && loadingError == nil
                                {
                                    // 🔧 新增：显示未找到匹配位置的提示
                                    HStack
                                    {
                                        Image(systemName: "location.slash")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("100米范围内未找到已录入的位置")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }

                                // 原有地址显示逻辑保持不变
                                let addressParts: [String] = [
                                    mapItem.placemark.subThoroughfare,
                                    mapItem.placemark.thoroughfare,
                                    mapItem.placemark.subLocality,
                                    mapItem.placemark.locality,
                                    mapItem.placemark.subAdministrativeArea,
                                    mapItem.placemark.administrativeArea,
                                ].compactMap { $0 }.filter { !$0.isEmpty }

                                let lat = String(format: "%.4f", mapItem.placemark.coordinate.latitude)
                                let lon = String(format: "%.4f", mapItem.placemark.coordinate.longitude)
                                Text("坐标: \(lat), \(lon)")
                                    .font(.caption2)
                                    .foregroundColor(Color.gray)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))

                        LazyVStack(spacing: 24)
                        {
                            // 🆕 新增：AI智能总结卡片
                            if let nearestInfo = nearestLocationInfo
                            {
                                aiSummarySection(locationId: nearestInfo.id)
                            }
                        }

                        // 问题列表部分 - 改进的空状态显示
                        if isLoadingQuestions
                        {
                            VStack(spacing: 16)
                            {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("搜索附近问题中...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
                        }
                        else if let error = loadingError
                        {
                            VStack(spacing: 16)
                            {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                    .foregroundColor(.orange)
                                Text("搜索失败")
                                    .font(.headline)
                                Text(error)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                Button("重新搜索")
                                {
                                    loadQuestions()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
                        }
                        else if questions.isEmpty
                        {
                            // 🔧 改进的空状态显示
                            VStack(spacing: 16)
                            {
                                if nearestLocationInfo != nil
                                {
                                    // 找到了位置但没有问题
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)

                                    Text("这里还没有问答")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    Text("成为第一个在这里提问的人吧！")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                else
                                {
                                    // 没有找到匹配的位置
                                    Image(systemName: "location.magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(.orange)

                                    Text("附近暂无相关位置")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    Text("100米范围内没有已录入的地点，您可以在其他已知地点查看问答。")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(40)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
                        }
                        else
                        {
                            // 显示实际查询到的问题列表
                            ForEach(questions)
                            { question in
                                QuestionCard.compact(
                                    question: question,
                                    onSelect: { onSelectQuestion(question) },
                                    onLike: {
                                        print("在位置详情中点赞: \(question.title)")
                                    }
                                )
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .frame(width: 600)
            .frame(maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: -8, y: 0)
            .padding(.trailing, 20)
            .padding(.vertical, 20)
            .offset(x: animationOffset)
            .opacity(animationOpacity)
            .onAppear
            {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8))
                {
                    animationOffset = 0
                    animationOpacity = 1
                }
                // 侧边栏出现时加载问题列表
                loadQuestions()
            }
            .onChange(of: isPresented)
            { _ in
                if !isPresented
                {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9))
                    {
                        animationOffset = 400
                        animationOpacity = 0
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.15)
                .onTapGesture
                {
                    print("点击背景关闭侧边栏")
                    onClose()
                }
                .opacity(animationOpacity)
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func aiSummarySection(locationId: Int64) -> some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack
            {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundColor(.purple)

                Text("AI智能总结")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                if isLoadingSummary
                {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                else if locationSummary == nil
                {
                    Button(action: {
                        loadLocationSummary(locationId: locationId)
                    })
                    {
                        HStack(spacing: 4)
                        {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            Text("生成")
                                .font(.caption)
                        }
                        .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLoadingSummary
            {
                HStack
                {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("AI正在分析该地点的问题...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            else if let summary = locationSummary
            {
                Text(summary)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .padding(.vertical, 4)
            }
            else if let error = summaryError
            {
                HStack
                {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.05),
                    Color.blue.opacity(0.05),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .onAppear
        {
            // 自动加载总结
            if locationSummary == nil && !isLoadingSummary
            {
                loadLocationSummary(locationId: locationId)
            }
        }
    }

    private func loadLocationSummary(locationId: Int64)
    {
        isLoadingSummary = true
        summaryError = nil

        Task
        {
            do
            {
                let response = try await NetworkManager.shared.getLocationQuestionsSummary(
                    locationId: locationId
                )

                await MainActor.run
                {
                    self.locationSummary = response.summary
                    self.isLoadingSummary = false
                    print("✅ 地点问题总结加载成功")
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isLoadingSummary = false
                    self.summaryError = "总结生成失败，请稍后重试"
                    print("❌ 地点问题总结加载失败: \(error)")
                }
            }
        }
    }
}

struct ThreeDViewThumbnailButton: View
{
    let selectedMapItem: MKMapItem?
    let onEnter3DView: (Location) -> Void
    let onAddPanorama: (Location) -> Void // ✅ 新增回调

    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false
    @State private var has3DView = false
    @State private var isChecking3DView = false
    @State private var currentLocation: Location?
    @State private var showAnimation = false

    var body: some View
    {
        Group
        {
            // ✅ 修改：即使没有找到位置，也显示"添加全景图"按钮
            if let mapItem = selectedMapItem, currentLocation == nil
            {
                // 没有找到匹配的位置，直接显示添加按钮
                Button(action: {
                    // 创建一个临时 Location 对象用于上传
                    let tempLocation = Location(
                        id: -1, // 临时ID，后端会创建新位置
                        name: mapItem.name ?? "未知位置",
                        longitude: mapItem.placemark.coordinate.longitude,
                        latitude: mapItem.placemark.coordinate.latitude,
                        questionCount: 0
                    )
                    onAddPanorama(tempLocation)
                })
                {
                    HStack(spacing: 12)
                    {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4)
                        {
                            Text("添加实景图片")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("为这个地点上传360°全景图")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 300, height: 180)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.highlight)
                .scaleEffect(showAnimation ? 1.0 : 0.8)
                .opacity(showAnimation ? 1.0 : 0)
            }
            else if isLoadingThumbnail
            {
                // 加载中状态
                VStack(spacing: 8)
                {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("加载预览...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 300, height: 180)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            }
            else if has3DView && !isChecking3DView
            {
                // 有3D视图：显示缩略图
                Button(action: {
                    if let location = currentLocation
                    {
                        onEnter3DView(location)
                    }
                })
                {
                    ZStack(alignment: .bottomTrailing)
                    {
                        Group
                        {
                            if let thumbnail = thumbnailImage
                            {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            else
                            {
                                Color.clear
                                    .background(.ultraThinMaterial)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 36))
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                        .frame(width: 300, height: 180)
                        .clipped()
                        .cornerRadius(24)

                        HStack(spacing: 6)
                        {
                            Image(systemName: "square.stack.3d.down.right")
                                .font(.caption)
                            Text("进入3D实景")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.7))
                        .cornerRadius(24)
                        .padding(8)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.highlight)
                .scaleEffect(showAnimation ? 1.0 : 0.8)
                .opacity(showAnimation ? 1.0 : 0)
            }
            else if !isChecking3DView && currentLocation != nil
            {
                // 有位置但没有3D视图：显示添加按钮
                Button(action: {
                    if let location = currentLocation
                    {
                        onAddPanorama(location)
                    }
                })
                {
                    HStack(spacing: 12)
                    {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4)
                        {
                            Text("添加实景图片")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("为这个地点上传360°全景图")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 300, height: 180)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.highlight)
                .scaleEffect(showAnimation ? 1.0 : 0.8)
                .opacity(showAnimation ? 1.0 : 0)
            }
            else if isChecking3DView
            {
                // 正在检查状态
                VStack(spacing: 8)
                {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("检查3D视图...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 300, height: 180)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            }
        }
        .onAppear
        {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
            {
                showAnimation = true
            }
            loadLocationAndCheck3DView()
        }
        .onChange(of: selectedMapItem)
        { _ in
            loadLocationAndCheck3DView()
        }
    }

    private func loadLocationAndCheck3DView()
    {
        print("🎯 [Button] loadLocationAndCheck3DView 开始")

        guard let mapItem = selectedMapItem
        else
        {
            print("🎯 [Button] selectedMapItem 为 nil")
            currentLocation = nil
            has3DView = false
            return
        }

        let coordinate = mapItem.placemark.coordinate
        print("🎯 [Button] 坐标: (\(coordinate.latitude), \(coordinate.longitude))")

        Task
        {
            do
            {
                let response = try await NetworkManager.shared.findNearestLocationQuestions(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    maxDistance: 100
                )

                if response.success, let nearestInfo = response.nearestLocation
                {
                    let location = Location(
                        id: nearestInfo.id,
                        name: nearestInfo.name,
                        longitude: nearestInfo.longitude,
                        latitude: nearestInfo.latitude,
                        questionCount: response.questions.count
                    )

                    await MainActor.run
                    {
                        self.currentLocation = location
                        print("🎯 [Button] 找到位置: \(location.name)")
                    }

                    await check3DViewExists(for: location)
                }
                else
                {
                    await MainActor.run
                    {
                        self.currentLocation = nil
                        self.has3DView = false
                        print("🎯 [Button] 未找到匹配位置")
                    }
                }
            }
            catch
            {
                print("🎯 [Button] 查找位置失败: \(error)")
                await MainActor.run
                {
                    self.currentLocation = nil
                    self.has3DView = false
                }
            }
        }
    }

    private func check3DViewExists(for location: Location) async
    {
        print("🎯 [Button] 开始检查: \(location.name)")

        await MainActor.run
        {
            isChecking3DView = true
        }

        do
        {
            let exists = try await NetworkManager.shared.checkLocationHas3DView(locationId: location.id)

            print("🎯 [Button] 结果: exists=\(exists)")

            await MainActor.run
            {
                self.has3DView = exists
                self.isChecking3DView = false
            }

            if exists
            {
                print("🎯 [Button] 调用 loadThumbnail")
                await loadThumbnail(for: location)
            }
        }
        catch
        {
            print("🎯 [Button] 异常: \(error)")
            await MainActor.run
            {
                self.has3DView = false
                self.isChecking3DView = false
            }
        }
    }

    private func loadThumbnail(for location: Location) async
    {
        print("🖼️ [loadThumbnail] 开始加载缩略图: locationId=\(location.id)")

        await MainActor.run
        {
            isLoadingThumbnail = true
            print("🖼️ [loadThumbnail] 设置 isLoadingThumbnail=true")
        }

        do
        {
            let thumbnailBase64 = try await NetworkManager.shared.get3DViewThumbnail(
                locationId: location.id,
                width: 300,
                height: 180
            )

            if let base64Data = thumbnailBase64.components(separatedBy: ",").last,
               let imageData = Data(base64Encoded: base64Data),
               let image = UIImage(data: imageData)
            {
                await MainActor.run
                {
                    self.thumbnailImage = image
                    self.isLoadingThumbnail = false
                    print("✅ 缩略图加载成功")
                }
            }
        }
        catch
        {
            await MainActor.run
            {
                self.thumbnailImage = nil
                self.isLoadingThumbnail = false
                print("❌ 缩略图加载失败: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview(windowStyle: .automatic)
{
    ExploreView()
}
