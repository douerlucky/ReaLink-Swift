//import SwiftUI
//import RealityKit
//import RealityKitContent
//
//struct ARImmersiveView: View {
//    @State private var signText: String = "3D模型Demo"
//    @State private var isEditing: Bool = false
//    @State private var tempText: String = ""
//    @State private var showAddMenu: Bool = false
//    @State private var entityCounter: Int = 0
//    @State private var selectedEntity: Entity?
//    @State private var mainAnchor: AnchorEntity?
//    @State private var draggedEntity: Entity?
//    @State private var initialDragPosition: SIMD3<Float> = .zero
//    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
//    @Environment(\.openWindow) var openWindow
//    
//    var body: some View {
//        RealityView { content, attachments in
//            // 设置场景
//            setupScene(content: content)
//            
//            // 创建头部锚点用于退出按钮和加号按钮
//            let headAnchor = AnchorEntity(.head)
//            content.add(headAnchor)
//            
//            // 将退出按钮附加到头部锚点（右上角）
//            if let exitButtonAttachment = attachments.entity(for: "exitButton") {
//                exitButtonAttachment.position = SIMD3(x: 0.6, y: 0.48, z: -0.7)
//                headAnchor.addChild(exitButtonAttachment)
//            }
//            
//            // 将加号按钮附加到头部锚点（左下角）
//            if let addButtonAttachment = attachments.entity(for: "addButton") {
//                addButtonAttachment.position = SIMD3(x: -0.6, y: -0.48, z: -0.7)
//                headAnchor.addChild(addButtonAttachment)
//            }
//            
//            // 将添加菜单附加到头部锚点（左下角稍上方）
//            if let addMenuAttachment = attachments.entity(for: "addMenu") {
//                addMenuAttachment.position = SIMD3(x: -0.6, y: -0.3, z: -0.7)
//                headAnchor.addChild(addMenuAttachment)
//            }
//            
//            // 创建编辑窗口的锚点（位置稍微调整）
//            let editAnchor = AnchorEntity(world: SIMD3<Float>(0.6, 1.2, -1.8))
//            content.add(editAnchor)
//            
//            if let editWindowAttachment = attachments.entity(for: "editWindow") {
//                editWindowAttachment.position = SIMD3<Float>(0, 0, 0)
//                editAnchor.addChild(editWindowAttachment)
//            }
//            
//        } update: { content, attachments in
//            // 更新选中实体的文字内容
//            if let selected = selectedEntity {
//                updateSignText(for: selected, text: signText)
//            }
//            
//            // 更新编辑窗口的可见性
//            if let editWindow = attachments.entity(for: "editWindow") {
//                editWindow.isEnabled = isEditing
//            }
//            
//            // 更新添加菜单的可见性
//            if let addMenu = attachments.entity(for: "addMenu") {
//                addMenu.isEnabled = showAddMenu
//            }
//        } attachments: {
//            // 创建退出按钮作为attachment
//            Attachment(id: "exitButton") {
//                Button("退出实景探索") {
//                    Task {
//                        openWindow(id: "mainWindow")
//                        try? await Task.sleep(nanoseconds: 100_000_000)
//                        await dismissImmersiveSpace()
//                    }
//                }
//                .buttonStyle(.bordered)
//                .padding()
//                .glassBackgroundEffect()
//            }
//            
//            // 创建加号按钮
//            Attachment(id: "addButton") {
//                Button(action: {
//                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                        showAddMenu.toggle()
//                    }
//                }) {
//                    Image(systemName: "plus.circle")
//                        .font(.system(size: 44))
//                }
//                .buttonStyle(.plain)
//                .padding()
//                .glassBackgroundEffect()
//            }
//            
//            // 创建添加菜单
//            Attachment(id: "addMenu") {
//                VStack(spacing: 15) {
//                    Button(action: {
//                        addSign()
//                        withAnimation {
//                            showAddMenu = false
//                        }
//                    }) {
//                        HStack {
//                            Image(systemName: "signpost.right.fill")
//                                .font(.title2)
//                            Text("添加告示牌")
//                                .font(.title3)
//                        }
//                        .padding()
//                        .frame(width: 200)
//                    }
//                    .buttonStyle(.borderedProminent)
//                    
//                    Button(action: {
//                        addCube()
//                        withAnimation {
//                            showAddMenu = false
//                        }
//                    }) {
//                        HStack {
//                            Image(systemName: "cube.fill")
//                                .font(.title2)
//                            Text("添加模型")
//                                .font(.title3)
//                        }
//                        .padding()
//                        .frame(width: 200)
//                    }
//                    .buttonStyle(.borderedProminent)
//                }
//                .padding()
//                .background(.ultraThickMaterial)
//                .cornerRadius(15)
//                .scaleEffect(showAddMenu ? 1 : 0.1)
//                .opacity(showAddMenu ? 1 : 0)
//                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAddMenu)
//            }
//            
//            // 编辑窗口始终创建，通过isEnabled控制显示
//            Attachment(id: "editWindow") {
//                VStack(spacing: 20) {
//                    Text("编辑告示牌文字")
//                        .font(.largeTitle)
//                        .fontWeight(.bold)
//                        .foregroundColor(.white)
//                    
//                    TextField("输入文字", text: $tempText)
//                        .textFieldStyle(.roundedBorder)
//                        .font(.title)
//                        .frame(width: 300)
//                    
//                    HStack(spacing: 30) {
//                        Button("取消") {
//                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                tempText = signText
//                                isEditing = false
//                            }
//                        }
//                        .buttonStyle(.bordered)
//                        .controlSize(.large)
//                        
//                        Button("确定") {
//                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                signText = tempText
//                                isEditing = false
//                            }
//                        }
//                        .buttonStyle(.borderedProminent)
//                        .controlSize(.large)
//                    }
//                    
//                    Text("点击空白处关闭")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .padding(.top, 5)
//                }
//                .padding(40)
//                .background(.ultraThickMaterial)
//                .cornerRadius(20)
//                .shadow(radius: 20)
//                .scaleEffect(isEditing ? 1 : 0.1)  // 缩放动画
//                .opacity(isEditing ? 1 : 0)        // 透明度动画
//                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditing)
//            }
//        }
//        // 添加拖动手势来移动实体
//        .gesture(
//            DragGesture()
//                .targetedToAnyEntity()
//                .onChanged { value in
//                    handleDragChanged(value: value)
//                }
//                .onEnded { value in
//                    handleDragEnded(value: value)
//                }
//        )
//        // 使用长按手势
//        .gesture(
//            LongPressGesture(minimumDuration: 0.8) // 0.8秒长按
//                .targetedToAnyEntity()
//                .onEnded { value in
//                    print("长按了实体: \(value.entity.name ?? "无名称")")
//                    
//                    // 检查是否是告示牌的任何部分
//                    var isSignPart = false
//                    var currentEntity: Entity? = value.entity
//                    var rootSignEntity: Entity?
//                    
//                    // 向上遍历父实体
//                    while currentEntity != nil {
//                        if currentEntity?.name.hasPrefix("mainSign") == true {
//                            isSignPart = true
//                            rootSignEntity = currentEntity
//                            break
//                        }
//                        currentEntity = currentEntity?.parent
//                    }
//                    
//                    // 也检查实体名称
//                    if value.entity.name.hasPrefix("mainSign") == true ||
//                       value.entity.name == "signText" ||
//                        value.entity.parent?.name.hasPrefix("mainSign") == true {
//                        isSignPart = true
//                        if rootSignEntity == nil {
//                            rootSignEntity = value.entity.name.hasPrefix("mainSign") == true ? value.entity : value.entity.parent
//                        }
//                    }
//                    
//                    if isSignPart, let sign = rootSignEntity {
//                        print("长按了告示牌，显示编辑窗口")
//                        selectedEntity = sign
//                        
//                        // 获取当前告示牌的文字
//                        if let textEntity = sign.children.first(where: { $0.name == "signText" }) as? ModelEntity,
//                           let textComponent = textEntity.components[ModelComponent.self],
//                           let currentText = getTextFromEntity(sign) {
//                            signText = currentText
//                            tempText = currentText
//                        }
//                        
//                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
//                            isEditing = true
//                        }
//                    }
//                }
//        )
//        // 添加点击手势来关闭编辑窗口和添加菜单
//        .gesture(
//            SpatialTapGesture()
//                .targetedToAnyEntity()
//                .onEnded { value in
//                    // 如果编辑窗口打开，且点击的不是告示牌，则关闭编辑窗口
//                    if isEditing {
//                        var isSignPart = false
//                        var currentEntity: Entity? = value.entity
//                        
//                        while currentEntity != nil {
//                            if currentEntity?.name.hasPrefix("mainSign") == true {
//                                isSignPart = true
//                                break
//                            }
//                            currentEntity = currentEntity?.parent
//                        }
//                        
//                        if !isSignPart && value.entity.name.hasPrefix("mainSign") != true &&
//                           value.entity.name != "signText" {
//                            print("点击了空白处，关闭编辑窗口")
//                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                isEditing = false
//                            }
//                        }
//                    }
//                    
//                    // 如果添加菜单打开，点击其他地方关闭它
//                    if showAddMenu {
//                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                            showAddMenu = false
//                        }
//                    }
//                }
//        )
//    }
//    
//    // 处理拖动开始和变化
//    private func handleDragChanged(value: EntityTargetValue<DragGesture.Value>) {
//        // 找到可拖动的根实体
//        var targetEntity: Entity? = value.entity
//        var rootEntity: Entity?
//        
//        // 向上查找告示牌或立方体的根实体
//        while targetEntity != nil {
//            if targetEntity?.name.hasPrefix("mainSign") == true ||
//               targetEntity?.name.hasPrefix("cube_") == true {
//                rootEntity = targetEntity
//                break
//            }
//            targetEntity = targetEntity?.parent
//        }
//        
//        // 如果点击的是文字实体，找到它的父实体（告示牌）
//        if value.entity.name == "signText" {
//            rootEntity = value.entity.parent
//        }
//        
//        // 如果找到了可拖动的实体
//        if let entity = rootEntity {
//            // 如果是新的拖动操作，记录初始位置
//            if draggedEntity == nil {
//                draggedEntity = entity
//                initialDragPosition = entity.position
//                
//                // 添加视觉反馈：略微放大
//                entity.scale = SIMD3<Float>(1.1, 1.1, 1.1)
//                
//            }
//            
//            // 计算新位置
//            if draggedEntity == entity {
//                let translation = value.convert(value.translation3D, from: .local, to: .scene)
//                entity.position = initialDragPosition + SIMD3<Float>(
//                    Float(translation.x),
//                    Float(translation.y),
//                    Float(translation.z)
//                )
//            }
//        }
//    }
//    
//    // 处理拖动结束
//    private func handleDragEnded(value: EntityTargetValue<DragGesture.Value>) {
//        if let entity = draggedEntity {
//            // 恢复原始缩放
//            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                entity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
//            }
//            
//            // 重置拖动状态
//            draggedEntity = nil
//            initialDragPosition = .zero
//            
//            print("实体 \(entity.name ?? "未命名") 移动到新位置: \(entity.position)")
//        }
//    }
//    
//    private func setupScene(content: RealityViewContent) {
//        let anchor = AnchorEntity(world: .zero)
//        anchor.name = "mainAnchor"
//        content.add(anchor)
//        self.mainAnchor = anchor  // 保存锚点引用
//        
//        // 初始化时添加一个告示牌
//        Task {
//            if let signEntity = try? await Entity(named: "sign", in: realityKitContentBundle) {
//                signEntity.position = SIMD3<Float>(0, 1, -2.0)
//                signEntity.name = "mainSign_0"
//                
//                // 确保实体有碰撞组件和输入目标组件
//                signEntity.generateCollisionShapes(recursive: true)
//                signEntity.components.set(InputTargetComponent(allowedInputTypes: .all))
//                
//                // 为所有子实体也添加输入目标组件
//                signEntity.children.forEach { child in
//                    child.components.set(InputTargetComponent(allowedInputTypes: .all))
//                }
//                
//                let textEntity = createTextEntity(text: signText)
//                signEntity.addChild(textEntity)
//                
//                anchor.addChild(signEntity)
//                
//                print("初始告示牌设置完成")
//            }
//        }
//    }
//    
//    private func addSign() {
//        guard let anchor = mainAnchor else { return }
//        
//        entityCounter += 1
//        
//        Task {
//            if let signEntity = try? await Entity(named: "sign", in: realityKitContentBundle) {
//                // 随机位置，避免重叠
//                let randomX = Float.random(in: -1...1)
//                let randomZ = Float.random(in: -3...(-1.5))
//                signEntity.position = SIMD3<Float>(randomX, 1, randomZ)
//                signEntity.name = "mainSign_\(entityCounter)"
//                
//                // 确保实体有碰撞组件和输入目标组件
//                signEntity.generateCollisionShapes(recursive: true)
//                signEntity.components.set(InputTargetComponent(allowedInputTypes: .all))
//                
//                // 为所有子实体也添加输入目标组件
//                signEntity.children.forEach { child in
//                    child.components.set(InputTargetComponent(allowedInputTypes: .all))
//                }
//                
//                let textEntity = createTextEntity(text: "新告示牌 \(entityCounter)")
//                signEntity.addChild(textEntity)
//                
//                // 保存文字到实体
//                signEntity.components.set(TextComponent(text: "新告示牌 \(entityCounter)"))
//                
//                anchor.addChild(signEntity)
//                
//                print("添加了新告示牌: mainSign_\(entityCounter)")
//            }
//        }
//    }
//    
//    private func addCube() {
//        guard let anchor = mainAnchor else { return }
//        
//        entityCounter += 1
//        
//        // 创建立方体
//        let cubeMesh = MeshResource.generateBox(size: 0.2)
//        var material = SimpleMaterial()
//        material.color = .init(tint: UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0))
//        
//        let cubeEntity = ModelEntity(mesh: cubeMesh, materials: [material])
//        
//        // 随机位置
//        let randomX = Float.random(in: -1...1)
//        let randomY = Float.random(in: 0.5...1.5)
//        let randomZ = Float.random(in: -3...(-1.5))
//        cubeEntity.position = SIMD3<Float>(randomX, randomY, randomZ)
//        cubeEntity.name = "cube_\(entityCounter)"
//        
//        // 添加碰撞和输入组件
//        cubeEntity.generateCollisionShapes(recursive: false)
//        cubeEntity.components.set(InputTargetComponent(allowedInputTypes: .all))
//        
//        anchor.addChild(cubeEntity)
//        
//        print("添加了新立方体: cube_\(entityCounter)")
//    }
//    
//    private func createTextEntity(text: String) -> ModelEntity {
//        let textMesh = MeshResource.generateText(
//            text,
//            extrusionDepth: 0.01,
//            font: .systemFont(ofSize: 0.15, weight: .bold),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byWordWrapping
//        )
//        
//        var material = SimpleMaterial()
//        material.color = .init(tint: .white, texture: nil)
//        let textEntity = ModelEntity(mesh: textMesh, materials: [material])
//        
//        // 计算文字边界并居中
//        let textBounds = textEntity.visualBounds(relativeTo: textEntity)
//        textEntity.position = SIMD3<Float>(-textBounds.center.x, -textBounds.center.y, 0.05)
//        textEntity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
//        textEntity.name = "signText"
//        
//        textEntity.generateCollisionShapes(recursive: false)
//        textEntity.components.set(InputTargetComponent(allowedInputTypes: .all))
//        
//        return textEntity
//    }
//    
//    private func updateSignText(for entity: Entity, text: String) {
//        guard let textEntity = entity.children.first(where: { $0.name == "signText" }) as? ModelEntity else { return }
//        
//        let newTextMesh = MeshResource.generateText(
//            text,
//            extrusionDepth: 0.01,
//            font: .systemFont(ofSize: 0.15, weight: .bold),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byWordWrapping
//        )
//        
//        textEntity.model?.mesh = newTextMesh
//        let textBounds = textEntity.visualBounds(relativeTo: textEntity)
//        textEntity.position = SIMD3<Float>(-textBounds.center.x, -textBounds.center.y, 0.05)
//        
//        // 保存文字到父实体
//        entity.components.set(TextComponent(text: text))
//    }
//    
//    private func updateSignText(in content: RealityViewContent) {
//        content.entities.forEach { entity in
//            if let anchor = entity as? AnchorEntity {
//                anchor.children.forEach { child in
//                    if child.name.hasPrefix("mainSign") == true {
//                        updateTextInEntity(child)
//                    }
//                }
//            }
//        }
//    }
//    
//    private func updateTextInEntity(_ entity: Entity) {
//        guard let textEntity = entity.children.first(where: { $0.name == "signText" }) as? ModelEntity else { return }
//        
//        let newTextMesh = MeshResource.generateText(
//            signText,
//            extrusionDepth: 0.01,
//            font: .systemFont(ofSize: 0.15, weight: .bold),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byWordWrapping
//        )
//        
//        textEntity.model?.mesh = newTextMesh
//        let textBounds = textEntity.visualBounds(relativeTo: textEntity)
//        textEntity.position = SIMD3<Float>(-textBounds.center.x, -textBounds.center.y, 0.05)
//    }
//    
//    private func getTextFromEntity(_ entity: Entity) -> String? {
//        if let textComponent = entity.components[TextComponent.self] {
//            return textComponent.text
//        }
//        return nil
//    }
//}
//
//// 自定义组件：用于追踪悬停状态
//struct HoverEffectComponent: Component {
//    var isHovered: Bool = false
//}
//
//// 文字组件：用于保存告示牌的文字
//struct TextComponent: Component {
//    var text: String
//}
//
//#Preview(immersionStyle: .mixed) {
//    ARImmersiveView()
//        .environment(AppModel())
//}
