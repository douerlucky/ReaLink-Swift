//
//  ModelEditingView.swift
//  ReaLink
//
//  模型编辑相关的视图组件
//

import SwiftUI
import RealityKit

// MARK: - 模型选择区域

struct ModelSelectionSection: View
{
    @ObservedObject var modelManager: ModelManager
    @Binding var showModelTypePicker: Bool
    @Binding var isAddingModel: Bool
    
    var body: some View
    {
        VStack(spacing: 20)
        {
            // 标题
            HStack
            {
                Text("模型类型")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            // 模型类型选择
            VStack(alignment: .center, spacing: 12)
            {
                Button(action: { showModelTypePicker = true })
                {
                    VStack(spacing: 8)
                    {
                        Model3DPreview(modelType: modelManager.selectedModelType)
                            .frame(width: 80, height: 80)

                        Text(modelTypeName(modelManager.selectedModelType))
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 120, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.blue.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 2)
                )
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                
                Text("点击选择模型类型")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            // 添加模型按钮
            Button(action: addModelAction)
            {
                HStack
                {
                    Image(systemName: "plus.circle")
                    Text("添加模型")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            
            // 提示信息
            VStack(alignment: .leading, spacing: 8)
            {
                Text("💡 操作提示")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)

                Text("• 点击上方卡片选择模型类型\n• 点击「添加模型」在场景中放置\n• 放置后可拖动调整位置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(12)
            .background(.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private func addModelAction()
    {
        guard !isAddingModel
        else
        {
            print("⚠️ 正在处理添加操作,跳过重复请求")
            return
        }

        print("添加模型按钮被点击,当前选择类型: \(modelManager.selectedModelType.rawValue)")

        isAddingModel = true

        // 🔥 修复：Sign模型使用默认brown，其他模型使用当前选择的颜色
        let finalColor: Color
        if modelManager.selectedModelType == .sign {
            finalColor = .brown
        } else {
            finalColor = modelManager.cubeColor
        }
        
        let colorComponents = finalColor.cgColor?.components ?? [0, 0, 1, 1]
        let userInfo: [String: Any] = [
            "modelType": modelManager.selectedModelType.rawValue,
            "color": [
                "red": Float(colorComponents[0]),
                "green": Float(colorComponents[1]),
                "blue": Float(colorComponents[2]),
                "alpha": Float(colorComponents.count > 3 ? colorComponents[3] : 1.0),
            ],
            "size": modelManager.cubeSize,
            "opacity": modelManager.modelOpacity,
        ]

        NotificationCenter.default.post(
            name: NSNotification.Name("AddCube"),
            object: nil,
            userInfo: userInfo
        )

        print("已发送添加模型通知")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            isAddingModel = false
            print("添加模型处理标志已重置")
        }
    }
    
    func modelTypeName(_ type: ModelType) -> String
    {
        switch type
        {
        case .cube: return "立方体"
        case .sphere: return "球体"
        case .cylinder: return "圆柱体"
        case .cone: return "锥体"
        case .capsule: return "胶囊"
        case .sign: return "告示牌"
        }
    }
}

// MARK: - 模型编辑区域

struct ModelEditSection: View
{
    @Binding var selectedModelForEdit: PlacedModel?
    @Binding var editModelColor: Color
    @Binding var modelRotationX: Double
    @Binding var modelRotationY: Double
    @Binding var modelRotationZ: Double
    @Binding var selectedModelText: String
    
    @ObservedObject var userManager: UserManager
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text("模型编辑")
                .font(.headline)
                .foregroundStyle(.primary)

            if let selectedModel = selectedModelForEdit
            {
                let currentUserId = userManager.getUserId()
                let canEdit = selectedModel.canUserManipulate(currentUserId: currentUserId)

                if canEdit
                {
                    EditableModelInterface(
                        selectedModel: selectedModel,
                        editModelColor: $editModelColor,
                        modelRotationX: $modelRotationX,
                        modelRotationY: $modelRotationY,
                        modelRotationZ: $modelRotationZ,
                        selectedModelText: $selectedModelText
                    )
                }
                else
                {
                    NoPermissionModelInterface(selectedModel: selectedModel)
                }
            }
            else
            {
                NoModelSelectedInterface()
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - 有权限的编辑界面

struct EditableModelInterface: View
{
    let selectedModel: PlacedModel
    @Binding var editModelColor: Color
    @Binding var modelRotationX: Double
    @Binding var modelRotationY: Double
    @Binding var modelRotationZ: Double
    @Binding var selectedModelText: String
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            // 选中状态指示
            HStack
            {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已选中: \(modelTypeName(selectedModel.type))")
                    .foregroundColor(.green)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(8)
            .background(.green.opacity(0.1))
            .cornerRadius(8)

            // 颜色修改区域
            if selectedModel.type == .sign
            {
                SignModelEditInterface(
                    selectedModel: selectedModel,
                    selectedModelText: $selectedModelText,
                    modelRotationX: $modelRotationX,
                    modelRotationY: $modelRotationY,
                    modelRotationZ: $modelRotationZ
                )
            }
            else
            {
                GeneralModelEditInterface(
                    selectedModel: selectedModel,
                    editModelColor: $editModelColor,
                    modelRotationX: $modelRotationX,
                    modelRotationY: $modelRotationY,
                    modelRotationZ: $modelRotationZ
                )
            }

            // 复制和删除按钮
            HStack(spacing: 12)
            {
                Button(action: {
                    handleModelDuplicate(selectedModel)
                })
                {
                    HStack(spacing: 4)
                    {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                        Text("复制")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)

                Button(action: {
                    handleModelDelete(selectedModel)
                })
                {
                    HStack(spacing: 4)
                    {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("删除")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(.green.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func handleModelDuplicate(_ model: PlacedModel) {
        print("RealityWindow: 复制模型 \(model.id)")
        
        // 🔥 修复：使用原模型的实际位置和缩放
        let originalPosition = model.entity.position
        let originalScale = model.entity.scale
        let originalRotation = model.entity.orientation
        
        // 计算偏移位置（稍微偏移避免重叠）
        let offsetPosition = SIMD3<Float>(
            originalPosition.x + 0.2,
            originalPosition.y,
            originalPosition.z
        )
        
        // 🔥 修复：获取实际的颜色组件
        let colorComponents: [CGFloat]
        if let cgColor = model.color.cgColor,
           let components = cgColor.components,
           components.count >= 3 {
            colorComponents = components
        } else {
            // 回退到默认蓝色
            colorComponents = [0.0, 0.0, 1.0, 1.0]
        }
        
        // 🔥 修复：传递完整的属性信息
        let userInfo: [String: Any] = [
            "modelType": model.type.rawValue,
            "position": [
                "x": offsetPosition.x,
                "y": offsetPosition.y,
                "z": offsetPosition.z
            ],
            "scale": [
                "x": originalScale.x,
                "y": originalScale.y,
                "z": originalScale.z
            ],
            "rotation": [
                "x": originalRotation.vector.x,
                "y": originalRotation.vector.y,
                "z": originalRotation.vector.z,
                "w": originalRotation.vector.w
            ],
            "color": [
                "red": Float(colorComponents[0]),
                "green": Float(colorComponents[1]),
                "blue": Float(colorComponents[2]),
                "alpha": Float(colorComponents.count > 3 ? colorComponents[3] : 1.0)
            ],
            "size": model.size,
            "opacity": model.opacity,
            "text": model.text ?? "" // 🔥 添加文本支持
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("AddCube"),
            object: nil,
            userInfo: userInfo
        )
        
        print("✅ 已发送复制模型通知，包含完整属性")
        print("   - 原始位置: \(originalPosition)")
        print("   - 复制位置: \(offsetPosition)")
        print("   - 原始缩放: \(originalScale)")
        print("   - 原始旋转: \(originalRotation)")
        print("   - 颜色: R:\(colorComponents[0]) G:\(colorComponents[1]) B:\(colorComponents[2])")
        print("   - 大小: \(model.size)")
        print("   - 不透明度: \(model.opacity)")
        if let text = model.text, !text.isEmpty {
            print("   - 文本: \(text)")
        }
    }
    
    private func handleModelDelete(_ model: PlacedModel)
    {
        print("RealityWindow: 删除模型 \(model.id)")

        let userInfo: [String: Any] = [
            "action": "delete",
            "modelId": model.id.uuidString,
        ]

        NotificationCenter.default.post(
            name: NSNotification.Name("ModelEditOperation"),
            object: nil,
            userInfo: userInfo
        )

        print("已发送删除通知")
    }
    
    func modelTypeName(_ type: ModelType) -> String
    {
        switch type
        {
        case .cube: return "立方体"
        case .sphere: return "球体"
        case .cylinder: return "圆柱体"
        case .cone: return "锥体"
        case .capsule: return "胶囊"
        case .sign: return "告示牌"
        }
    }
}

// MARK: - Sign模型专用编辑界面

struct SignModelEditInterface: View
{
    let selectedModel: PlacedModel
    @Binding var selectedModelText: String
    @Binding var modelRotationX: Double
    @Binding var modelRotationY: Double
    @Binding var modelRotationZ: Double
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            // 文本输入区域
            VStack(alignment: .leading, spacing: 8)
            {
                Text("告示牌文字")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("输入要显示的文字", text: $selectedModelText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onChange(of: selectedModelText)
                    { newText in
                        updateSignModelText(selectedModel, newText: newText)
                    }
                    .onAppear
                    {
                        selectedModelText = selectedModel.text ?? ""
                    }

                Text("提示:文字会显示在告示牌的中央位置")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(.blue.opacity(0.05))
            .cornerRadius(8)

            // 显示默认材质信息
            VStack(alignment: .leading, spacing: 8)
            {
                Text("材质设置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack
                {
                    Image(systemName: "paintbrush.pointed.fill")
                        .foregroundColor(.brown)
                    Text("使用默认木质材质")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // XYZ旋转控制区域
            RotationControlInterface(
                selectedModel: selectedModel,
                modelRotationX: $modelRotationX,
                modelRotationY: $modelRotationY,
                modelRotationZ: $modelRotationZ
            )
        }
    }
    
    private func updateSignModelText(_ model: PlacedModel, newText: String)
    {
        print("RealityWindow: 更新Sign模型文字 \(model.id) -> \(newText)")

        let userInfo: [String: Any] = [
            "action": "updateText",
            "modelId": model.id.uuidString,
            "text": newText,
        ]

        NotificationCenter.default.post(
            name: NSNotification.Name("ModelEditOperation"),
            object: nil,
            userInfo: userInfo
        )

        print("已发送文字更新通知")
    }
}

// MARK: - 通用模型编辑界面

struct GeneralModelEditInterface: View
{
    let selectedModel: PlacedModel
    @Binding var editModelColor: Color
    @Binding var modelRotationX: Double
    @Binding var modelRotationY: Double
    @Binding var modelRotationZ: Double
    
    // 🔥 新增：用于跟踪上次的颜色，避免重复触发
    @State private var lastColor: Color?
    
    var body: some View
    {
        HStack(alignment: .top, spacing: 16)
        {
            // 颜色修改区域
            VStack(alignment: .leading, spacing: 8)
            {
                Text("颜色")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ColorPicker("", selection: $editModelColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 120, height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(editModelColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    )
                    .onChange(of: editModelColor)
                    { oldColor, newColor in
                        // 🔥 关键修复：检查颜色是否真的改变了
                        // 避免在模型切换时触发
                        if let last = lastColor, colorsAreEqual(last, newColor) {
                            print("⏭️ 颜色未实际改变，跳过更新")
                            return
                        }
                        
                        // 🔥 延迟执行，让模型切换的标志位有时间生效
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            // 再次检查，确保不是在模型切换过程中
                            if self.editModelColor == newColor {
                                print("🎨 用户主动修改颜色: \(selectedModel.id.uuidString.prefix(8))")
                                handleModelColorChange(selectedModel, newColor: newColor)
                                lastColor = newColor
                            }
                        }
                    }
                    .onAppear {
                        // 初始化时记录颜色
                        lastColor = editModelColor
                    }
            }

            // XYZ旋转控制区域
            RotationControlInterface(
                selectedModel: selectedModel,
                modelRotationX: $modelRotationX,
                modelRotationY: $modelRotationY,
                modelRotationZ: $modelRotationZ
            )
        }
    }
    
    // 🔥 新增：颜色比较函数（考虑浮点数精度）
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        guard let components1 = color1.cgColor?.components,
              let components2 = color2.cgColor?.components,
              components1.count >= 3,
              components2.count >= 3 else {
            return false
        }
        
        let threshold: CGFloat = 0.001
        return abs(components1[0] - components2[0]) < threshold &&
               abs(components1[1] - components2[1]) < threshold &&
               abs(components1[2] - components2[2]) < threshold
    }
    
    private func handleModelColorChange(_ model: PlacedModel, newColor: Color)
    {
        print("🔧 RealityWindow: 变更模型颜色 \(model.id.uuidString.prefix(8))")

        let colorComponents = newColor.cgColor?.components ?? [0, 0, 1, 1]
        let userInfo: [String: Any] = [
            "action": "changeColor",
            "modelId": model.id.uuidString,
            "color": [
                "red": Float(colorComponents[0]),
                "green": Float(colorComponents[1]),
                "blue": Float(colorComponents[2]),
                "alpha": Float(colorComponents.count > 3 ? colorComponents[3] : 1.0),
            ],
        ]

        NotificationCenter.default.post(
            name: NSNotification.Name("ModelEditOperation"),
            object: nil,
            userInfo: userInfo
        )

        print("✅ 已发送颜色变更通知")
    }
}

// MARK: - 旋转控制界面组件

struct RotationControlInterface: View
{
    let selectedModel: PlacedModel
    @Binding var modelRotationX: Double
    @Binding var modelRotationY: Double
    @Binding var modelRotationZ: Double
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            Text("旋转")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8)
            {
                // X轴
                HStack(spacing: 8)
                {
                    Text("X")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .frame(width: 12)

                    Slider(value: $modelRotationX, in: 0 ... 360, step: 1)
                        .accentColor(.red)
                        .onChange(of: modelRotationX)
                        { newValue in
                            handleModelRotateWithAngle(selectedModel, axis: "x", angle: newValue)
                        }

                    Text("\(Int(modelRotationX))°")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                        .frame(width: 30, alignment: .trailing)
                }

                // Y轴
                HStack(spacing: 8)
                {
                    Text("Y")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .frame(width: 12)

                    Slider(value: $modelRotationY, in: 0 ... 360, step: 1)
                        .accentColor(.green)
                        .onChange(of: modelRotationY)
                        { newValue in
                            handleModelRotateWithAngle(selectedModel, axis: "y", angle: newValue)
                        }

                    Text("\(Int(modelRotationY))°")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                        .frame(width: 30, alignment: .trailing)
                }

                // Z轴
                HStack(spacing: 8)
                {
                    Text("Z")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(width: 12)

                    Slider(value: $modelRotationZ, in: 0 ... 360, step: 1)
                        .accentColor(.blue)
                        .onChange(of: modelRotationZ)
                        { newValue in
                            handleModelRotateWithAngle(selectedModel, axis: "z", angle: newValue)
                        }

                    Text("\(Int(modelRotationZ))°")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                        .frame(width: 30, alignment: .trailing)
                }
            }
            .padding(8)
            .background(.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func handleModelRotateWithAngle(_ model: PlacedModel, axis: String, angle: Double)
    {
        print("🔧 设置模型绝对旋转: \(model.id), 轴: \(axis), 角度: \(angle)°")

        let eulerRadians = SIMD3<Float>(
            Float(modelRotationX * .pi / 180),
            Float(modelRotationY * .pi / 180),
            Float(modelRotationZ * .pi / 180)
        )

        let modelRotation = ModelRotation(eulerAngles: eulerRadians)

        let userInfo: [String: Any] = [
            "action": "setAbsoluteRotation",
            "modelId": model.id.uuidString,
            "quaternion": [
                "x": modelRotation.x,
                "y": modelRotation.y,
                "z": modelRotation.z,
                "w": modelRotation.w,
            ],
        ]

        NotificationCenter.default.post(
            name: NSNotification.Name("ModelEditOperation"),
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - 无权限的显示界面

struct NoPermissionModelInterface: View
{
    let selectedModel: PlacedModel
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 16)
        {
            // 权限提示状态指示
            HStack
            {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4)
                {
                    Text("无编辑权限")
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("这不是你放置的模型,无法进行更改")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                Spacer()
            }
            .padding(12)
            .background(.red.opacity(0.1))
            .cornerRadius(12)

            // 显示模型归属信息
            VStack(alignment: .leading, spacing: 12)
            {
                Text("模型信息")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12)
                {
                    // ✅ 显示真实头像
                    if let avatarUrl = selectedModel.avatarUrl, !avatarUrl.isEmpty {
                        AsyncImage(url: URL(string: avatarUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 4)
                    {
                        Text("模型所有者")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // ✅ 显示真实用户名
                        Text(selectedModel.getDisplayUsername())
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("类型: \(modelTypeName(selectedModel.type))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(.gray.opacity(0.1))
                .cornerRadius(12)
            }

            // 权限说明
            VStack(alignment: .leading, spacing: 8)
            {
                Text("权限说明")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)

                Text("• 只能编辑自己放置的模型\n• 可以查看其他用户的模型\n• 无法删除或修改他人的模型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(16)
            .cornerRadius(12)
        }
        .padding(20)
        .background(.red.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    func modelTypeName(_ type: ModelType) -> String
    {
        switch type
        {
        case .cube: return "立方体"
        case .sphere: return "球体"
        case .cylinder: return "圆柱体"
        case .cone: return "锥体"
        case .capsule: return "胶囊"
        case .sign: return "告示牌"
        }
    }
}

// MARK: - 未选中模型的界面

struct NoModelSelectedInterface: View
{
    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack
            {
                Image(systemName: "hand.tap")
                    .foregroundColor(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4)
                {
                    Text("点击场景中的模型进行编辑")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("选中后可进行颜色修改、旋转、复制和删除操作")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 操作说明
            VStack(alignment: .leading, spacing: 8)
            {
                Text("操作说明")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)

                Text("• 点击场景中的3D模型进行选择\n• 拖动模型可移动位置\n• 双指捏合可缩放模型\n• 选中后在右侧进行精确编辑")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(20)
        .background(.blue.opacity(0.05))
        .cornerRadius(16)
    }
}
