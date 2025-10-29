import CoreLocation
import MapKit
import SwiftUI

struct QuestionView: View
{
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @EnvironmentObject var vrManager: VRSessionManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var locationManager = LocationManager.shared

    @State private var mapItems: [MKMapItem] = []
    @State private var defaultMapItem: MKMapItem?
    @State private var regionSpan: Double = 500
    @State private var selectedMapItem: MKMapItem?

    // 问题表单状态
    @State private var addressSearch: String = ""
    @State private var selectedAddressMapItem: MKMapItem?
    @State private var specificLocationDescription: String = ""
    @State private var questionTitle: String = ""
    @State private var questionContent: String = ""
    @State private var enableTimeRange: Bool = false
    @State private var selectedDate = Date()
    @State private var enableGeoRange: Bool = false
    @State private var geoRange: Double = 100

    @State private var showSidebar = true

    // 发布状态
    @State private var isPublishing = false
    @State private var publishError: String?
    @State private var showPublishSuccess = false

    @State private var matchedLocation: Location? // 根据坐标匹配到的Location
    @State private var has3DView = false
    @State private var isChecking3DView = false
    @State private var current3DViewData: View3DData?

    // AI相关状态
    @State private var showSmartSuggestionAI = false
    @State private var showRelatedSearchAI = false
    @State private var showAIAssistant = false

    // 定位相关状态
    @State private var isLoadingLocation = false
    @State private var hasAttemptedLocation = false

    @State private var locationToUpload: Location?

    // ✅ 新增：3D位置相关状态
    @State private var question3DPosition: SIMD3<Float>?
    @State private var isSettingQuestion3DPosition = false
    
    @State private var isDrawingMode: Bool = false
    @State private var drawnPoints: [CLLocationCoordinate2D] = []
    @State private var isRegionClosed: Bool = false
    @State private var drawnRegion: DrawnRegion?

    var currentLocation: Location?
    {
        return matchedLocation // 改为返回动态匹配的Location
    }

    var view3D: Real3DViewSpace?
    {
        guard let location = currentLocation else { return nil }
        return realities.first { $0.locationID == location.id }
    }

    var body: some View {
        ZStack {
            // 地图层
            ZStack(alignment: .topLeading) {
                DrawableMapView(
                    mapItems: mapItems,
                    defaultMapItem: selectedAddressMapItem ?? defaultMapItem,
                    regionSpan: $regionSpan,
                    selectedMapItem: $selectedMapItem,
                    isDrawingMode: $isDrawingMode,
                    drawnPoints: $drawnPoints,
                    isRegionClosed: $isRegionClosed,
                    markerColor: MapMarkerColor.green.uiColor,
                    centerOffset: -5000
                )
                .onAppear {
                    loadUserLocationForQuestion()
                }
                
                // ✅ 添加绘制控制按钮 - 右下角
                if enableGeoRange {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            drawingControlButtons
                                .padding(32)
                        }
                    }
                }

                // 菜单按钮
                Button {
                    showSidebar = true
                } label: {
                    HStack {
                        Image(systemName: "menucard.fill")
                            .font(.title)
                            .padding()
                            .cornerRadius(8)
                    }
                }.padding(32)
            }

            // 左侧问题发布面板
            if showSidebar
            {
                QuestionPublishSidebar(
                    mapItem: selectedAddressMapItem ?? selectedMapItem ?? defaultMapItem,
                    addressSearch: $addressSearch,
                    selectedAddressMapItem: $selectedAddressMapItem,
                    specificLocationDescription: $specificLocationDescription,
                    questionTitle: $questionTitle,
                    questionContent: $questionContent,
                    enableTimeRange: $enableTimeRange,
                    selectedDate: $selectedDate,
                    enableGeoRange: $enableGeoRange,
                    geoRange: $geoRange,
                    isPublishing: $isPublishing,
                    publishError: $publishError,
                    view3D: view3D,
                    showSmartSuggestionAI: $showSmartSuggestionAI,
                    showRelatedSearchAI: $showRelatedSearchAI,
                    showAIAssistant: $showAIAssistant,
                    question3DPosition: $question3DPosition,
                    onOpen3DPositionSetting: {
                        open3DPositionSetting()
                    },
                    onClear3DPosition: {
                        clear3DPosition()
                    },
                    isLoadingLocation: isLoadingLocation,
                    onClose: {
                        withAnimation
                        {
                            showSidebar = false
                        }
                    },
                    onPublish: {
                        publishQuestion()
                    },
                    onAddressSelected: { mapItem in
                        handleAddressSelection(mapItem)
                    },
                    has3DView: has3DView,
                    isChecking3DView: isChecking3DView,
                    onCheck3DView: {
                        check3DViewExists()
                    },
                    onOpen3DView: {
                        handle3DViewRequest()
                    },
                    // ✅ 新增参数
                    currentLocation: matchedLocation,
                    onAddPanorama: { location in
                        print("🎬 触发添加全景图: \(location.name)")
                        locationToUpload = location
                    }
                )

                .onAppear
                {
                    if let mapItem = selectedAddressMapItem
                    {
                        checkNearbyLocationWith3DView(coordinate: mapItem.placemark.coordinate)
                    }
                }
                .zIndex(10)
            }

