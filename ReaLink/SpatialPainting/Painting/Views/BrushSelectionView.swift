/*
画笔选择和配置界面
*/

import SwiftUI

struct BrushSelectionView: View {
    @EnvironmentObject var paintingConfig: PaintingConfig
    @State private var showColorPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("画笔设置")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 画笔类型选择
            VStack(alignment: .leading, spacing: 8) {
                Text("画笔类型")
                    .font(.headline)
                
                HStack {
                    ForEach(BrushType.allCases, id: \.self) { brushType in
                        Button(action: {
                            paintingConfig.brushConfig.type = brushType
                        }) {
                            Text(brushType.displayName)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    paintingConfig.brushConfig.type == brushType 
                                    ? Color.blue : Color.gray.opacity(0.3)
                                )
                                .foregroundColor(
                                    paintingConfig.brushConfig.type == brushType 
                                    ? .white : .primary
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // 画笔模式选择
            VStack(alignment: .leading, spacing: 8) {
                Text("绘画模式")
                    .font(.headline)
                
                HStack {
                    ForEach(BrushMode.allCases, id: \.self) { mode in
                        Button(action: {
                            paintingConfig.brushConfig.mode = mode
                        }) {
                            Text(mode.displayName)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    paintingConfig.brushConfig.mode == mode 
                                    ? Color.green : Color.gray.opacity(0.3)
                                )
                                .foregroundColor(
                                    paintingConfig.brushConfig.mode == mode 
                                    ? .white : .primary
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Shader类型选择
            VStack(alignment: .leading, spacing: 8) {
                Text("材质类型")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(ShaderType.allCases, id: \.self) { shader in
                        Button(action: {
                            paintingConfig.brushConfig.shader = shader
                        }) {
                            Text(shader.displayName)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    paintingConfig.brushConfig.shader == shader 
                                    ? Color.purple : Color.gray.opacity(0.3)
                                )
                                .foregroundColor(
                                    paintingConfig.brushConfig.shader == shader 
                                    ? .white : .primary
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // 画笔大小调节
            VStack(alignment: .leading, spacing: 8) {
                Text("画笔大小: \(String(format: "%.3f", paintingConfig.brushConfig.size))")
                    .font(.headline)
                
                Slider(
                    value: Binding(
                        get: { paintingConfig.brushConfig.size },
                        set: { paintingConfig.brushConfig.size = $0 }
                    ),
                    in: 0.005...0.05,
                    step: 0.001
                )
                .accentColor(.blue)
            }
            
            // 断续间距调节（仅在断续模式下显示）
            if paintingConfig.brushConfig.mode == .dotted {
                VStack(alignment: .leading, spacing: 8) {
                    Text("断续间距: \(String(format: "%.3f", paintingConfig.brushConfig.dottedSpacing))")
                        .font(.headline)
                    
                    Slider(
                        value: Binding(
                            get: { paintingConfig.brushConfig.dottedSpacing },
                            set: { paintingConfig.brushConfig.dottedSpacing = $0 }
                        ),
                        in: 0.01...0.1,
                        step: 0.005
                    )
                    .accentColor(.green)
                }
            }
            
            // 颜色选择
            VStack(alignment: .leading, spacing: 8) {
                Text("画笔颜色")
                    .font(.headline)
                
                HStack {
                    Rectangle()
                        .fill(Color(paintingConfig.brushConfig.color))
                        .frame(width: 50, height: 30)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary, lineWidth: 1)
                        )
                    
                    Button("选择颜色") {
                        showColorPicker.toggle()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                selectedColor: Binding(
                    get: { Color(paintingConfig.brushConfig.color) },
                    set: { paintingConfig.brushConfig.color = UIColor($0) }
                )
            )
        }
    }
}
//
//struct ColorPickerView: View {
//    @Binding var selectedColor: Color
//    @Environment(\.presentationMode) var presentationMode
//    
//    let colors: [Color] = [
//        .white, .black, .red, .green, .blue, .yellow, .orange, .purple, .pink, .cyan,
//        .gray, .brown, .indigo, .mint, .teal
//    ]
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("选择颜色")
//                .font(.title2)
//                .fontWeight(.bold)
//            
//            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 15) {
//                ForEach(colors, id: \.self) { color in
//                    Button(action: {
//                        selectedColor = color
//                        presentationMode.wrappedValue.dismiss()
//                    }) {
//                        Circle()
//                            .fill(color)
//                            .frame(width: 50, height: 50)
//                            .overlay(
//                                Circle()
//                                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 1)
//                            )
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//            }
//            
//            ColorPicker("自定义颜色", selection: $selectedColor)
//                .padding()
//            
//            Button("完成") {
//                presentationMode.wrappedValue.dismiss()
//            }
//            .padding(.horizontal, 30)
//            .padding(.vertical, 12)
//            .background(Color.blue)
//            .foregroundColor(.white)
//            .cornerRadius(10)
//            .buttonStyle(PlainButtonStyle())
//        }
//        .padding()
//    }
//}

#Preview {
    BrushSelectionView()
        .environmentObject(PaintingConfig())
}
