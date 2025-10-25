/*
紧凑的颜色选择器
*/

import SwiftUI

struct CompactColorPickerView: View {
    @Binding var selectedColor: Color
    @Environment(\.presentationMode) var presentationMode
    
    let predefinedColors: [Color] = [
        .white, .black, .red, .green, .blue, .yellow, 
        .orange, .purple, .pink, .cyan, .gray, .brown
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择颜色")
                .font(.title2)
                .fontWeight(.bold)
            
            // 预定义颜色网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(predefinedColors, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.blue : Color.primary, 
                                           lineWidth: selectedColor == color ? 3 : 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // 自定义颜色选择器
            VStack(spacing: 12) {
                Text("自定义颜色")
                    .font(.headline)
                
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .padding(.horizontal, 20)
            }
            
            // 完成按钮
            Button("完成") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(10)
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }
}

#Preview {
    CompactColorPickerView(selectedColor: .constant(.red))
}
