//
//  QandAView.swift
//  ReaLink
//
//  Created by douer_lucky on 2025.07.02.
//

import SwiftUI
import MapKit

// MARK: - 全屏地图组件
struct FullScreenMapView: UIViewRepresentable {
    let locationInfo: LocationInfo
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = false
        mapView.mapType = .standard
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinate = CLLocationCoordinate2D(
            latitude: locationInfo.latitude,
            longitude: locationInfo.longitude
        )
        
        // 清除现有标注
        mapView.removeAnnotations(mapView.annotations)
        
        // 创建标注
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = locationInfo.name
        mapView.addAnnotation(annotation)
        
        // 计算向右偏移的中心点（为右侧详情弹窗让位）
        let mapBounds = mapView.bounds
        let offsetRatio: Double = 0.3 // 向右偏移30%
        let longitudeOffset = 0.01 * offsetRatio // 约1公里的偏移
        
        let offsetCoordinate = CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude + longitudeOffset
        )
        
        // 设置地图显示区域
        let region = MKCoordinateRegion(
            center: offsetCoordinate,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        
        mapView.setRegion(region, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "LocationPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                
                // 创建橙色圆形标记
                let size: CGFloat = 40
                let circleView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circleView.backgroundColor = UIColor.systemOrange
                circleView.layer.cornerRadius = size / 2
                circleView.layer.borderColor = UIColor.white.cgColor
                circleView.layer.borderWidth = 4
                
                // 添加阴影
                circleView.layer.shadowColor = UIColor.black.cgColor
                circleView.layer.shadowOffset = CGSize(width: 0, height: 3)
                circleView.layer.shadowRadius = 8
                circleView.layer.shadowOpacity = 0.5
                
                annotationView?.frame = CGRect(x: 0, y: 0, width: size, height: size)
                annotationView?.addSubview(circleView)
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}

// MARK: - 主视图
struct QandAView: View {
    @Binding var searchContent: String
    
    // 数据状态管理
    @State private var questions: [Question] = []
    @State private var isLoading = false
    @State private var loadingError: String?
    
    // 排序和搜索
    @State private var selectedSortOption: QuestionSortOption = .newest
    
    // 问题详情和地图
    @State private var selectedQuestion: Question?
    @State private var showQuestionDetail = false
    @State private var currentLocationInfo: LocationInfo?
    
    // 统计信息
    @State private var statistics: QuestionsStatisticsResponse?
    
    // 搜索去抖动
    @State private var searchTask: Task<Void, Never>?
    
    // 定义网格列
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            // 全屏地图背景层（最底层）
            if showQuestionDetail, let locationInfo = currentLocationInfo {
                FullScreenMapView(locationInfo: locationInfo)
                    .ignoresSafeArea(.all)
                    .zIndex(0)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // 主内容区域：问答列表（中间层）
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        sortingView
                        contentView
                    }
                }
                .searchable(text: $searchContent, prompt: "搜索问答内容、标题或地点")
                .navigationBarHidden(true)
                .refreshable {
                    await refreshData()
                }
            }
            .background(.regularMaterial)
            .cornerRadius(32)
            .opacity(showQuestionDetail ? 0.0 : 1.0) // 显示地图时隐藏列表
            .animation(.easeInOut(duration: 0.3), value: showQuestionDetail)
            .zIndex(1)
            
            // 问题详情弹窗（顶层）
            if showQuestionDetail, let question = selectedQuestion {
                QuestionDetailModal.standard(
                    question: question,
                    isPresented: $showQuestionDetail,
                    onClose: {
                        closeQuestionDetailAndMap()
                    },
                    onAttachFile: {
                        print("附加文件功能")
                    }
                )
                .zIndex(20)
            }
        }
        .onAppear {
            loadInitialData()
        }
        .onChange(of: searchContent) { _, newValue in
            handleSearchChange(newValue)
        }
        .onChange(of: selectedSortOption) { _, _ in
            Task {
                await refreshData()
            }
        }
    }
    
    // MARK: - 视图组件
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("智能问答")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("浏览和回答社区问题")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            if let stats = statistics {
                HStack(spacing: 16) {
                    StatCard(title: "总问题", value: "\(stats.totalQuestions)", icon: "questionmark.bubble", color: .blue)
                    StatCard(title: "总回答", value: "\(stats.totalAnswers)", icon: "arrowshape.turn.up.left", color: .green)
                    StatCard(title: "活跃用户", value: "\(stats.activeUsers)", icon: "person.2", color: .orange)
                    StatCard(title: "平均回复", value: stats.averageRepliesPerQuestion, icon: "chart.bar", color: .purple)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    private var sortingView: some View {
        HStack(spacing:10) {
            
            Spacer()
            Text("排序方式")
                .font(.headline)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(QuestionSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedSortOption = option
                    }) {
                        HStack {
                            Text(option.displayName)
                            if selectedSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedSortOption.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, 24)
    }
    
    private var contentView: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载问答中...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if let error = loadingError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("加载失败")
                        .font(.headline)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("重新加载") {
                        loadInitialData()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if questions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "questionmark.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchContent.isEmpty ? "还没有问答" : "没找到相关问答")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if !searchContent.isEmpty {
                        Text("试试其他搜索词吧")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(questions) { question in
                        QuestionCard.detailed(
                            question: question,
                            onSelect: {
                                selectQuestion(question)
                            },
                            onLike: {
                                print("点赞问题: \(question.title)")
                            },
                            onAvatarTap: {
                                print("查看用户信息: \(question.username ?? "未知用户")")
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - 数据加载方法
    
    private func loadInitialData() {
        Task {
            await loadQuestions()
            await loadStatistics()
        }
    }
    
    private func loadQuestions() async {
        await MainActor.run {
            isLoading = true
            loadingError = nil
        }
        
        do {
            let response = try await NetworkManager.shared.getAllQuestions(
                searchQuery: searchContent,
                sortBy: selectedSortOption.sortBy,
                sortOrder: selectedSortOption.sortOrder
            )
            
            await MainActor.run {
                self.questions = response.questions.map { $0.toQuestion() }
                self.isLoading = false
                self.loadingError = nil
                
                // 添加头像数据检查
                print("QandA视图加载问题成功，检查头像数据:")
                for (index, question) in self.questions.prefix(3).enumerated() {
                    print("问题 \(index + 1): \(question.username ?? "无用户名") - 头像: \(question.avatarUrl ?? "无头像")")
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.loadingError = "加载失败: \(error.localizedDescription)"
                print("加载问答失败: \(error)")
            }
        }
    }
    
    private func loadStatistics() async {
        do {
            let stats = try await NetworkManager.shared.getQuestionsStatistics()
            await MainActor.run {
                self.statistics = stats
                print("加载统计信息成功")
            }
        } catch {
            print("加载统计信息失败: \(error)")
        }
    }
    
    private func refreshData() async {
        await loadQuestions()
        await loadStatistics()
    }
    
    // MARK: - 搜索处理
    
    private func handleSearchChange(_ searchText: String) {
        searchTask?.cancel()
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒延迟
            
            if !Task.isCancelled {
                await refreshData()
            }
        }
    }
    
    // MARK: - 问题选择和地图显示
    
    private func selectQuestion(_ question: Question) {
        print("选择问题: \(question.title)")
        
        selectedQuestion = question
        
        // 如果问题有位置信息，加载位置并显示地图+详情
        if question.locationID > 0 {
            Task {
                await loadLocationAndShowDetails(for: question)
            }
        } else {
            // 无位置信息：直接显示详情
            showQuestionDetail = true
        }
    }
    
    private func loadLocationAndShowDetails(for question: Question) async {
        do {
            // 直接从后端获取位置信息
            let locationDetail = try await NetworkManager.shared.getLocationInfo(locationId: question.locationID)
            let locationInfo = locationDetail.toLocationInfo()
            
            await MainActor.run {
                // 设置位置信息并显示地图和详情
                self.currentLocationInfo = locationInfo
                
                // 先显示地图
                withAnimation(.easeInOut(duration: 0.4)) {
                    // 地图会在ZStack中自动显示，因为currentLocationInfo不为nil且showQuestionDetail为true
                }
                
                // 延迟显示详情弹窗
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.showQuestionDetail = true
                    }
                }
            }
            
        } catch {
            print("获取位置信息失败: \(error)")
            
            // 使用默认位置信息
            let defaultLocation = getDefaultLocationInfo(for: question.locationID)
            
            await MainActor.run {
                self.currentLocationInfo = defaultLocation
                
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.showQuestionDetail = true
                }
            }
        }
    }
    
    // 获取默认位置信息
    private func getDefaultLocationInfo(for locationId: Int64) -> LocationInfo {
        switch locationId {
        case 1:
            return LocationInfo(id: 1, name: "华中农业大学博物馆", latitude: 30.475595, longitude: 114.357236)
        case 2:
            return LocationInfo(id: 2, name: "华中农业大学梧桐步行街", latitude: 30.474459, longitude: 114.349995)
        default:
            return LocationInfo(id: locationId, name: "默认位置", latitude: 30.4783, longitude: 114.3588)
        }
    }
    
    // 关闭问题详情和地图
    private func closeQuestionDetailAndMap() {
        print("关闭问题详情和地图")
        
        // 先关闭详情弹窗
        showQuestionDetail = false
        
        // 延迟清理状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.selectedQuestion = nil
            self.currentLocationInfo = nil
        }
    }
    
    // MARK: - 统计卡片组件
    
    struct StatCard: View {
        let title: String
        let value: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    QandAView(searchContent: .constant(""))
        .environmentObject(UserManager.shared)
}