            // 成功提示
            if showPublishSuccess
            {
                VStack
                {
                    Spacer()
                    HStack
                    {
                        Spacer()
                        VStack(spacing: 12)
                        {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("问题发布成功!")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 10)
                        Spacer()
                    }
                    Spacer()
                }
                .zIndex(100)
                .onAppear
                {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2)
                    {
                        withAnimation
                        {
                            showPublishSuccess = false
                        }
                    }
                }
            }

            // AI助手
            if showAIAssistant
            {
                AIAssistant.forQuestionDraft(
                    questionData: QuestionDraftData(
                        location: selectedAddressMapItem?.name ?? "",
                        specificPlace: specificLocationDescription,
                        title: questionTitle,
                        content: questionContent,
                        latitude: selectedAddressMapItem?.placemark.coordinate.latitude,
                        longitude: selectedAddressMapItem?.placemark.coordinate.longitude
                    ),
                    isPresented: $showAIAssistant
                )
                .zIndex(200)
                .onDisappear
                {
                    showSmartSuggestionAI = false
                    showRelatedSearchAI = false
                }
            }
        }
        .background(.regularMaterial)
        .cornerRadius(32)
        .sheet(item: $locationToUpload)
        { location in
            AddRealSpace(
                locationId: location.id,
                locationName: location.name,
                latitude: location.latitude,
                longitude: location.longitude
            )
            .environmentObject(userManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToQuestionWithLocation")))
        { notification in
            if let mapItem = notification.userInfo?["mapItem"] as? MKMapItem
            {
                print("🔔 QuestionView 接收到位置通知: \(mapItem.name ?? "未知")")

                // 自动填充地址
                self.addressSearch = mapItem.name ?? ""
                self.selectedAddressMapItem = mapItem
                self.selectedMapItem = mapItem
                self.defaultMapItem = mapItem

                // ✅ 使用统一的处理函数
                self.handleAddressSelection(mapItem)

                // 显示侧边栏
                withAnimation
                {
                    self.showSidebar = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("QuestionPositionSet")))
        { notification in
            if let position = notification.userInfo?["position"] as? SIMD3<Float>
            {
                print("🎯 收到问题位置设置: \(position)")
                self.question3DPosition = position
                self.isSettingQuestion3DPosition = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("QuestionPositionCancel")))
        { _ in
            print("❌ 取消问题位置设置")
            self.isSettingQuestion3DPosition = false
        }
    }

    private func handleAddressSelection(_ mapItem: MKMapItem)
    {
        print("📍 用户选择地址: \(mapItem.name ?? "未知")")

        // 更新地图显示
        updateMapLocation(mapItem)

        // 清空相关表单字段
        specificLocationDescription = ""
        questionTitle = ""
        questionContent = ""

        // 重置匹配状态
        matchedLocation = nil
        has3DView = false

        // 查找附近的3D视图位置
        checkNearbyLocationWith3DView(coordinate: mapItem.placemark.coordinate)
    }

    private var drawingControlButtons: some View {
        VStack(spacing: 12) {
            if !isDrawingMode && drawnRegion == nil {
                // 未绘制：显示"开始绘制"按钮
                Button(action: {
                    withAnimation {
                        isDrawingMode = true
                        drawnPoints = []
                        isRegionClosed = false
                        drawnRegion = nil
                    }
                    print("🎨 开始绘制推送区域")
                }) {
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
            } else if isDrawingMode && !isRegionClosed {
                // 绘制中：显示"取消"和"完成"按钮
                VStack(spacing: 8) {
                    Button(action: cancelDrawing) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text("取消绘制")
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(Circle())
                        .buttonBorderShape(.circle)  // 添加圆形边框
                        .hoverEffect(.highlight)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    if drawnPoints.count >= 3 {
                        Button(action: {
                            // ✅ 完成绘制后自动确认并退出
                            guard drawnPoints.count >= 3 else { return }
                            withAnimation {
                                isRegionClosed = true
                                drawnRegion = DrawnRegion(points: drawnPoints)
                                isDrawingMode = false  // ✅ 直接退出绘制模式
                            }
                            print("✅ 完成绘制推送区域")
                            print("  顶点数: \(drawnPoints.count)")
                            if let region = drawnRegion {
                                print("  边界框: Lat[\(region.boundingBox.minLat), \(region.boundingBox.maxLat)], Lon[\(region.boundingBox.minLon), \(region.boundingBox.maxLon)]")
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                Text("完成绘制")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
            } else if drawnRegion != nil {
                // ✅ 已完成绘制：显示"重新绘制"按钮
                Button(action: {
                    withAnimation {
                        isDrawingMode = true
                        drawnPoints = []
                        isRegionClosed = false
                        drawnRegion = nil
                    }
                    print("🔄 重新绘制推送区域")
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重新绘制推送区域")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
    
    // ✅ 添加绘制控制方法
    private func resetDrawing() {
        withAnimation {
            drawnPoints = []
            isRegionClosed = false
            drawnRegion = nil
        }
        print("🔄 重置绘制")
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

    private func closeRegionManually() {
        guard drawnPoints.count >= 3 else { return }
        withAnimation {
            isRegionClosed = true
            drawnRegion = DrawnRegion(points: drawnPoints)
        }
        print("✅ 手动闭合区域")
    }

    private func confirmDrawnRegion() {
        guard let region = drawnRegion else { return }
        
        print("📤 确认推送区域:")
        print("  顶点数: \(region.points.count)")
        print("  边界框: Lat[\(region.boundingBox.minLat), \(region.boundingBox.maxLat)], Lon[\(region.boundingBox.minLon), \(region.boundingBox.maxLon)]")
        
        // 退出绘制模式
        withAnimation {
            isDrawingMode = false
        }
    }
    
    // MARK: - 加载用户位置用于提问

    private func loadUserLocationForQuestion()
    {
        guard !hasAttemptedLocation else { return }
        hasAttemptedLocation = true

        print("🗺️ 开始获取用户位置用于提问...")

        isLoadingLocation = true
        locationManager.requestLocationPermission()

        // 延迟检查位置并执行反向地理编码
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5)
        {
            if let location = locationManager.currentLocation
            {
                print("✅ 使用用户位置: \(location.coordinate)")
                self.performReverseGeocoding(for: location.coordinate)
            }
            else
            {
                print("⚠️ 无法获取用户位置，不设置默认地址")
                self.isLoadingLocation = false
                // 不设置默认位置，让用户手动搜索
            }
        }
    }

    // MARK: - 反向地理编码

    private func performReverseGeocoding(for coordinate: CLLocationCoordinate2D)
    {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        geocoder.reverseGeocodeLocation(location)
        { placemarks, error in
            DispatchQueue.main.async
            {
                self.isLoadingLocation = false

                if let error = error
                {
                    print("❌ 反向地理编码失败: \(error)")
                    return
                }

                guard let placemark = placemarks?.first
                else
                {
                    print("❌ 未找到地址信息")
                    return
                }

                // 创建 MKPlacemark 和 MKMapItem
                let mkPlacemark = MKPlacemark(placemark: placemark)
                let mapItem = MKMapItem(placemark: mkPlacemark)

                // 构建地址字符串
                var addressComponents: [String] = []
                if let name = placemark.name { addressComponents.append(name) }
                if let thoroughfare = placemark.thoroughfare { addressComponents.append(thoroughfare) }
                if let subLocality = placemark.subLocality { addressComponents.append(subLocality) }
                if let locality = placemark.locality { addressComponents.append(locality) }

                let addressString = addressComponents.joined(separator: ", ")

                // 设置地址
                self.addressSearch = addressString
                self.selectedAddressMapItem = mapItem
                self.defaultMapItem = mapItem
                self.selectedMapItem = mapItem

                print("✅ 地址已自动填充: \(addressString)")
                print("✅ 坐标: \(coordinate.latitude), \(coordinate.longitude)")

                self.checkNearbyLocationWith3DView(coordinate: coordinate)
            }
        }
    }

    private func checkNearbyLocationWith3DView(coordinate: CLLocationCoordinate2D)
    {
        isChecking3DView = true
        has3DView = false
        matchedLocation = nil

        Task
        {
            do
            {
                let nearbyResponse = try await NetworkManager.shared.findNearestLocationQuestions(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    maxDistance: 50  // 🔧 修改：限制为50米范围内搜索，避免误匹配远处的位置
                )

                await MainActor.run
                {
                    if nearbyResponse.success, let nearestLoc = nearbyResponse.nearestLocation
                    {
                        let foundLocation = Location(
                            id: nearestLoc.id,
                            name: nearestLoc.name,
                            longitude: nearestLoc.longitude,
                            latitude: nearestLoc.latitude,
                            questionCount: 0
                        )
                        self.matchedLocation = foundLocation

                        print("✅ 找到附近Location: \(foundLocation.name), 距离: \(nearestLoc.distance)米")

                        // ✅ 关键修复：自动检查3D视图并应用，无需用户再次点击
                        self.check3DViewAndApply()
                    }
                    else
                    {
                        self.isChecking3DView = false
                        self.has3DView = false
                        print("附近1公里内没有找到Location")
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isChecking3DView = false
                    self.has3DView = false
                    self.matchedLocation = nil
                    print("查询附近Location失败: \(error)")
                }
            }
        }
    }

    private func check3DViewAndApply()
    {
        guard let location = matchedLocation
        else
        {
            isChecking3DView = false
            return
        }

        Task
        {
            do
            {
                let exists = try await NetworkManager.shared.checkLocationHas3DView(locationId: location.id)

                await MainActor.run
                {
                    self.has3DView = exists
                    self.isChecking3DView = false

                    if exists
                    {
                        print("✅ 该位置有3D视图，已自动应用: locationId=\(location.id)")
                    }
                    else
                    {
                        print("ℹ️ 该位置暂无3D视图: locationId=\(location.id)")
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.has3DView = false
                    self.isChecking3DView = false
                    print("检查3D视图存在性失败: \(error)")
                }
            }
        }
    }

    // MARK: - 更新地图位置

    private func updateMapLocation(_ mapItem: MKMapItem)
    {
        selectedMapItem = mapItem
        regionSpan = 1000
    }

    // MARK: - 搜索位置

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
            completion(response?.mapItems ?? [])
        }
    }

    // MARK: - 发布问题

    private func publishQuestion()
    {
        guard let currentUserId = userManager.getUserId()
        else
        {
            publishError = "请先登录再发布问题"
            return
        }

        guard let selectedMapItem = selectedAddressMapItem,
              !questionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !questionContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else
        {
            publishError = "请完整填写问题标题、内容并选择位置"
            return
        }

        let latitude = selectedMapItem.placemark.coordinate.latitude
        let longitude = selectedMapItem.placemark.coordinate.longitude
        let locationName = selectedMapItem.name ?? "未知位置"

        let actualPlace = specificLocationDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
            locationName :
            "\(specificLocationDescription.trimmingCharacters(in: .whitespacesAndNewlines))"

        publishError = nil
        isPublishing = true

        // 在 publishQuestion() 方法中
        if let region = drawnRegion {
            _ = [
                "type": "polygon",
                "points": region.points.map {
                    ["lat": $0.latitude, "lon": $0.longitude]
                },
                "boundingBox": [
                    "minLat": region.boundingBox.minLat,
                    "maxLat": region.boundingBox.maxLat,
                    "minLon": region.boundingBox.minLon,
                    "maxLon": region.boundingBox.maxLon
                ]
            ] as [String : Any]
            // 发送到后端
        }
        Task
        {
            do
            {
                // ✅ 根据是否有3D位置选择不同的API
                if let position3D = question3DPosition
                {
                    print("📍 发布带3D位置的问题: \(position3D)")

                    let response = try await NetworkManager.shared.createQuestionWith3DPosition(
                        latitude: latitude,
                        longitude: longitude,
                        locationName: locationName,
                        actualPlace: actualPlace,
                        title: questionTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        content: questionContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        userId: currentUserId,
                        position3D: position3D
                    )

                    await MainActor.run
                    {
                        self.isPublishing = false

                        if response.success
                        {
                            print("✅ 带3D位置的问题发布成功!")
                            self.clearForm()
                            self.question3DPosition = nil
                            withAnimation
                            {
                                self.showPublishSuccess = true
                            }
                        }
                        else
                        {
                            self.publishError = response.message ?? "发布问题失败"
                        }
                    }
                }
                else
                {
                    // 普通问题发布（原有逻辑）
                    let response = try await NetworkManager.shared.createQuestion(
                        latitude: latitude,
                        longitude: longitude,
                        locationName: locationName,
                        actualPlace: actualPlace,
                        title: questionTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        content: questionContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        userId: currentUserId
                    )

                    await MainActor.run
                    {
                        self.isPublishing = false

                        if response.success
                        {
                            print("✅ 问题发布成功!")
                            self.clearForm()
                            withAnimation
                            {
                                self.showPublishSuccess = true
                            }
                        }
                        else
                        {
                            self.publishError = response.message ?? "发布问题失败"
                        }
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.isPublishing = false
                    self.publishError = "网络错误,请检查网络连接后重试"
                    print("❌ 发布问题网络错误: \(error)")
                }
            }
        }
    }

    // ✅ 新增：打开3D位置设置
    private func open3DPositionSetting()
    {
        guard has3DView
        else
        {
            publishError = "该位置暂无3D视图，无法设置3D位置"
            return
        }

        guard let location = currentLocation
        else
        {
            publishError = "请先选择地址"
            return
        }

        isSettingQuestion3DPosition = true

        Task
        {
            do
            {
                // 加载3D视图数据
                let view3DData = try await NetworkManager.shared.fetch3DView(for: location.id)

                await MainActor.run
                {
                    vrManager.updateLocationInfoWithURL(
                        title: location.name, locationId: location.id,
                        panoramaImageURL: view3DData.fileURL
                    )
                }

                // 打开Question3DSet空间
                await openImmersiveSpace(id: "Question3DSetSpace")
            }
            catch
            {
                await MainActor.run
                {
                    self.isSettingQuestion3DPosition = false
                    self.publishError = "无法加载3D视图: \(error.localizedDescription)"
                }
            }
        }
    }

    // ✅ 新增：清除3D位置
    private func clear3DPosition()
    {
        question3DPosition = nil
        print("🗑️ 已清除3D位置")
    }

    // MARK: - 清空表单

    private func clearForm()
    {
        // 不清空地址相关字段，保留用户位置
        specificLocationDescription = ""
        questionTitle = ""
        questionContent = ""
        enableTimeRange = false
        selectedDate = Date()
        enableGeoRange = false
        geoRange = 100
    }

    private func check3DViewExists()
    {
        guard let location = currentLocation
        else
        {
            has3DView = false
            return
        }

        isChecking3DView = true

        Task
        {
            do
            {
                let exists = try await NetworkManager.shared.checkLocationHas3DView(locationId: location.id)

                await MainActor.run
                {
                    self.has3DView = exists
                    self.isChecking3DView = false
                    print("3D视图存在性检查完成: locationId=\(location.id), has3DView=\(exists)")
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.has3DView = false
                    self.isChecking3DView = false
                    print("检查3D视图存在性失败: \(error)")
                }
            }
        }
    }

    private func handle3DViewRequest()
    {
        guard let location = currentLocation, has3DView
        else
        {
            print("无法打开3D视图:位置不存在或无3D数据")
            return
        }

        Task
        {
            do
            {
                await MainActor.run
                {
                    vrManager.setLoadingState(true)
                }

                print("请求3D视图数据,位置ID: \(location.id)")

                let view3DData = try await NetworkManager.shared.fetch3DView(for: location.id)

                await MainActor.run
                {
                    self.current3DViewData = view3DData
                    vrManager.updateLocationInfoWithURL(
                        title: location.name, locationId: location.id,
                        panoramaImageURL: view3DData.fileURL
                    )

                    print("获取3D视图数据成功: \(view3DData.name)")
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
                    print("该位置暂无3D视图数据,使用本地备用数据")

                    if let view3D = realities.first(where: { $0.locationID == location.id })
                    {
                        vrManager.updateLocationInfo(
                            title: location.name, locationId: location.id,
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
                    else
                    {
                        self.has3DView = false
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    vrManager.setLoadingState(false)
                    self.has3DView = false
                    print("获取3D视图失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct QuestionPublishSidebar: View
{
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @EnvironmentObject var vrManager: VRSessionManager

    let mapItem: MKMapItem?
    @Binding var addressSearch: String
    @Binding var selectedAddressMapItem: MKMapItem?
    @Binding var specificLocationDescription: String
    @Binding var questionTitle: String
    @Binding var questionContent: String
    @Binding var enableTimeRange: Bool
    @Binding var selectedDate: Date
    @Binding var enableGeoRange: Bool
    @Binding var geoRange: Double
    @Binding var isPublishing: Bool
    @Binding var publishError: String?
    let view3D: Real3DViewSpace?

    @Binding var showSmartSuggestionAI: Bool
    @Binding var showRelatedSearchAI: Bool
    @Binding var showAIAssistant: Bool

    // ✅ 3D位置相关参数
    @Binding var question3DPosition: SIMD3<Float>?
    let onOpen3DPositionSetting: () -> Void
    let onClear3DPosition: () -> Void

    let isLoadingLocation: Bool

    let onClose: () -> Void
    let onPublish: () -> Void
    let onAddressSelected: ((MKMapItem) -> Void)?

    let has3DView: Bool
    let isChecking3DView: Bool
    let onCheck3DView: () -> Void
    let onOpen3DView: () -> Void

    @State private var animationOffset: CGFloat = -600
    @State private var animationOpacity: Double = 0

    // ✅ 新增：3D实景开启状态
    @State private var is3DViewOpen = false
    // ✅ 新增：缩略图状态
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false

    // ✅ 新增参数
    let currentLocation: Location? // 传入匹配到的 Location
    let onAddPanorama: (Location) -> Void // 添加全景图回调

    var body: some View
    {
        HStack
        {
            VStack(spacing: 0)
            {
                // 头部
                HStack
                {
                    VStack(alignment: .leading, spacing: 4)
                    {
                        Text("发布问题")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("选择位置并描述问题")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                    }

                    Spacer()
                    Button(action: onClose)
                    {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                    .buttonBorderShape(.circle)  // 添加圆形边框
                    .hoverEffect(.highlight)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView
                {
                    VStack(spacing: 24)
                    {
                        // 错误提示
                        if let error = publishError
                        {
                            HStack
                            {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                                Button("✕")
                                {
                                    publishError = nil
                                }
                                .foregroundColor(.orange)
                                .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 20)
                        }

                        // 地址搜索输入
                        VStack(alignment: .leading, spacing: 8)
                        {
                            HStack
                            {
                                Label("地址搜索", systemImage: "magnifyingglass.circle")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)

                                if isLoadingLocation
                                {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("正在获取位置...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            AddressSearchField(
                                searchText: $addressSearch,
                                selectedMapItem: $selectedAddressMapItem,
                                placeholder: "搜索并选择地址...", // ✅ 无空格
                                onLocationSelected: { mapItem in
                                    onAddressSelected?(mapItem)
                                }
                            )
                        }
                        .padding(.horizontal, 20)

                        // 选中位置显示
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Label("选中位置", systemImage: "location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8)
                            {
                                TextField("在此添加具体位置描述", text: $specificLocationDescription)
                                    .lineLimit(2 ... 4)
                                    .textFieldStyle(.roundedBorder)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                    .disabled(selectedAddressMapItem == nil)
                            }
                        }
                        .padding(.horizontal, 20)

                        // 问题标题输入
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Label("问题标题", systemImage: "textformat.abc")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            TextField("请输入问题标题...", text: $questionTitle)
                                .textFieldStyle(.roundedBorder)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 20)

                        // 问题内容输入
                        VStack(alignment: .leading, spacing: 8)
                        {
                            Label("问题内容", systemImage: "questionmark.bubble")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            TextField("请输入您的问题详细描述...", text: $questionContent, axis: .vertical)
                                .lineLimit(5 ... 7)
                                .textFieldStyle(.roundedBorder)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .frame(minHeight: 120)
                        }
                        .padding(.horizontal, 20)
                        
                        // 智能提问和搜索按钮
                        HStack(spacing: 12)
                        {
                            Button(action: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8))
                                {
                                    showSmartSuggestionAI = true
                                    showAIAssistant = true
                                }
                            })
                            {
                                HStack
                                {
                                    Image(systemName: "sparkles")
                                    Text("智能提问")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isPublishing ||
                                selectedAddressMapItem == nil ||
                                questionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button(action: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8))
                                {
                                    showRelatedSearchAI = true
                                    showAIAssistant = true
                                }
                            })
                            {
                                HStack
                                {
                                    Image(systemName: "magnifyingglass")
                                    Text("搜索相关提问")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isPublishing || selectedAddressMapItem == nil)
                        }
                        .padding(.horizontal, 20)

                        // ✅ 3D实景位置设置区域
                        VStack(alignment: .leading, spacing: 12)
                        {
                            Label("3D实景位置（可选）", systemImage: "cube.transparent")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12)
                            {
                                // ✅ 根据状态显示不同UI
                                Group
                                {
                                    if isChecking3DView
                                    {
                                        // 正在检查3D视图
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
                                    else if has3DView
                                    {
                                        // 有3D数据：显示缩略图 + 进入按钮
                                        Button(action: {
                                            if is3DViewOpen
                                            {
                                                Task
                                                {
                                                    await dismissImmersiveSpace()
                                                    is3DViewOpen = false
                                                }
                                            }
                                            else
                                            {
                                                onOpen3DPositionSetting()
                                                is3DViewOpen = true
                                            }
                                        })
                                        {
                                            ZStack(alignment: .bottomTrailing)
                                            {
                                                Group
                                                {
                                                    if isLoadingThumbnail
                                                    {
                                                        Color.clear
                                                            .background(.ultraThinMaterial)
                                                            .overlay(
                                                                VStack(spacing: 8)
                                                                {
                                                                    ProgressView()
                                                                        .scaleEffect(0.7)
                                                                    Text("加载预览...")
                                                                        .font(.caption2)
                                                                        .foregroundColor(.secondary)
                                                                }
                                                            )
                                                    }
                                                    else if let thumbnail = thumbnailImage
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

                                                // 右下角标签
                                                HStack(spacing: 6)
                                                {
                                                    Image(systemName: is3DViewOpen ? "xmark" : "square.stack.3d.down.right")
                                                        .font(.caption)
                                                    Text(is3DViewOpen ? "关闭3D实景" : "进入3D实景")
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
                                        .disabled(isPublishing)
                                    }
                                    else if currentLocation != nil
                                    {
                                        // 有位置但无3D数据：显示添加按钮
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

                                                Spacer()
                                            }
                                            .frame(width: 300, height: 180)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 24))
                                            .cornerRadius(24)
                                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .hoverEffect(.highlight)
                                        .disabled(isPublishing)
                                    }
                                    else if selectedAddressMapItem != nil
                                    {
                                        // ✅ 新增：选择了地址但没找到位置，显示添加按钮
                                        Button(action: {
                                            guard let mapItem = selectedAddressMapItem else { return }
                                            // 创建临时 Location 对象用于上传
                                            let tempLocation = Location(
                                                id: -1,
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

                                                    Text("为这个地点上传360°全景图")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()
                                            }
                                            .frame(width: 300, height: 180)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 24))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .hoverEffect(.highlight)
                                        .disabled(isPublishing)
                                    }
                                    else
                                    {
                                        // 未选择地址或未匹配到位置
                                        VStack(spacing: 12)
                                        {
                                            Image(systemName: "location.slash")
                                                .font(.system(size: 36))
                                                .foregroundColor(.secondary)
                                            Text("请先选择地址")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(width: 300, height: 180)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(24)
                                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                                    }
                                }
                                // ✅ 关键：添加 onChange 监听器
                                .onChange(of: has3DView)
                                { newValue in
                                    print("🔄 has3DView 变化: \(newValue)")
                                    if newValue
                                    {
                                        loadThumbnailIfNeeded()
                                    }
                                    else
                                    {
                                        thumbnailImage = nil
                                    }
                                }
                                .onChange(of: currentLocation?.id)
                                { _ in
                                    print("🔄 currentLocation 变化")
                                    thumbnailImage = nil // 重置缩略图
                                    if has3DView
                                    {
                                        loadThumbnailIfNeeded()
                                    }
                                }

                                // ✅ 右侧状态显示（保持不变）
                                VStack(alignment: .leading, spacing: 8)
                                {
                                    if let position = question3DPosition
                                    {
                                        // 已设置位置
                                        VStack(alignment: .leading, spacing: 6)
                                        {
                                            HStack(spacing: 4)
                                            {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                    .font(.caption)
                                                Text("已设置3D位置")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.green)
                                            }

                                            Button(action: onClear3DPosition)
                                            {
                                                HStack(spacing: 4)
                                                {
                                                    Image(systemName: "trash")
                                                    Text("清除")
                                                }
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(.red)
                                            .padding(.top, 4)
                                        }
                                        .padding(12)
                                        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    else if is3DViewOpen
                                    {
                                        VStack(alignment: .leading, spacing: 6)
                                        {
                                            HStack(spacing: 4)
                                            {
                                                Image(systemName: "hand.point.up.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.caption)
                                                Text("操作提示")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.blue)
                                            }

                                            Text("1. 拖动橙色问题球到合适位置")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)

                                            Text("2. 点击问题球保存位置")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(12)
                                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    else if has3DView
                                    {
                                        VStack(alignment: .leading, spacing: 6)
                                        {
                                            HStack(spacing: 4)
                                            {
                                                Image(systemName: "info.circle")
                                                    .foregroundColor(.secondary)
                                                    .font(.caption)
                                                Text("点击图片进入3D实景")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(12)
                                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    else
                                    {
                                        VStack(alignment: .leading, spacing: 6)
                                        {
                                            HStack(spacing: 4)
                                            {
                                                Image(systemName: "exclamationmark.triangle")
                                                    .foregroundColor(.orange)
                                                    .font(.caption)
                                                Text(currentLocation == nil ? "请先选择地址" : "该位置暂无3D数据")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        .padding(12)
                                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        HStack
                        {
                            // 时效范围设置
                            VStack(alignment: .leading, spacing: 12)
                            {
                                HStack
                                {
                                    Label("时效范围", systemImage: "clock")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Toggle("", isOn: $enableTimeRange)
                                        .labelsHidden()
                                        .disabled(isPublishing)
                                }

                            }
                            .padding(.horizontal, 20)

                            // 地理范围设置
                            VStack(alignment: .leading, spacing: 12)
                            {
                                HStack
                                {
                                    Label("地理范围", systemImage: "circle.dashed")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Toggle("", isOn: $enableGeoRange)
                                        .labelsHidden()
                                        .disabled(isPublishing)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        
                        if enableTimeRange
                        {
                            DatePicker(
                                "选择时间",
                                selection: $selectedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .padding(12)
                            .background(in: RoundedRectangle(cornerRadius: 12))
                            .disabled(isPublishing)
                        }

                        // 发布按钮
                        Button(action: onPublish)
                        {
                            HStack
                            {
                                if isPublishing
                                {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isPublishing ? "正在发布..." : "发布问题")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .disabled(
                            isPublishing ||
                                is3DViewOpen ||  // ✅ 新增：ImmersiveView打开时禁用发布按钮
                                selectedAddressMapItem == nil ||
                                questionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                questionContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )

                        Spacer(minLength: 40)
                    }
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
            .shadow(color: .black.opacity(0.2), radius: 20, x: 8, y: 0)
            .padding(.leading, 20)
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

                // ✅ 先检查3D视图
                onCheck3DView()

                // ✅ 延迟加载缩略图，确保 has3DView 已更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                {
                    if self.has3DView && self.currentLocation != nil
                    {
                        self.loadThumbnailIfNeeded()
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ✅ 真正加载缩略图
    private func loadThumbnailIfNeeded()
    {
        guard has3DView,
              let location = currentLocation,
              thumbnailImage == nil,
              !isLoadingThumbnail else { return }

        isLoadingThumbnail = true

        Task
        {
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
                        print("✅ 问题发布页面缩略图加载成功")
                    }
                }
            }
            catch
            {
                await MainActor.run
                {
                    self.thumbnailImage = nil
                    self.isLoadingThumbnail = false
                    print("❌ 问题发布页面缩略图加载失败: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview(windowStyle: .automatic)
{
    QuestionView()
        .environmentObject(UserManager.shared)
}
